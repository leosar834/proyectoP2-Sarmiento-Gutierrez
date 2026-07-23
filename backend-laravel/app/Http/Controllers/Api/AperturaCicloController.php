<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\CiclosLectivos\AbrirCicloRequest;
use App\Models\CicloLectivo;
use App\Models\Curso;
use App\Models\Desenlace;
use App\Models\Inscripcion;
use App\Models\Nivel;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Fase 3 del "Proceso de Cierre y Apertura en Cuatro Fases": crea el
 * ciclo lectivo siguiente, clona la estructura de `cursos` (nivel +
 * división + turno, vacía de alumnos) y genera las inscripciones según
 * los desenlaces ya definidos en la Fase 2.
 *
 * Deliberadamente NO clona acá `grupos_taller` ni `grupos_ed_fisica`:
 * `grupos_ed_fisica.profesor_id` es obligatorio (NOT NULL) — no hay
 * forma de crear un grupo realmente "vacío" sin inventar un profesor
 * placeholder — y `grupos_taller` depende de `especialidad_id`, que
 * las inscripciones nuevas todavía no tienen asignado. La propia
 * narrativa ubica esa redistribución (y la distribución de
 * especialidades) en la Fase 4, "población manual de lo que falta".
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que las Fases 1 y 2.
 */
class AperturaCicloController extends Controller
{
    public function abrir(AbrirCicloRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        $cicloAnterior = $ciclo;

        if ($cicloAnterior->estado !== 'cerrado') {
            throw ValidationException::withMessages([
                'ciclo' => ['El ciclo debe estar cerrado (Fase 1) antes de abrir el siguiente.'],
            ]);
        }

        // Solo puede haber un ciclo lectivo abierto a la vez. Este guard,
        // sumado al de "ciclo debe estar cerrado" de arriba, es lo que
        // realmente impide reabrir un ciclo ya procesado — cubre incluso
        // el caso límite (antes sin cubrir) de un ciclo donde TODOS los
        // desenlaces fueron 'egresa'/'baja', que nunca dejan rastro en
        // curso_destino_id. Se valida encontrado por testing real: sin
        // este guard, una segunda apertura de ese ciclo pasaba de largo
        // y creaba un ciclo lectivo entero duplicado.
        $yaHayCicloAbierto = CicloLectivo::where('estado', 'abierto')->exists();
        if ($yaHayCicloAbierto) {
            throw ValidationException::withMessages([
                'ciclo' => ['Ya existe un ciclo lectivo abierto — hay que cerrarlo antes de abrir otro.'],
            ]);
        }

        $inscripcionesActivasSinDesenlace = Inscripcion::where('ciclo_lectivo_id', $cicloAnterior->id_ciclo_lectivo)
            ->where('estado', 'activo')
            ->whereNotIn('id_inscripcion', function ($query) {
                $query->select('inscripcion_id')->from('desenlaces');
            })
            ->count();

        if ($inscripcionesActivasSinDesenlace > 0) {
            throw ValidationException::withMessages([
                'ciclo' => ["Todavía hay {$inscripcionesActivasSinDesenlace} inscripción(es) activa(s) sin desenlace definido (Fase 2 incompleta)."],
            ]);
        }

        $desenlaces = Desenlace::whereIn(
            'inscripcion_id',
            Inscripcion::where('ciclo_lectivo_id', $cicloAnterior->id_ciclo_lectivo)->select('id_inscripcion')
        )->with(['inscripcion.curso.nivel', 'inscripcion.curso.division', 'inscripcion.alumno'])->get();

        // Segunda capa de seguridad (defense in depth) para el mismo
        // caso que ya cubre el guard "ya hay un ciclo abierto" de más
        // arriba: si por algún motivo ese guard no aplicara (ej. alguien
        // cierra a mano el ciclo nuevo desde tinker), esto sigue
        // impidiendo reprocesar un ciclo cuyos desenlaces de
        // promoción/recursada ya tienen curso de destino asignado.
        if ($desenlaces->contains(fn ($d) => $d->curso_destino_id !== null)) {
            throw ValidationException::withMessages([
                'ciclo' => ['Este ciclo ya fue abierto anteriormente (ya hay desenlaces con curso de destino asignado).'],
            ]);
        }

        // Caso bloqueante: un alumno de último año que quedó en
        // 'promociona' (el default de la Fase 2) sin que el
        // administrador lo haya corregido a 'egresa' o 'recursa' — no
        // existe ningún nivel siguiente al que promocionarlo. Se valida
        // ANTES de tocar la base para no adivinar acá cuál de las dos
        // correcciones era la intención real (ver la nota completa en
        // el resumen de esta fase).
        $conflictos = [];
        foreach ($desenlaces as $desenlace) {
            if ($desenlace->tipo_desenlace !== 'promociona') {
                continue;
            }
            $nivelActual = $desenlace->inscripcion->curso->nivel;
            $existeNivelSiguiente = Nivel::where('numero_orden', $nivelActual->numero_orden + 1)->exists();
            if (! $existeNivelSiguiente) {
                $alumno = $desenlace->inscripcion->alumno;
                $conflictos[] = "{$alumno->apellido}, {$alumno->nombre} (DNI {$alumno->dni})";
            }
        }

        if ($conflictos !== []) {
            throw ValidationException::withMessages([
                'desenlaces' => [
                    "Los siguientes alumnos de último año quedaron en 'promociona' sin año "
                    . "siguiente posible — volvé a la Fase 2 y corregilos a 'egresa' o 'recursa': "
                    . implode('; ', $conflictos),
                ],
            ]);
        }

        $resultado = DB::transaction(function () use ($request, $cicloAnterior, $desenlaces) {
            $cicloNuevo = CicloLectivo::create([
                'anio' => $request->validated('anio'),
                'fecha_inicio' => $request->validated('fecha_inicio'),
                'estado' => 'abierto',
            ]);

            // Clona la estructura de cursos (nivel + división + turno,
            // vacía de alumnos) — ver la nota de clase sobre por qué NO
            // se clonan acá grupos_taller/grupos_ed_fisica.
            $cursosClonados = 0;
            foreach ($cicloAnterior->cursos as $cursoViejo) {
                $curso = Curso::firstOrCreate(
                    [
                        'nivel_id' => $cursoViejo->nivel_id,
                        'division_id' => $cursoViejo->division_id,
                        'ciclo_lectivo_id' => $cicloNuevo->id_ciclo_lectivo,
                    ],
                    ['turno' => $cursoViejo->turno]
                );
                if ($curso->wasRecentlyCreated) {
                    $cursosClonados++;
                }
            }

            $contadores = [
                'promociona' => 0,
                'recursa' => 0,
                'egresa' => 0,
                'baja' => 0,
                'pendientes_asignacion' => 0,
            ];

            foreach ($desenlaces as $desenlace) {
                $inscripcionVieja = $desenlace->inscripcion;

                if ($desenlace->tipo_desenlace === 'egresa') {
                    $inscripcionVieja->update(['estado' => 'egresado']);
                    $contadores['egresa']++;
                    continue;
                }

                if ($desenlace->tipo_desenlace === 'baja') {
                    $inscripcionVieja->update([
                        'estado' => 'baja',
                        'fecha_baja' => $inscripcionVieja->fecha_baja ?? now()->toDateString(),
                    ]);
                    $contadores['baja']++;
                    continue;
                }

                // promociona / recursa
                $cursoOrigen = $inscripcionVieja->curso;
                $nivelDestinoOrden = $desenlace->tipo_desenlace === 'promociona'
                    ? $cursoOrigen->nivel->numero_orden + 1
                    : $cursoOrigen->nivel->numero_orden;
                $nivelDestino = Nivel::where('numero_orden', $nivelDestinoOrden)->first();

                $cursoDestino = Curso::where([
                    'nivel_id' => $nivelDestino->id_nivel,
                    'division_id' => $cursoOrigen->division_id,
                    'ciclo_lectivo_id' => $cicloNuevo->id_ciclo_lectivo,
                ])->first();

                // Combinación nivel+división que no existía en el ciclo
                // anterior (nunca hubo curso ahí, así que no se clonó
                // recién arriba) — se crea sobre la marcha, pero la
                // inscripción queda en 'pendiente_asignacion' en vez de
                // 'activo' para que el administrador la revise (ver la
                // nota sobre este estado en el modelo Inscripcion).
                $esCursoNuevo = $cursoDestino === null;
                if ($esCursoNuevo) {
                    $cursoDestino = Curso::create([
                        'nivel_id' => $nivelDestino->id_nivel,
                        'division_id' => $cursoOrigen->division_id,
                        'ciclo_lectivo_id' => $cicloNuevo->id_ciclo_lectivo,
                        'turno' => $cursoOrigen->turno,
                    ]);
                }

                Inscripcion::create([
                    'alumno_id' => $inscripcionVieja->alumno_id,
                    'curso_id' => $cursoDestino->id_curso,
                    'ciclo_lectivo_id' => $cicloNuevo->id_ciclo_lectivo,
                    'especialidad_id' => $inscripcionVieja->especialidad_id,
                    'condicion' => $desenlace->tipo_desenlace === 'promociona' ? 'regular' : 'recursante',
                    'estado' => $esCursoNuevo ? 'pendiente_asignacion' : 'activo',
                ]);

                $desenlace->update(['curso_destino_id' => $cursoDestino->id_curso]);

                $contadores[$desenlace->tipo_desenlace]++;
                if ($esCursoNuevo) {
                    $contadores['pendientes_asignacion']++;
                }
            }

            return [
                'ciclo_nuevo' => $cicloNuevo,
                'cursos_clonados' => $cursosClonados,
                'contadores' => $contadores,
            ];
        });

        return response()->json([
            'data' => [
                'ciclo_nuevo' => [
                    'id_ciclo_lectivo' => $resultado['ciclo_nuevo']->id_ciclo_lectivo,
                    'anio' => $resultado['ciclo_nuevo']->anio,
                    'estado' => $resultado['ciclo_nuevo']->estado,
                ],
                'cursos_clonados' => $resultado['cursos_clonados'],
                'promociona' => $resultado['contadores']['promociona'],
                'recursa' => $resultado['contadores']['recursa'],
                'egresa' => $resultado['contadores']['egresa'],
                'baja' => $resultado['contadores']['baja'],
                'pendientes_asignacion' => $resultado['contadores']['pendientes_asignacion'],
            ],
        ]);
    }
}
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\GruposTaller\ActualizarGrupoTallerRequest;
use App\Http\Requests\Api\GruposTaller\AsignarLoteTallerRequest;
use App\Http\Requests\Api\GruposTaller\AsignarUsuariosGrupoTallerRequest;
use App\Http\Requests\Api\GruposTaller\CrearGrupoTallerRequest;
use App\Models\CicloLectivo;
use App\Models\GrupoTaller;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Fase 4 ("población manual de lo que falta"), tercera pieza:
 * redistribución en grupos de taller del ciclo nuevo — mismo patrón
 * general que `GruposEdFisicaController`, con dos diferencias reales:
 * un grupo de taller es específico de una materia Y un nivel (no solo
 * del ciclo), y un alumno puede estar en varios grupos de taller a la
 * vez (uno por cada materia que cursa), a diferencia de educación
 * física donde solo puede estar en uno.
 *
 * También cubre RF1 ("Asignar uno o más profesores de taller..." /
 * "...preceptores de taller a cada curso y grupo de taller") vía
 * `asignarUsuarios()`.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de la estructura académica.
 */
class GruposTallerController extends Controller
{
    public function crear(CrearGrupoTallerRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'ciclo' => ['Los grupos se crean sobre un ciclo lectivo abierto — este está cerrado y archivado de solo lectura.'],
            ]);
        }

        $grupo = GrupoTaller::create([
            'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
            'materia_taller_id' => $request->validated('materia_taller_id'),
            'nivel_id' => $request->validated('nivel_id'),
            'nombre_grupo' => $request->validated('nombre_grupo'),
        ]);

        return response()->json(['data' => $this->formatearGrupo($grupo)], 201);
    }

    public function index(CicloLectivo $ciclo): JsonResponse
    {
        $grupos = GrupoTaller::where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->withCount('inscripciones')
            ->get();

        return response()->json([
            'data' => $grupos->map(fn ($g) => $this->formatearGrupo($g))->values(),
        ]);
    }

    /**
     * Asignación por lote: REEMPLAZA la membresía de la MISMA materia
     * (no de todo el ciclo, como en educación física) — un alumno
     * puede estar simultáneamente en un grupo de "Electricidad" y otro
     * de "Dibujo Técnico", así que reasignarlo dentro de una materia no
     * debe tocar sus grupos de las demás. Selección de a quién asignar,
     * mismo criterio que en educación física: `inscripcion_ids` para
     * lista manual (ej. separar por sexo, ver la nota en
     * `AsignarLoteTallerRequest`), o curso/división/especialidad como
     * filtro amplio si no viene la lista.
     */
    public function asignarLote(AsignarLoteTallerRequest $request, GrupoTaller $grupo): JsonResponse
    {
        if ($grupo->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'grupo' => ['La asignación por lote solo aplica sobre un ciclo lectivo abierto.'],
            ]);
        }

        $inscripcionIdsExplicitos = $request->validated('inscripcion_ids');

        if ($inscripcionIdsExplicitos !== null && $inscripcionIdsExplicitos !== []) {
            $inscripcionIds = collect($inscripcionIdsExplicitos)->unique()->values();

            // La lista explícita puede venir de una pantalla distinta a
            // la del filtro amplio — confirmamos que sea del mismo
            // nivel que el grupo, para no colar un alumno de otro año.
            $fueraDeNivel = Inscripcion::whereIn('id_inscripcion', $inscripcionIds)
                ->whereHas('curso', fn ($q) => $q->where('nivel_id', '!=', $grupo->nivel_id))
                ->pluck('id_inscripcion');

            if ($fueraDeNivel->isNotEmpty()) {
                throw ValidationException::withMessages([
                    'inscripcion_ids' => ['Las inscripciones ' . $fueraDeNivel->implode(', ') . ' no son del nivel de este grupo.'],
                ]);
            }
        } else {
            $query = Inscripcion::where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                ->where('estado', 'activo')
                ->whereHas('curso', fn ($q) => $q->where('nivel_id', $grupo->nivel_id));

            if ($request->validated('curso_id')) {
                $query->where('curso_id', $request->validated('curso_id'));
            }
            if ($request->validated('division_id')) {
                $query->whereHas('curso', fn ($q) => $q->where('division_id', $request->validated('division_id')));
            }
            if ($request->validated('especialidad_id')) {
                $query->where('especialidad_id', $request->validated('especialidad_id'));
            }

            $inscripcionIds = $query->pluck('id_inscripcion');
        }

        $asignados = DB::transaction(function () use ($inscripcionIds, $grupo) {
            if ($inscripcionIds->isEmpty()) {
                return 0;
            }

            // Reemplazo acotado a los grupos de la MISMA materia en este
            // ciclo — no se tocan las membresías de otras materias.
            $gruposDeLaMateria = GrupoTaller::where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                ->where('materia_taller_id', $grupo->materia_taller_id)
                ->pluck('id_grupo_taller');

            DB::table('alumnos_grupos_taller')
                ->whereIn('inscripcion_id', $inscripcionIds)
                ->whereIn('grupo_taller_id', $gruposDeLaMateria)
                ->delete();

            DB::table('alumnos_grupos_taller')->insert(
                $inscripcionIds->map(fn ($id) => [
                    'inscripcion_id' => $id,
                    'grupo_taller_id' => $grupo->id_grupo_taller,
                ])->all()
            );

            return $inscripcionIds->count();
        });

        return response()->json([
            'data' => [
                'grupo_taller_id' => $grupo->id_grupo_taller,
                'asignados' => $asignados,
            ],
        ]);
    }

    /**
     * Narrativa RF1: "Crear, modificar y eliminar cursos y grupos de
     * taller" — la mitad de "modificar" que faltaba (solo existía
     * `crear`). Deliberadamente acota a `nombre_grupo`, ver el docblock
     * de `ActualizarGrupoTallerRequest`.
     */
    public function actualizar(ActualizarGrupoTallerRequest $request, GrupoTaller $grupo): JsonResponse
    {
        if ($grupo->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'grupo' => ['No se puede editar un grupo de un ciclo lectivo cerrado y archivado de solo lectura.'],
            ]);
        }

        $grupo->update(['nombre_grupo' => $request->validated('nombre_grupo')]);

        return response()->json(['data' => $this->formatearGrupo($grupo->fresh())]);
    }

    /**
     * La mitad de "eliminar" que faltaba de la misma frase de RF1.
     * Mismo criterio que `CursosController::eliminar` y
     * `MateriasTallerController::eliminar`: no se borra un grupo que ya
     * tiene alumnos asignados, para no dejar huérfanas las planillas de
     * asistencia que referencian `grupo_taller_id`.
     */
    public function eliminar(GrupoTaller $grupo): JsonResponse
    {
        if ($grupo->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'grupo' => ['No se puede eliminar un grupo de un ciclo lectivo cerrado y archivado de solo lectura.'],
            ]);
        }

        $tieneAlumnos = $grupo->inscripciones()->exists();
        if ($tieneAlumnos) {
            throw ValidationException::withMessages([
                'grupo' => ['Este grupo ya tiene alumnos asignados — no se puede eliminar.'],
            ]);
        }

        $grupo->delete();

        return response()->json(['data' => ['id_grupo_taller' => $grupo->id_grupo_taller, 'eliminado' => true]]);
    }

    /**
     * Narrativa RF1: "Asignar uno o más profesores de taller a cada
     * curso y grupo de taller" + "...preceptores de taller...". Ambos
     * roles viven en la misma tabla puente (`usuarios_grupos_taller`,
     * distinguidos por `rol_en_grupo`), así que una sola llamada
     * reemplaza (sync) el personal completo del grupo — mandar la
     * lista nueva completa cubre agregar, quitar o cambiarle el rol a
     * alguien, sin un endpoint de "quitar" aparte.
     */
    public function asignarUsuarios(AsignarUsuariosGrupoTallerRequest $request, GrupoTaller $grupo): JsonResponse
    {
        if ($grupo->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'grupo' => ['No se puede modificar el personal de un grupo de un ciclo lectivo cerrado y archivado de solo lectura.'],
            ]);
        }

        $sync = collect($request->validated('asignaciones'))
            ->mapWithKeys(fn (array $fila) => [$fila['usuario_id'] => ['rol_en_grupo' => $fila['rol_en_grupo']]])
            ->all();

        $grupo->usuarios()->sync($sync);
        $grupo = $grupo->fresh(['usuarios']);

        return response()->json([
            'data' => $this->formatearGrupo($grupo) + [
                'personal' => $grupo->usuarios->map(fn ($u) => [
                    'id_usuario' => $u->id_usuario,
                    'nombre' => $u->nombre,
                    'apellido' => $u->apellido,
                    'rol_en_grupo' => $u->pivot->rol_en_grupo,
                ])->values(),
            ],
        ]);
    }

    private function formatearGrupo(GrupoTaller $grupo): array
    {
        return [
            'id_grupo_taller' => $grupo->id_grupo_taller,
            'ciclo_lectivo_id' => $grupo->ciclo_lectivo_id,
            'materia_taller_id' => $grupo->materia_taller_id,
            'nivel_id' => $grupo->nivel_id,
            'nombre_grupo' => $grupo->nombre_grupo,
            'alumnos_asignados' => $grupo->inscripciones_count ?? 0,
        ];
    }
}

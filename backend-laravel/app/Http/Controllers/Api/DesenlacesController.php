<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Desenlaces\ActualizarDesenlaceRequest;
use App\Models\CicloLectivo;
use App\Models\Desenlace;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Fase 2 del "Proceso de Cierre y Apertura en Cuatro Fases": el
 * administrador marca qué alumnos promocionan, recursan, egresan o se
 * dan de baja, mirando los resultados ya congelados en la Fase 1.
 *
 * `inicializar()` sigue al pie de la letra lo que pide la narrativa:
 * "el sistema puede marcar por defecto la promoción de todos, de
 * manera que el administrador solo intervenga en las excepciones" —
 * no hay un caso especial para el último año acá adentro (egresar a
 * los alumnos de último año es una de esas excepciones que corrige el
 * administrador con `actualizar()`, no un default distinto).
 *
 * Todas las rutas van detrás de `permiso:gestionar_sistema`, igual que
 * el cierre de la Fase 1 (RF1, "dar inicio y fin del ciclo lectivo").
 */
class DesenlacesController extends Controller
{
    /**
     * Crea un desenlace `promociona` para cada inscripción activa del
     * ciclo que todavía no tenga uno — nunca pisa uno ya definido (a
     * mano o por una corrida anterior de este mismo endpoint), así que
     * es seguro reinvocarlo si quedó algún alumno sin procesar.
     */
    public function inicializar(Request $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'cerrado') {
            throw ValidationException::withMessages([
                'ciclo' => ['Los desenlaces se definen sobre un ciclo ya cerrado (Fase 1) — este todavía está abierto.'],
            ]);
        }

        $usuario = $request->user();
        $ahora = now();

        $inscripcionesSinDesenlace = Inscripcion::where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->where('estado', 'activo')
            ->whereNotIn('id_inscripcion', function ($query) {
                $query->select('inscripcion_id')->from('desenlaces');
            })
            ->pluck('id_inscripcion');

        $filas = $inscripcionesSinDesenlace->map(fn ($inscripcionId) => [
            'inscripcion_id' => $inscripcionId,
            'tipo_desenlace' => 'promociona',
            'curso_destino_id' => null,
            'usuario_definicion_id' => $usuario->id_usuario,
            'fecha_definicion' => $ahora,
        ])->all();

        if ($filas !== []) {
            DB::table('desenlaces')->insert($filas);
        }

        return response()->json([
            'data' => [
                'creados' => count($filas),
            ],
        ]);
    }

    /**
     * Lista los desenlaces del ciclo con el resultado final ya
     * calculado en la Fase 1 al lado — es justamente lo que la
     * narrativa dice que hay que mirar para tomar esta decisión
     * ("mirando el año que terminó").
     */
    public function index(Request $request, CicloLectivo $ciclo): JsonResponse
    {
        $filas = DB::table('desenlaces')
            ->join('inscripciones', 'inscripciones.id_inscripcion', '=', 'desenlaces.inscripcion_id')
            ->join('alumnos', 'alumnos.id_alumno', '=', 'inscripciones.alumno_id')
            ->leftJoin('resultados_finales', 'resultados_finales.inscripcion_id', '=', 'desenlaces.inscripcion_id')
            ->where('inscripciones.ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->orderBy('alumnos.apellido')
            ->get([
                'desenlaces.id_desenlace',
                'desenlaces.inscripcion_id',
                'desenlaces.tipo_desenlace',
                'desenlaces.curso_destino_id',
                'desenlaces.fecha_definicion',
                'alumnos.id_alumno',
                'alumnos.nombre',
                'alumnos.apellido',
                'alumnos.dni',
                'resultados_finales.porcentaje_inasistencia',
                'resultados_finales.condicion_final',
            ]);

        return response()->json([
            'data' => $filas->map(fn ($fila) => [
                'id_desenlace' => $fila->id_desenlace,
                'inscripcion_id' => $fila->inscripcion_id,
                'alumno' => [
                    'id_alumno' => $fila->id_alumno,
                    'nombre' => $fila->nombre,
                    'apellido' => $fila->apellido,
                    'dni' => $fila->dni,
                ],
                'resultado_final' => $fila->condicion_final ? [
                    'porcentaje_inasistencia' => $fila->porcentaje_inasistencia,
                    'condicion_final' => $fila->condicion_final,
                ] : null,
                'tipo_desenlace' => $fila->tipo_desenlace,
                'curso_destino_id' => $fila->curso_destino_id,
                'fecha_definicion' => $fila->fecha_definicion,
            ]),
        ]);
    }

    /**
     * Corrige el desenlace de una inscripción puntual — la excepción
     * que el administrador marca a mano sobre el default de
     * `inicializar()`.
     */
    public function actualizar(ActualizarDesenlaceRequest $request, Desenlace $desenlace): JsonResponse
    {
        $desenlace->update([
            'tipo_desenlace' => $request->validated('tipo_desenlace'),
            'usuario_definicion_id' => $request->user()->id_usuario,
            'fecha_definicion' => now(),
        ]);

        return response()->json([
            'data' => [
                'id_desenlace' => $desenlace->id_desenlace,
                'inscripcion_id' => $desenlace->inscripcion_id,
                'tipo_desenlace' => $desenlace->tipo_desenlace,
                'curso_destino_id' => $desenlace->curso_destino_id,
                'fecha_definicion' => $desenlace->fecha_definicion,
            ],
        ]);
    }
}

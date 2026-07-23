<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Ingresantes\CrearIngresanteRequest;
use App\Models\Alumno;
use App\Models\CicloLectivo;
use App\Models\Curso;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Fase 4 ("población manual de lo que falta"), primera pieza: altas de
 * ingresantes nuevos a la institución. La narrativa es explícita en
 * que el alta crea el legajo Y su inscripción en primer año en un
 * mismo paso: "se cargan los ingresantes nuevos a la institución en el
 * primer año —ya sea como altas individuales o mediante la
 * importación de un listado de inscripción—". Esto cubre la parte
 * individual; la importación por listado queda para más adelante,
 * como una mejora sobre este mismo endpoint.
 *
 * Solo cubre al alumno genuinamente nuevo (sin legajo previo). El
 * regreso de un egresado, que la narrativa menciona como un traslado
 * manual aparte ("el regreso de egresados"), no entra acá — reusar un
 * legajo existente es una operación distinta a dar de alta uno nuevo,
 * y no la resuelve este endpoint.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de alumnos (narrativa: "gestionar ... alumnos" es una
 * facultad de jefa de preceptores/administrador).
 */
class IngresantesController extends Controller
{
    public function crear(CrearIngresanteRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'ciclo' => ['Los ingresantes se cargan sobre un ciclo lectivo abierto — este está cerrado y archivado de solo lectura.'],
            ]);
        }

        $curso = Curso::with('nivel')->findOrFail($request->validated('curso_id'));
        if ($curso->nivel->numero_orden !== 1) {
            throw ValidationException::withMessages([
                'curso_id' => ['Los ingresantes nuevos se cargan en un curso de primer año (numero_orden = 1), no en años superiores.'],
            ]);
        }

        // DNI ya usado por un legajo existente: si está borrado
        // (soft-delete), avisamos que hay que restaurarlo en vez de
        // reintentar el alta — `uq_alumnos_dni` no incluye
        // `deleted_at` (ver nota en el modelo Alumno), así que un
        // create() directo chocaría con la restricción igual si
        // simplemente lo ignorásemos acá.
        $dni = $request->validated('dni');
        $existente = Alumno::withTrashed()->where('dni', $dni)->first();
        if ($existente !== null) {
            throw ValidationException::withMessages([
                'dni' => [$existente->trashed()
                    ? "Ya existe un legajo con este DNI (id {$existente->id_alumno}), pero está dado de baja — hay que restaurarlo en vez de crear uno nuevo."
                    : "Ya existe un legajo con este DNI (id {$existente->id_alumno})."],
            ]);
        }

        [$alumno, $inscripcion] = DB::transaction(function () use ($request, $curso) {
            $alumno = Alumno::create([
                'nombre' => $request->validated('nombre'),
                'apellido' => $request->validated('apellido'),
                'dni' => $request->validated('dni'),
                'fecha_nacimiento' => $request->validated('fecha_nacimiento'),
                'fecha_ingreso_institucion' => $request->validated('fecha_ingreso_institucion'),
            ]);

            $inscripcion = Inscripcion::create([
                'alumno_id' => $alumno->id_alumno,
                'curso_id' => $curso->id_curso,
                'ciclo_lectivo_id' => $curso->ciclo_lectivo_id,
                'especialidad_id' => null,
                'condicion' => 'regular',
                'estado' => 'activo',
            ]);

            return [$alumno, $inscripcion];
        });

        return response()->json([
            'data' => [
                'alumno' => [
                    'id_alumno' => $alumno->id_alumno,
                    'nombre' => $alumno->nombre,
                    'apellido' => $alumno->apellido,
                    'dni' => $alumno->dni,
                ],
                'inscripcion' => [
                    'id_inscripcion' => $inscripcion->id_inscripcion,
                    'curso_id' => $inscripcion->curso_id,
                    'ciclo_lectivo_id' => $inscripcion->ciclo_lectivo_id,
                    'condicion' => $inscripcion->condicion,
                    'estado' => $inscripcion->estado,
                ],
            ],
        ], 201);
    }
}
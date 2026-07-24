<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Traslados\TrasladarAlumnoRequest;
use App\Models\Alumno;
use App\Models\CicloLectivo;
use App\Models\Curso;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Traslados manuales de alumnos (narrativa: "traslados de alumnos a
 * diferentes cursos... para los casos que rompen la regla general, como
 * recursantes, cambios de división o el regreso de egresados").
 *
 * Los tres casos de la narrativa se resuelven con UNA sola operación,
 * porque estructuralmente son la misma pregunta: "¿este alumno ya tiene
 * una fila en `inscripciones` para este ciclo lectivo?" —
 * `uq_inscripciones_alumno_ciclo` en la base garantiza que un alumno no
 * puede tener más de una inscripción por ciclo, sin importar su `estado`.
 * Si ya la tiene (el caso típico de "cambio de división": el alumno ya
 * está activo en un curso de este ciclo), se actualiza esa fila en el
 * lugar. Si no la tiene (recursante fuera de temporada — no pasó por la
 * Fase 3 automática — o el regreso de un egresado, cuya última fila
 * pertenece a un ciclo distinto y ya cerrado), se crea una nueva,
 * respetando la distinción legajo/inscripción de la narrativa: el
 * `Alumno` nunca se toca, lo que se crea es el vínculo nuevo.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de alumnos y estructura académica.
 */
class TrasladosController extends Controller
{
    public function trasladar(TrasladarAlumnoRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'ciclo' => ['Los traslados se hacen sobre un ciclo lectivo abierto — este está cerrado y archivado de solo lectura.'],
            ]);
        }

        $alumnoId = $request->validated('alumno_id');
        $alumno = Alumno::find($alumnoId);
        if ($alumno === null) {
            $existeBorrado = Alumno::withTrashed()->find($alumnoId);
            throw ValidationException::withMessages([
                'alumno_id' => [$existeBorrado !== null
                    ? "Este legajo está dado de baja (id {$existeBorrado->id_alumno}) — hay que restaurarlo antes de trasladarlo."
                    : 'El alumno indicado no existe.'],
            ]);
        }

        $curso = Curso::with(['nivel', 'division'])->findOrFail($request->validated('curso_id'));

        $resultado = DB::transaction(function () use ($alumno, $curso, $ciclo, $request) {
            $inscripcionDeEsteCiclo = Inscripcion::where('alumno_id', $alumno->id_alumno)
                ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
                ->first();

            // Especialidad: si no viene explícita en el pedido, se hereda
            // de la inscripción más reciente del alumno (la de este mismo
            // ciclo si ya existía, o si no la última que tenga en
            // cualquier ciclo) — así un traslado no pisa sin querer una
            // especialidad ya asignada en el ciclo superior.
            $especialidadId = $request->validated('especialidad_id')
                ?? $inscripcionDeEsteCiclo?->especialidad_id
                ?? Inscripcion::where('alumno_id', $alumno->id_alumno)
                    ->latest('id_inscripcion')
                    ->value('especialidad_id');

            $datos = [
                'curso_id' => $curso->id_curso,
                'especialidad_id' => $especialidadId,
                'condicion' => $request->validated('condicion'),
                // El traslado siempre deja al alumno activo en el curso
                // de destino — es el efecto natural de "trasladarlo": si
                // la fila existente estaba egresada o de baja, se
                // reactiva; se limpian fecha/motivo de baja porque ya no
                // aplican.
                'estado' => 'activo',
                'fecha_baja' => null,
                'motivo_baja' => null,
            ];

            if ($inscripcionDeEsteCiclo !== null) {
                $inscripcionDeEsteCiclo->update($datos);

                return ['inscripcion' => $inscripcionDeEsteCiclo->fresh(), 'tipo' => 'cambio_de_curso'];
            }

            $inscripcionNueva = Inscripcion::create($datos + [
                'alumno_id' => $alumno->id_alumno,
                'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
            ]);

            return ['inscripcion' => $inscripcionNueva, 'tipo' => 'inscripcion_nueva'];
        });

        return response()->json([
            'data' => [
                'tipo_traslado' => $resultado['tipo'],
                'inscripcion' => $this->formatear($resultado['inscripcion']->load(['alumno', 'curso.nivel', 'curso.division'])),
            ],
        ], $resultado['tipo'] === 'inscripcion_nueva' ? 201 : 200);
    }

    private function formatear(Inscripcion $inscripcion): array
    {
        return [
            'id_inscripcion' => $inscripcion->id_inscripcion,
            'alumno_id' => $inscripcion->alumno_id,
            'alumno_nombre' => trim(($inscripcion->alumno?->apellido ?? '').', '.($inscripcion->alumno?->nombre ?? '')),
            'curso_id' => $inscripcion->curso_id,
            'curso' => $inscripcion->curso
                ? trim(($inscripcion->curso->nivel?->nombre ?? '').' '.($inscripcion->curso->division?->nombre ?? ''))
                : null,
            'ciclo_lectivo_id' => $inscripcion->ciclo_lectivo_id,
            'especialidad_id' => $inscripcion->especialidad_id,
            'condicion' => $inscripcion->condicion,
            'estado' => $inscripcion->estado,
        ];
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Alumnos\ActualizarAlumnoRequest;
use App\Http\Requests\Api\Alumnos\CrearAlumnoRequest;
use App\Models\Alumno;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Gestión de alumnos (RF1, "Gestión de alumnos": "Dar de alta, modificar
 * y eliminar alumnos del sistema"). Esto es SOLO el legajo — nombre,
 * apellido, DNI, fechas. Asignar al alumno a un curso (año y división)
 * es una operación aparte:
 *
 * - `IngresantesController::crear` sigue siendo el atajo para el caso
 *   más común (alta de un ingresante nuevo, directo en un curso de
 *   primer año) — crea legajo + inscripción en un solo paso, restringido
 *   a nivel uno.
 * - `crear()` acá abajo da de alta SOLO el legajo, sin restricción de
 *   nivel — cubre el caso de un alumno genuinamente nuevo que entra
 *   directo a un año superior (ej. un pase de otra institución, que no
 *   es "ingresante de primer año" ni tiene legajo previo para usar
 *   `TrasladosController`). Después de creado, se lo asigna a un curso
 *   con `TrasladosController::trasladar`.
 *
 * Va detrás de `permiso:gestionar_sistema`.
 */
class AlumnosController extends Controller
{
    public function crear(CrearAlumnoRequest $request): JsonResponse
    {
        $this->verificarDniDisponible($request->validated('dni'));

        $alumno = Alumno::create($request->validated());

        return response()->json(['data' => $this->formatearLegajo($alumno->fresh())], 201);
    }

    public function index(Request $request): JsonResponse
    {
        $alumnos = Alumno::query()
            ->when($request->query('busqueda'), function ($query, $busqueda) {
                $query->where(function ($q) use ($busqueda) {
                    $q->where('nombre', 'like', "%{$busqueda}%")
                        ->orWhere('apellido', 'like', "%{$busqueda}%")
                        ->orWhere('dni', 'like', "%{$busqueda}%");
                });
            })
            ->when($request->query('curso_id'), function ($query, $cursoId) {
                $query->whereHas('inscripciones', fn ($q) => $q
                    ->where('curso_id', $cursoId)
                    ->where('estado', 'activo'));
            })
            ->orderBy('apellido')
            ->orderBy('nombre')
            ->get();

        return response()->json(['data' => $alumnos->map(fn (Alumno $a) => $this->formatearLegajo($a))->values()]);
    }

    /**
     * Legajo + historial completo de inscripciones (una por ciclo
     * lectivo). Necesario para decidir un traslado con información real
     * — ver `TrasladosController`.
     */
    public function mostrar(Alumno $alumno): JsonResponse
    {
        $inscripciones = $alumno->inscripciones()
            ->with(['curso.nivel', 'curso.division', 'cicloLectivo', 'especialidad'])
            ->orderByDesc('ciclo_lectivo_id')
            ->get();

        return response()->json([
            'data' => $this->formatearLegajo($alumno) + [
                'inscripciones' => $inscripciones->map(fn (Inscripcion $i) => [
                    'id_inscripcion' => $i->id_inscripcion,
                    'ciclo_lectivo_id' => $i->ciclo_lectivo_id,
                    'ciclo_anio' => $i->cicloLectivo?->anio,
                    'curso_id' => $i->curso_id,
                    'curso' => $i->curso
                        ? trim(($i->curso->nivel?->nombre ?? '').' '.($i->curso->division?->nombre ?? ''))
                        : null,
                    'especialidad_id' => $i->especialidad_id,
                    'especialidad_nombre' => $i->especialidad?->nombre,
                    'condicion' => $i->condicion,
                    'estado' => $i->estado,
                ])->values(),
            ],
        ]);
    }

    public function actualizar(ActualizarAlumnoRequest $request, Alumno $alumno): JsonResponse
    {
        $dniNuevo = $request->validated('dni');
        if ($dniNuevo !== $alumno->dni) {
            $this->verificarDniDisponible($dniNuevo, $alumno->id_alumno);
        }

        $alumno->update($request->validated());

        return response()->json(['data' => $this->formatearLegajo($alumno->fresh())]);
    }

    public function eliminar(Alumno $alumno): JsonResponse
    {
        // No se elimina un legajo con una inscripción activa en el ciclo
        // lectivo abierto — el alumno "desaparecería" de listados y de la
        // toma de asistencia mientras sigue figurando inscripto. Si el
        // alumno abandonó a mitad de año, el paso correcto es dar de baja
        // SU INSCRIPCIÓN primero con `TrasladosController::darDeBaja`
        // (PUT /inscripciones/{inscripcion}/dar-de-baja) — eso no toca el
        // legajo — y recién después, si además hace falta, eliminar el
        // legajo acá.
        $tieneInscripcionActiva = $alumno->inscripciones()->where('estado', 'activo')->exists();
        if ($tieneInscripcionActiva) {
            throw ValidationException::withMessages([
                'alumno' => ['Este alumno tiene una inscripción activa en el ciclo lectivo abierto — primero hay que darla de baja con PUT /inscripciones/{inscripcion}/dar-de-baja antes de poder eliminar el legajo.'],
            ]);
        }

        $alumno->delete();

        return response()->json(['data' => ['id_alumno' => $alumno->id_alumno, 'eliminado' => true]]);
    }

    private function verificarDniDisponible(string $dni, ?int $idAlumnoExcluido = null): void
    {
        $existente = Alumno::withTrashed()
            ->where('dni', $dni)
            ->when($idAlumnoExcluido, fn ($q) => $q->where('id_alumno', '!=', $idAlumnoExcluido))
            ->first();

        if ($existente !== null) {
            throw ValidationException::withMessages([
                'dni' => [$existente->trashed()
                    ? "Ya existe un legajo con este DNI (id {$existente->id_alumno}), pero está dado de baja — hay que restaurarlo en vez de crear uno nuevo."
                    : "Ya existe un legajo con este DNI (id {$existente->id_alumno})."],
            ]);
        }
    }

    private function formatearLegajo(Alumno $alumno): array
    {
        return [
            'id_alumno' => $alumno->id_alumno,
            'nombre' => $alumno->nombre,
            'apellido' => $alumno->apellido,
            'dni' => $alumno->dni,
            'fecha_nacimiento' => $alumno->fecha_nacimiento?->toDateString(),
            'fecha_ingreso_institucion' => $alumno->fecha_ingreso_institucion?->toDateString(),
        ];
    }
}

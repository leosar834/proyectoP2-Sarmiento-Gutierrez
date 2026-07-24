<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Alumno;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;

/**
 * Consulta de legajo: alumno + su historial completo de inscripciones
 * (una por ciclo lectivo, narrativa/`uq_inscripciones_alumno_ciclo`).
 * Se agregó como apoyo directo de los traslados manuales — antes de
 * trasladar a alguien hace falta ver si ya tiene una inscripción en el
 * ciclo abierto, y si viene de una situación de egresado/recursante.
 *
 * Esto NO es el CRUD completo de alumnos (alta/edición/baja de un
 * legajo) — ese sigue siendo un gap aparte, sin resolver todavía.
 *
 * Va detrás de `permiso:gestionar_sistema`.
 */
class AlumnosController extends Controller
{
    public function mostrar(Alumno $alumno): JsonResponse
    {
        $inscripciones = $alumno->inscripciones()
            ->with(['curso.nivel', 'curso.division', 'cicloLectivo', 'especialidad'])
            ->orderByDesc('ciclo_lectivo_id')
            ->get();

        return response()->json([
            'data' => [
                'id_alumno' => $alumno->id_alumno,
                'nombre' => $alumno->nombre,
                'apellido' => $alumno->apellido,
                'dni' => $alumno->dni,
                'fecha_nacimiento' => $alumno->fecha_nacimiento?->toDateString(),
                'fecha_ingreso_institucion' => $alumno->fecha_ingreso_institucion?->toDateString(),
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
}

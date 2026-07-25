<?php

namespace App\Http\Controllers\Api;

use App\Exports\EstadisticasAlumnoExport;
use App\Exports\FaltasPorCursoExport;
use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Reportes\FaltasPorCursoRequest;
use App\Models\Curso;
use App\Models\DetalleAsistencia;
use App\Models\Inscripcion;
use App\Models\Justificacion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Facades\Excel;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Implementa RF7 (Reportes y Estadísticas): dos vistas en JSON
 * (`faltasPorCurso`, `estadisticasAlumno`) para un futuro cliente
 * Flutter, y la exportación a `.xlsx` de ambas — "el formato de
 * exportación principal es Excel", según la narrativa.
 *
 * Ninguna de las respuestas JSON envuelve un modelo Eloquent 1:1 (son
 * agregados armados a partir de varias tablas), así que se devuelven
 * como arrays planos vía `response()->json()` en vez de forzarlos
 * dentro de un JsonResource — mismo criterio que ya se usó en
 * AsignacionesController.
 *
 * Todas las rutas van detrás de `permiso:ver_reportes` (ver
 * routes/api.php).
 */
class ReportesController extends Controller
{
    /**
     * Faltas por alumno de un curso, en un rango de fechas explícito
     * (ver la nota en FaltasPorCursoRequest sobre por qué no hay un
     * cálculo automático de "esta semana"/"este mes"/"este trimestre").
     */
    public function faltasPorCurso(FaltasPorCursoRequest $request): JsonResponse
    {
        $datos = $request->validated();
        $curso = Curso::with(['nivel', 'division'])->findOrFail($datos['curso_id']);
        $alumnos = $this->alumnosConFaltas($curso, $datos['fecha_inicio'], $datos['fecha_fin']);

        return response()->json([
            'data' => [
                'curso' => [
                    'id_curso' => $curso->id_curso,
                    'etiqueta' => "{$curso->nivel->nombre} {$curso->division->nombre} ({$curso->turno})",
                ],
                'periodo' => [
                    'fecha_inicio' => $datos['fecha_inicio'],
                    'fecha_fin' => $datos['fecha_fin'],
                ],
                'alumnos' => $alumnos,
            ],
        ]);
    }

    /**
     * Mismo reporte que `faltasPorCurso()`, en .xlsx.
     */
    public function exportarFaltasPorCurso(FaltasPorCursoRequest $request): BinaryFileResponse
    {
        $datos = $request->validated();
        $curso = Curso::with(['nivel', 'division'])->findOrFail($datos['curso_id']);
        $alumnos = $this->alumnosConFaltas($curso, $datos['fecha_inicio'], $datos['fecha_fin']);

        $nombreArchivo = sprintf(
            'faltas_curso_%d_%s_a_%s.xlsx',
            $curso->id_curso,
            $datos['fecha_inicio'],
            $datos['fecha_fin']
        );

        return Excel::download(new FaltasPorCursoExport($alumnos), $nombreArchivo);
    }

    /**
     * Estadísticas individuales de un alumno (por inscripción, no por
     * legajo — ver la nota en el modelo `Inscripcion` sobre por qué
     * todo lo transaccional cuelga de la inscripción del ciclo, no del
     * alumno directamente). Combina el contador acumulado del ciclo
     * completo (`contadores_asistencia`, ya mantenido por los triggers
     * de MySQL) con el historial puntual de tardanzas y justificaciones
     * que pide la narrativa.
     */
    public function estadisticasAlumno(Request $request, Inscripcion $inscripcion): JsonResponse
    {
        return response()->json(['data' => $this->datosEstadisticasAlumno($inscripcion)]);
    }

    /**
     * Mismo reporte que `estadisticasAlumno()`, en .xlsx — tres hojas
     * (Resumen, Tardanzas, Justificaciones) porque, a diferencia del
     * reporte de faltas por curso, acá los tres bloques no comparten
     * columnas y no tiene sentido forzarlos en una sola tabla.
     */
    public function exportarEstadisticasAlumno(Request $request, Inscripcion $inscripcion): BinaryFileResponse
    {
        $datos = $this->datosEstadisticasAlumno($inscripcion);

        $nombreArchivo = sprintf(
            'estadisticas_%s_%s.xlsx',
            $datos['alumno']['apellido'],
            $datos['alumno']['dni']
        );

        return Excel::download(new EstadisticasAlumnoExport($datos), $nombreArchivo);
    }

    /**
     * Compartido entre `estadisticasAlumno()` (JSON) y
     * `exportarEstadisticasAlumno()` (.xlsx) para no calcular esto dos
     * veces con el riesgo de que se desincronicen — mismo criterio que
     * ya se usa con `alumnosConFaltas()` para el reporte de faltas por
     * curso.
     */
    private function datosEstadisticasAlumno(Inscripcion $inscripcion): array
    {
        $inscripcion->load(['alumno', 'curso.nivel', 'curso.division']);

        $contador = DB::table('contadores_asistencia')
            ->where('inscripcion_id', $inscripcion->id_inscripcion)
            ->first();

        $tardanzas = DetalleAsistencia::query()
            ->join('planillas_asistencia', 'planillas_asistencia.id_planilla', '=', 'detalles_asistencia.planilla_id')
            ->where('detalles_asistencia.inscripcion_id', $inscripcion->id_inscripcion)
            ->where('detalles_asistencia.estado', 'tardanza')
            ->orderByDesc('planillas_asistencia.fecha')
            ->get([
                'planillas_asistencia.fecha as fecha',
                'planillas_asistencia.area as area',
                'detalles_asistencia.observaciones as observaciones',
            ]);

        $justificaciones = Justificacion::where('inscripcion_id', $inscripcion->id_inscripcion)
            ->orderByDesc('fecha_presentacion')
            ->get([
                'id_justificacion',
                'fecha_inicio',
                'fecha_fin',
                'tipo',
                'fecha_presentacion',
                'area_receptora',
                'estado_notificacion',
            ]);

        return [
            'alumno' => [
                'id_alumno' => $inscripcion->alumno->id_alumno,
                'nombre' => $inscripcion->alumno->nombre,
                'apellido' => $inscripcion->alumno->apellido,
                'dni' => $inscripcion->alumno->dni,
                'curso' => "{$inscripcion->curso->nivel->nombre} {$inscripcion->curso->division->nombre}",
            ],
            'contador_general' => $contador ? [
                'faltas_teoricas' => $contador->faltas_teoricas,
                'faltas_taller' => $contador->faltas_taller,
                'faltas_ed_fisica' => $contador->faltas_ed_fisica,
                'faltas_general' => $contador->faltas_general,
                'tardanzas_global' => $contador->tardanzas_global,
                'justificaciones_total' => $contador->justificaciones_total,
            ] : null,
            'historial_tardanzas' => $tardanzas,
            'historial_justificaciones' => $justificaciones,
        ];
    }

    /**
     * Solo cuenta inscripciones con `estado = activo`: el reporte
     * describe la matrícula actual del curso, no el historial completo
     * de quien pasó por él. Compartido entre `faltasPorCurso()` (JSON)
     * y `exportarFaltasPorCurso()` (.xlsx) para no calcular esto dos
     * veces con el riesgo de que se desincronicen.
     */
    private function alumnosConFaltas(Curso $curso, string $fechaInicio, string $fechaFin): Collection
    {
        $inscripciones = Inscripcion::where('curso_id', $curso->id_curso)
            ->where('estado', 'activo')
            ->with('alumno')
            ->get();

        $conteosPorInscripcion = DetalleAsistencia::query()
            ->join('planillas_asistencia', 'planillas_asistencia.id_planilla', '=', 'detalles_asistencia.planilla_id')
            // Sin este filtro, un alumno que también curse taller o
            // educación física arrastraría esas faltas al reporte "del
            // curso" — el JOIN por inscripcion_id solo garantiza que el
            // alumno pertenece al curso, no que la planilla sea la de
            // ese curso en particular (taller/ed_fisica usan sus
            // propios grupos, no `curso_id`).
            ->where('planillas_asistencia.area', 'teorica')
            ->where('planillas_asistencia.curso_id', $curso->id_curso)
            ->whereIn('detalles_asistencia.inscripcion_id', $inscripciones->pluck('id_inscripcion'))
            ->whereBetween('planillas_asistencia.fecha', [$fechaInicio, $fechaFin])
            ->groupBy('detalles_asistencia.inscripcion_id')
            ->selectRaw(<<<'SQL'
                detalles_asistencia.inscripcion_id as inscripcion_id,
                SUM(detalles_asistencia.estado = 'presente') as presentes,
                SUM(detalles_asistencia.estado = 'ausente') as ausentes,
                SUM(detalles_asistencia.estado = 'tardanza') as tardanzas,
                SUM(detalles_asistencia.estado = 'falta_justificada') as faltas_justificadas
            SQL)
            ->get()
            ->keyBy('inscripcion_id');

        return $inscripciones
            ->map(function (Inscripcion $inscripcion) use ($conteosPorInscripcion) {
                $conteo = $conteosPorInscripcion->get($inscripcion->id_inscripcion);

                return [
                    'inscripcion_id' => $inscripcion->id_inscripcion,
                    'alumno' => [
                        'id_alumno' => $inscripcion->alumno->id_alumno,
                        'nombre' => $inscripcion->alumno->nombre,
                        'apellido' => $inscripcion->alumno->apellido,
                        'dni' => $inscripcion->alumno->dni,
                    ],
                    'presentes' => (int) ($conteo->presentes ?? 0),
                    'ausentes' => (int) ($conteo->ausentes ?? 0),
                    'tardanzas' => (int) ($conteo->tardanzas ?? 0),
                    'faltas_justificadas' => (int) ($conteo->faltas_justificadas ?? 0),
                ];
            })
            ->sortBy('alumno.apellido')
            ->values();
    }
}

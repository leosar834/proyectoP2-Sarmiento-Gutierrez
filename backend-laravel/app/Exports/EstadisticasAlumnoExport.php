<?php

namespace App\Exports;

use Maatwebsite\Excel\Concerns\WithMultipleSheets;

/**
 * Exporta a .xlsx el mismo reporte que
 * ReportesController::estadisticasAlumno() ya devuelve en JSON — igual
 * que con FaltasPorCursoExport, recibe los datos ya calculados por el
 * controller (`datosEstadisticasAlumno()`) en vez de volver a consultar
 * la base, para que el JSON y el .xlsx nunca se desincronicen.
 *
 * A diferencia de FaltasPorCursoExport (una sola tabla), acá el reporte
 * trae tres bloques de forma distinta entre sí (un resumen de un solo
 * alumno, y dos historiales con columnas propias) — forzarlos en una
 * sola hoja los haría ilegibles, así que se arman como tres hojas
 * separadas.
 */
class EstadisticasAlumnoExport implements WithMultipleSheets
{
    public function __construct(private readonly array $datos)
    {
    }

    public function sheets(): array
    {
        return [
            new EstadisticasAlumnoResumenSheet($this->datos),
            new EstadisticasAlumnoTardanzasSheet($this->datos['historial_tardanzas']),
            new EstadisticasAlumnoJustificacionesSheet($this->datos['historial_justificaciones']),
        ];
    }
}

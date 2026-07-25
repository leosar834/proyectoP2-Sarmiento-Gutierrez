<?php

namespace App\Exports;

use Illuminate\Support\Collection;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithTitle;

/**
 * Segunda hoja del export de estadísticas individuales: historial
 * completo de tardanzas de la inscripción, misma consulta que ya arma
 * `ReportesController::datosEstadisticasAlumno()` para el JSON.
 */
class EstadisticasAlumnoTardanzasSheet implements FromCollection, WithHeadings, WithMapping, WithTitle, ShouldAutoSize
{
    public function __construct(private readonly Collection $tardanzas)
    {
    }

    public function collection(): Collection
    {
        return $this->tardanzas;
    }

    public function headings(): array
    {
        return ['Fecha', 'Área', 'Observaciones'];
    }

    public function map($fila): array
    {
        // $fila viene de un select con alias sobre columnas crudas (ver
        // ReportesController::datosEstadisticasAlumno()) — `fecha` no
        // pasa por ningún cast de Eloquent (ese cast vive en
        // PlanillaAsistencia, no en DetalleAsistencia), así que ya
        // llega como string "AAAA-MM-DD" tal cual está en la base.
        return [
            $fila->fecha,
            $fila->area,
            $fila->observaciones,
        ];
    }

    public function title(): string
    {
        return 'Tardanzas';
    }
}

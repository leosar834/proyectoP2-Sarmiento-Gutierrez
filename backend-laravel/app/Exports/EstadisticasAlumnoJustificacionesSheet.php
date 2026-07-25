<?php

namespace App\Exports;

use Illuminate\Support\Collection;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithTitle;

/**
 * Tercera hoja del export de estadísticas individuales: historial
 * completo de justificaciones de la inscripción. A diferencia de la
 * hoja de tardanzas, acá `$fila` sí es un modelo `Justificacion` con
 * sus propios casts de fecha (ver el modelo) — por eso las tres fechas
 * pasan por `?->toDateString()`.
 */
class EstadisticasAlumnoJustificacionesSheet implements FromCollection, WithHeadings, WithMapping, WithTitle, ShouldAutoSize
{
    public function __construct(private readonly Collection $justificaciones)
    {
    }

    public function collection(): Collection
    {
        return $this->justificaciones;
    }

    public function headings(): array
    {
        return ['Fecha inicio', 'Fecha fin', 'Tipo', 'Fecha presentación', 'Área receptora', 'Estado notificación'];
    }

    public function map($fila): array
    {
        return [
            $fila->fecha_inicio?->toDateString(),
            $fila->fecha_fin?->toDateString(),
            $fila->tipo,
            $fila->fecha_presentacion?->toDateString(),
            $fila->area_receptora,
            $fila->estado_notificacion,
        ];
    }

    public function title(): string
    {
        return 'Justificaciones';
    }
}

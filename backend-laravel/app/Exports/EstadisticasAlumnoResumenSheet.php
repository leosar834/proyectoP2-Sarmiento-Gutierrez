<?php

namespace App\Exports;

use Maatwebsite\Excel\Concerns\FromArray;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithStrictNullComparison;
use Maatwebsite\Excel\Concerns\WithTitle;

/**
 * Primera hoja del export de estadísticas individuales: es un solo
 * registro (el alumno de la inscripción pedida), no una lista — por eso
 * se arma como pares Campo/Valor en vez de forzar una fila con muchas
 * columnas. `WithStrictNullComparison` a propósito, mismo motivo que en
 * `FaltasPorCursoExport`: los contadores en 0 (ej. un alumno sin
 * tardanzas) no deben quedar en blanco en la celda.
 */
class EstadisticasAlumnoResumenSheet implements FromArray, WithHeadings, WithTitle, ShouldAutoSize, WithStrictNullComparison
{
    public function __construct(private readonly array $datos)
    {
    }

    public function array(): array
    {
        $alumno = $this->datos['alumno'];
        $contador = $this->datos['contador_general'];

        return [
            ['Alumno', "{$alumno['apellido']}, {$alumno['nombre']}"],
            ['DNI', $alumno['dni']],
            ['Curso', $alumno['curso']],
            ['Faltas teóricas', $contador['faltas_teoricas'] ?? 0],
            ['Faltas taller', $contador['faltas_taller'] ?? 0],
            ['Faltas educación física', $contador['faltas_ed_fisica'] ?? 0],
            ['Faltas (general)', $contador['faltas_general'] ?? 0],
            ['Tardanzas (global)', $contador['tardanzas_global'] ?? 0],
            ['Justificaciones (total)', $contador['justificaciones_total'] ?? 0],
        ];
    }

    public function headings(): array
    {
        return ['Campo', 'Valor'];
    }

    public function title(): string
    {
        return 'Resumen';
    }
}

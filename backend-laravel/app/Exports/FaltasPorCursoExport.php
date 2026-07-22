<?php

namespace App\Exports;

use Illuminate\Support\Collection;
use Maatwebsite\Excel\Concerns\FromCollection;
use Maatwebsite\Excel\Concerns\ShouldAutoSize;
use Maatwebsite\Excel\Concerns\WithHeadings;
use Maatwebsite\Excel\Concerns\WithMapping;
use Maatwebsite\Excel\Concerns\WithStrictNullComparison;

/**
 * Exporta a .xlsx el mismo reporte que
 * ReportesController::faltasPorCurso() ya devuelve en JSON — es el
 * formato de exportación principal que pide la narrativa (RF7). Recibe
 * la colección ya calculada por el controller en vez de volver a
 * consultar la base, para no duplicar la lógica de conteo entre el
 * endpoint JSON y este export.
 *
 * Implementa `WithStrictNullComparison` a propósito: sin este concern,
 * PhpSpreadsheet compara cada valor contra `null` de forma floja y se
 * salta la celda si el valor es "equivalente" a null — lo que incluye
 * un entero `0`. Un alumno sin tardanzas ni faltas justificadas en el
 * período (el caso más común) terminaba con esas dos columnas
 * directamente vacías en vez de en 0, algo que se detectó recién al
 * inspeccionar el XML crudo del .xlsx generado, no por el JSON (que sí
 * mostraba el 0 correctamente, al no pasar por PhpSpreadsheet).
 */
class FaltasPorCursoExport implements FromCollection, WithHeadings, WithMapping, ShouldAutoSize, WithStrictNullComparison
{
    public function __construct(private readonly Collection $alumnos)
    {
    }

    public function collection(): Collection
    {
        return $this->alumnos;
    }

    public function headings(): array
    {
        return [
            'Alumno',
            'DNI',
            'Presentes',
            'Ausentes',
            'Tardanzas',
            'Faltas justificadas',
        ];
    }

    public function map($fila): array
    {
        return [
            "{$fila['alumno']['apellido']}, {$fila['alumno']['nombre']}",
            $fila['alumno']['dni'],
            $fila['presentes'],
            $fila['ausentes'],
            $fila['tardanzas'],
            $fila['faltas_justificadas'],
        ];
    }
}
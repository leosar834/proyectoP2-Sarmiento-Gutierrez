<?php

namespace App\Http\Requests\Api\Reportes;

use Illuminate\Foundation\Http\FormRequest;

/**
 * La narrativa (RF7) distingue reporte "semanal", "mensual" y
 * "trimestral" de faltas por curso, pero ninguno de esos tres períodos
 * tiene una fecha de corte fija en el modelo de datos (no hay tabla de
 * trimestres) — así que en vez de inventar un calendario académico no
 * especificado, el rango se recibe explícito: quien pide el reporte
 * decide qué cuenta como "esta semana", "este mes" o "este trimestre".
 * Los tres tipos de reporte de la narrativa son, en términos de
 * consulta, el mismo reporte con distinto rango de fechas.
 */
class FaltasPorCursoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'curso_id' => ['required', 'integer', 'exists:cursos,id_curso'],
            'fecha_inicio' => ['required', 'date'],
            'fecha_fin' => ['required', 'date', 'after_or_equal:fecha_inicio'],
        ];
    }
}

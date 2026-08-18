<?php

namespace App\Http\Requests\Api\MateriasTaller;

use Illuminate\Foundation\Http\FormRequest;

/**
 * `especialidad_id` es `nullable` a propósito: una materia de ciclo
 * básico (1°/2° año) todavía no tiene orientación asignada en las
 * escuelas técnico-profesionales, donde la especialidad recién se
 * define a partir de 3°/4° año. Ver la migración
 * `make_especialidad_nullable_en_materias_taller`.
 */
class ActualizarMateriaTallerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'especialidad_id' => ['nullable', 'integer', 'exists:especialidades,id_especialidad'],
            'nombre' => ['required', 'string', 'max:100'],
            'regimen_cursada' => ['required', 'string', 'in:anual,trimestral,semestral,personalizado'],
        ];
    }
}

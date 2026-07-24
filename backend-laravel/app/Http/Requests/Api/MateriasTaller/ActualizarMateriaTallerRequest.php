<?php

namespace App\Http\Requests\Api\MateriasTaller;

use Illuminate\Foundation\Http\FormRequest;

class ActualizarMateriaTallerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'especialidad_id' => ['required', 'integer', 'exists:especialidades,id_especialidad'],
            'nombre' => ['required', 'string', 'max:100'],
            'regimen_cursada' => ['required', 'string', 'in:anual,trimestral,semestral,personalizado'],
        ];
    }
}

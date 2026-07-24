<?php

namespace App\Http\Requests\Api\Especialidades;

use Illuminate\Foundation\Http\FormRequest;

class CrearEspecialidadRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:100'],
        ];
    }
}
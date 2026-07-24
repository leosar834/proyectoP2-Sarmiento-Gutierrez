<?php

namespace App\Http\Requests\Api\Alumnos;

use Illuminate\Foundation\Http\FormRequest;

class CrearAlumnoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:100'],
            'apellido' => ['required', 'string', 'max:100'],
            'dni' => ['required', 'string', 'max:20'],
            'fecha_nacimiento' => ['nullable', 'date'],
            'fecha_ingreso_institucion' => ['required', 'date'],
        ];
    }
}

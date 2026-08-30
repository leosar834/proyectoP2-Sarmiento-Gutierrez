<?php

namespace App\Http\Requests\Api\Alumnos;

use Illuminate\Foundation\Http\FormRequest;

class ImportarAlumnosRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'archivo' => ['required', 'file', 'mimes:xlsx,xls', 'max:10240'],
        ];
    }
}

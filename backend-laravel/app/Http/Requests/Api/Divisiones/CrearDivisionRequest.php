<?php

namespace App\Http\Requests\Api\Divisiones;

use Illuminate\Foundation\Http\FormRequest;

class CrearDivisionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:20'],
        ];
    }
}
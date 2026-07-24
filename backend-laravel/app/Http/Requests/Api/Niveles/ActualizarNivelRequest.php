<?php

namespace App\Http\Requests\Api\Niveles;

use Illuminate\Foundation\Http\FormRequest;

class ActualizarNivelRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['sometimes', 'string', 'max:50'],
            'numero_orden' => ['sometimes', 'integer', 'min:1'],
        ];
    }
}
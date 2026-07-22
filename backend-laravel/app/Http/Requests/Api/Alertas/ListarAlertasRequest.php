<?php

namespace App\Http\Requests\Api\Alertas;

use Illuminate\Foundation\Http\FormRequest;

class ListarAlertasRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'estado' => ['nullable', 'in:activa,atendida'],
        ];
    }
}

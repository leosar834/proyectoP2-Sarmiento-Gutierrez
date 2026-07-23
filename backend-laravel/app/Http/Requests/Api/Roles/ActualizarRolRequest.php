<?php

namespace App\Http\Requests\Api\Roles;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Edición parcial de un rol — todos los campos son opcionales, se
 * actualiza solo lo que venga en el body. La unicidad de `nombre` (si
 * se manda) se chequea a mano en el controller, mismo motivo que en
 * `CrearRolRequest`.
 */
class ActualizarRolRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['sometimes', 'string', 'max:100'],
            'descripcion' => ['sometimes', 'nullable', 'string', 'max:255'],
            'activo' => ['sometimes', 'boolean'],
        ];
    }
}
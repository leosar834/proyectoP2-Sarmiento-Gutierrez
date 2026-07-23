<?php

namespace App\Http\Requests\Api\Usuarios;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Reemplaza los roles de un usuario (`sync()`), mismo criterio de
 * reemplazo que `AsignarPermisosRolRequest`. Array vacío permitido a
 * propósito, para poder dejar a un usuario sin ningún rol sin
 * eliminarlo.
 */
class AsignarRolesUsuarioRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'rol_ids' => ['required', 'array'],
            'rol_ids.*' => ['integer', 'exists:roles,id_rol'],
        ];
    }
}
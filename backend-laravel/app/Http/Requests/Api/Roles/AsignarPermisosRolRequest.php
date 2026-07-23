<?php

namespace App\Http\Requests\Api\Roles;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Reemplaza la matriz de permisos de un rol (equivalente a `sync()`,
 * mismo criterio de "reemplazar, no acumular" que ya se usa para los
 * grupos de la Fase 4). Se permite mandar un array vacío a propósito
 * — es la forma de dejar a un rol temporalmente sin ningún permiso,
 * sin tener que borrarlo.
 */
class AsignarPermisosRolRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'permiso_ids' => ['required', 'array'],
            'permiso_ids.*' => ['integer', 'exists:permisos,id_permiso'],
        ];
    }
}
<?php

namespace App\Http\Requests\Api\Roles;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Alta de un rol libre (RF1, "Gestión de roles y usuarios"). Acá solo
 * se valida formato — la unicidad de `nombre` se chequea a mano en el
 * controller, no con `Rule::unique`, porque `uq_roles_nombre` NO
 * incluye `deleted_at` (ver la nota en el modelo `Rol`): un
 * `Rule::unique` simple rechazaría por igual un nombre realmente
 * tomado y uno que pertenece a un rol dado de baja, sin poder avisar
 * cuál de los dos casos es. Mismo criterio que ya se usa para el DNI
 * de `Alumno` en `IngresantesController`.
 */
class CrearRolRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:100'],
            'descripcion' => ['nullable', 'string', 'max:255'],
        ];
    }
}
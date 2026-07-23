<?php

namespace App\Http\Requests\Api\Usuarios;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Alta de un usuario del sistema (preceptor, profesor, administrador,
 * etc. — nunca un alumno, ver nota en el modelo `Usuario`). `email` se
 * valida solo en formato acá: la unicidad real se chequea a mano en el
 * controller, mismo motivo que en `CrearRolRequest` —
 * `uq_usuarios_email` no incluye `deleted_at`.
 *
 * `rol_ids` es opcional: permite asignar los roles iniciales en el
 * mismo paso del alta, sin obligar a un segundo llamado a
 * `asignarRoles`.
 */
class CrearUsuarioRequest extends FormRequest
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
            'email' => ['required', 'string', 'email', 'max:150'],
            'password' => ['required', 'string', 'min:8'],
            'activo' => ['nullable', 'boolean'],
            'rol_ids' => ['nullable', 'array'],
            'rol_ids.*' => ['integer', 'exists:roles,id_rol'],
        ];
    }
}
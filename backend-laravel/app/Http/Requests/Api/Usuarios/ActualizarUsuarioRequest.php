<?php

namespace App\Http\Requests\Api\Usuarios;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Edición parcial de un usuario. `password` es opcional — si no viene,
 * no se toca la contraseña actual. `activo` es el apagado reversible
 * documentado en el modelo `Usuario` (bloquea login sin borrar nada);
 * la baja real (borrado lógico) es un endpoint aparte
 * (`UsuariosController::eliminar`), a propósito, para no confundir los
 * dos conceptos en un solo campo.
 */
class ActualizarUsuarioRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['sometimes', 'string', 'max:100'],
            'apellido' => ['sometimes', 'string', 'max:100'],
            'email' => ['sometimes', 'string', 'email', 'max:150'],
            'password' => ['sometimes', 'string', 'min:8'],
            'activo' => ['sometimes', 'boolean'],
        ];
    }
}
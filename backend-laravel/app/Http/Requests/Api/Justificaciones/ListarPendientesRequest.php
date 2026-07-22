<?php

namespace App\Http\Requests\Api\Justificaciones;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Consulta de justificaciones pendientes de notificación — RF5.
 * `mi_area` es obligatorio porque un mismo usuario podría, en teoría,
 * tener roles de ambos sectores; el cliente indica desde qué sector
 * está mirando la pantalla, y el controller valida que el usuario
 * realmente tenga un rol de ese sector antes de mostrarle nada.
 */
class ListarPendientesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'mi_area' => ['required', 'in:preceptoria,taller'],
        ];
    }
}

<?php

namespace App\Http\Requests\Api\Asistencia;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Corrección de un detalle ya cargado, sin restricción de fecha —
 * exclusivo de jefa de preceptores/administrador (permiso
 * `corregir_asistencia_historica`). El controller es responsable de
 * levantar el override `@permitir_correccion_admin` antes de tocar la
 * fila; este Request solo valida el nuevo estado.
 */
class CorregirDetalleRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'estado' => ['required', 'in:presente,ausente,tardanza,falta_justificada'],
            'observaciones' => ['nullable', 'string', 'max:255'],
        ];
    }
}

<?php

namespace App\Http\Requests\Api\Desenlaces;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Corrección puntual de un desenlace ya inicializado por defecto en
 * `promociona` (ver DesenlacesController::inicializar()). Solo el
 * `tipo_desenlace` es editable acá — `curso_destino_id` no, porque
 * mientras dure la Fase 2 el curso de destino todavía no existe (ver
 * la nota en el modelo `Desenlace`).
 */
class ActualizarDesenlaceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tipo_desenlace' => ['required', 'in:promociona,recursa,egresa,baja'],
        ];
    }
}

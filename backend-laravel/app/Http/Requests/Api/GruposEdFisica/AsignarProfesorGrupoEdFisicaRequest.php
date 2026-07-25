<?php

namespace App\Http\Requests\Api\GruposEdFisica;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Reasigna el profesor de un grupo de educación física ya existente —
 * narrativa RF1: "Asignar un profesor a cada grupo de educación
 * física". La asignación inicial ya la cubre `profesor_id` en
 * `CrearGrupoEdFisicaRequest` (obligatorio, la columna no admite NULL);
 * este Request es para el caso posterior de cambio de profesor a mitad
 * de año, que hasta ahora no tenía ningún endpoint.
 *
 * A diferencia de `AsignarPreceptoresCursoRequest`/
 * `AsignarUsuariosGrupoTallerRequest`, acá `required` simple es
 * correcto: `grupos_ed_fisica.profesor_id` es NOT NULL en el schema —
 * un grupo de ed. física nunca puede quedar sin profesor, así que no
 * existe el caso de "vacío a propósito".
 */
class AsignarProfesorGrupoEdFisicaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'profesor_id' => ['required', 'integer', 'exists:usuarios,id_usuario'],
        ];
    }
}

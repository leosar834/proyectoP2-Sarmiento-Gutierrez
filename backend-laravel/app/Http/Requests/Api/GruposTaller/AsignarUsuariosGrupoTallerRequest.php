<?php

namespace App\Http\Requests\Api\GruposTaller;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Reemplaza (sync, no acumula) el personal de un grupo de taller —
 * narrativa RF1: "Asignar uno o más profesores de taller a cada curso y
 * grupo de taller" + "Asignar uno o más preceptores de taller a cada
 * curso y grupo de taller". Es la misma tabla puente
 * (`usuarios_grupos_taller`) para ambos roles, distinguidos por
 * `rol_en_grupo` — por eso una sola asignación en lote en vez de dos
 * endpoints separados.
 *
 * `present` en vez de `required` en `asignaciones`, mismo motivo que en
 * `AsignarPreceptoresCursoRequest`: hay que poder mandar un array vacío
 * para dejar un grupo temporalmente sin personal.
 *
 * `distinct` en `usuario_id`: sin esto, mandar el mismo usuario dos
 * veces con `rol_en_grupo` distinto pisaría silenciosamente uno con el
 * otro en el `sync()` (las claves del array de sync son los
 * usuario_id) — mejor rechazarlo explícito que dejar que el último
 * gane sin que quien llama se entere.
 */
class AsignarUsuariosGrupoTallerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'asignaciones' => ['present', 'array'],
            'asignaciones.*.usuario_id' => ['required', 'integer', 'distinct', 'exists:usuarios,id_usuario'],
            'asignaciones.*.rol_en_grupo' => ['required', 'in:profesor,preceptor_taller'],
        ];
    }
}

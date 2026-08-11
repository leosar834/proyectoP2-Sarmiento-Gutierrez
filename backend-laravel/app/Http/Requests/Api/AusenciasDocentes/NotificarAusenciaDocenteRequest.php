<?php

namespace App\Http\Requests\Api\AusenciasDocentes;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

/**
 * El profesor elige explícitamente para qué grupo(s) de taller/ed.
 * física hoy no corresponde tomar asistencia, en una sola llamada — no
 * hay un "tildar todo" automático, mismo criterio que /mis-asignaciones
 * para elegir a qué apunta cada acción. `teorica` no es una opción acá
 * — ver el docblock de AusenciaDocente. La fecha nunca viaja en el
 * body: siempre es HOY, la pone el controller con `now()`.
 *
 * `motivo` es único a nivel de la solicitud completa (no por grupo): una
 * misma notificación normalmente cubre un solo motivo para todos los
 * grupos elegidos (ej. el profesor está enfermo y notifica todos sus
 * grupos de hoy de una), así que no tiene sentido pedir un texto por
 * cada grupo. Es opcional — el profesor puede dejarlo vacío.
 */
class NotificarAusenciaDocenteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'grupos' => ['required', 'array', 'min:1'],
            'grupos.*.area' => ['required', 'in:taller,ed_fisica'],
            'grupos.*.grupo_taller_id' => ['required_if:grupos.*.area,taller', 'integer', 'exists:grupos_taller,id_grupo_taller'],
            'grupos.*.grupo_ed_fisica_id' => ['required_if:grupos.*.area,ed_fisica', 'integer', 'exists:grupos_ed_fisica,id_grupo_ed_fisica'],
            'motivo' => ['nullable', 'string', 'max:100'],
        ];
    }

    /**
     * `distinct` no alcanza acá: el identificador real del grupo está
     * repartido entre dos columnas condicionales (`grupo_taller_id` /
     * `grupo_ed_fisica_id`) según el área, así que se arma la clave
     * compuesta a mano para detectar el mismo grupo mandado dos veces
     * en una sola solicitud.
     */
    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator) {
            $grupos = $this->input('grupos', []);
            $vistos = [];

            foreach ($grupos as $indice => $item) {
                if (! is_array($item)) {
                    continue;
                }

                $clave = ($item['area'] ?? '').':'.($item['grupo_taller_id'] ?? $item['grupo_ed_fisica_id'] ?? '');

                if (isset($vistos[$clave])) {
                    $validator->errors()->add("grupos.{$indice}", 'Este grupo ya está repetido en la misma solicitud.');
                }

                $vistos[$clave] = true;
            }
        });
    }
}

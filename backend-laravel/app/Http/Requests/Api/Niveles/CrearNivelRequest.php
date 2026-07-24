<?php

namespace App\Http\Requests\Api\Niveles;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Alta de un nivel/año (RF1, "Gestión de cursos"). `numero_orden` es
 * el dato que de verdad usa el sistema para razonar (narrativa: "el
 * nombre que se muestra en pantalla es solo una etiqueta; lo que el
 * sistema utiliza para razonar es ese número") — toda la lógica de
 * promoción de `AperturaCicloController` depende de que sea correcto y
 * único. La unicidad se chequea a mano en el controller (no
 * `Rule::unique`), mismo motivo que en roles/usuarios:
 * `uq_niveles_orden` no incluye `deleted_at`.
 */
class CrearNivelRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:50'],
            'numero_orden' => ['required', 'integer', 'min:1'],
        ];
    }
}
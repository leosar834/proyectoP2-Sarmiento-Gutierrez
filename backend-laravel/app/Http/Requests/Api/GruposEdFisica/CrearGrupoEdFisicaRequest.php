<?php

namespace App\Http\Requests\Api\GruposEdFisica;

use App\Models\CicloLectivo;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Alta de un grupo de educación física vacío en el ciclo lectivo de la
 * ruta (Fase 4, "redistribución en grupos"). `profesor_id` es
 * obligatorio porque la columna lo es en el schema (`grupos_ed_fisica`
 * tiene un solo profesor por grupo, a diferencia de taller) — no hay
 * forma de crear un grupo sin asignarlo de entrada.
 */
class CrearGrupoEdFisicaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        /** @var CicloLectivo $ciclo */
        $ciclo = $this->route('ciclo');

        return [
            'nombre_grupo' => [
                'required',
                'string',
                'max:50',
                Rule::unique('grupos_ed_fisica', 'nombre_grupo')->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo),
            ],
            'regimen_cursada' => ['required', 'in:anual,trimestral,semestral,personalizado'],
            'profesor_id' => ['required', 'integer', 'exists:usuarios,id_usuario'],
        ];
    }
}
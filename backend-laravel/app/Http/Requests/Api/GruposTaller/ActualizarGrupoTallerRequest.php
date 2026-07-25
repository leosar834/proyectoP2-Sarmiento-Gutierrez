<?php

namespace App\Http\Requests\Api\GruposTaller;

use App\Models\GrupoTaller;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ActualizarGrupoTallerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        // Deliberadamente solo `nombre_grupo`. `materia_taller_id`/
        // `nivel_id`/`ciclo_lectivo_id` son la identidad del grupo (la
        // unique key compuesta `uq_grupos_taller` se arma sobre esos
        // tres + el nombre) — mismo criterio que `ActualizarCursoRequest`:
        // "editarlos" convertiría este grupo en otro distinto, con el
        // riesgo de arrastrar inscripciones/planillas que ya referencian
        // este id_grupo_taller a una materia/nivel equivocado.
        /** @var GrupoTaller $grupo */
        $grupo = $this->route('grupo');

        return [
            'nombre_grupo' => [
                'required',
                'string',
                'max:50',
                Rule::unique('grupos_taller', 'nombre_grupo')
                    ->where('materia_taller_id', $grupo->materia_taller_id)
                    ->where('nivel_id', $grupo->nivel_id)
                    ->where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                    ->ignore($grupo->id_grupo_taller, 'id_grupo_taller'),
            ],
        ];
    }
}

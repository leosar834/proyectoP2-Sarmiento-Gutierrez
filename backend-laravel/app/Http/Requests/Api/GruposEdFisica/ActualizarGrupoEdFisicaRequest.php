<?php

namespace App\Http\Requests\Api\GruposEdFisica;

use App\Models\GrupoEdFisica;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ActualizarGrupoEdFisicaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        // `profesor_id` queda afuera a propósito: ya tiene su propio
        // endpoint (`GruposEdFisicaController::asignarProfesor`), no
        // hace falta duplicar esa responsabilidad acá.
        /** @var GrupoEdFisica $grupo */
        $grupo = $this->route('grupo');

        return [
            'nombre_grupo' => [
                'required',
                'string',
                'max:50',
                Rule::unique('grupos_ed_fisica', 'nombre_grupo')
                    ->where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                    ->ignore($grupo->id_grupo_ed_fisica, 'id_grupo_ed_fisica'),
            ],
            'regimen_cursada' => ['required', 'in:anual,trimestral,semestral,personalizado'],
        ];
    }
}

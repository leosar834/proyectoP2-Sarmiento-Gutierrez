<?php

namespace App\Http\Requests\Api\GruposTaller;

use App\Models\GrupoTaller;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Asignación por lote a un grupo de taller — mismo patrón que
 * `AsignarLoteEdFisicaRequest` (curso/división/especialidad como
 * filtro amplio, o `inscripcion_ids` para selección manual cuando el
 * filtro no alcanza, ej. separar por sexo). `curso_id`, además de
 * pertenecer al ciclo del grupo, tiene que ser del mismo `nivel_id`
 * que el grupo — un grupo de taller es específico de un nivel, no
 * tiene sentido cargarle alumnos de otro año.
 *
 * Al menos una de las cuatro formas es obligatoria, igual que en
 * educación física: sin ninguna, el lote sería "todo el ciclo".
 */
class AsignarLoteTallerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        /** @var GrupoTaller $grupo */
        $grupo = $this->route('grupo');

        return [
            'inscripcion_ids' => [
                'nullable',
                'array',
                'min:1',
                'required_without_all:curso_id,division_id,especialidad_id',
            ],
            'inscripcion_ids.*' => [
                'integer',
                Rule::exists('inscripciones', 'id_inscripcion')
                    ->where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                    ->where('estado', 'activo'),
            ],
            'curso_id' => [
                'nullable',
                'integer',
                'required_without_all:division_id,especialidad_id,inscripcion_ids',
                Rule::exists('cursos', 'id_curso')
                    ->where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                    ->where('nivel_id', $grupo->nivel_id),
            ],
            'division_id' => [
                'nullable',
                'integer',
                'required_without_all:curso_id,especialidad_id,inscripcion_ids',
                'exists:divisiones,id_division',
            ],
            'especialidad_id' => [
                'nullable',
                'integer',
                'required_without_all:curso_id,division_id,inscripcion_ids',
                'exists:especialidades,id_especialidad',
            ],
        ];
    }
}
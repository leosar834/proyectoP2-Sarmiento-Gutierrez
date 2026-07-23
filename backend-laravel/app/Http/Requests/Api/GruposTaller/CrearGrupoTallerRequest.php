<?php

namespace App\Http\Requests\Api\GruposTaller;

use App\Models\CicloLectivo;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Alta de un grupo de taller vacío en el ciclo lectivo de la ruta
 * (Fase 4, "redistribución en grupos"). A diferencia de educación
 * física, acá no hay profesor obligatorio de entrada (el vínculo con
 * profesores/preceptor de taller va por la tabla puente
 * `usuarios_grupos_taller`, que no gestiona este endpoint — está fuera
 * del alcance de "distribución de alumnos" que cubre la Fase 4).
 *
 * La unicidad del nombre se valida igual que en el schema
 * (`uq_grupos_taller`): por materia + nivel + ciclo, no global — puede
 * haber "Grupo 1" en dos materias distintas del mismo ciclo sin que
 * choquen entre sí.
 */
class CrearGrupoTallerRequest extends FormRequest
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
            'materia_taller_id' => ['required', 'integer', 'exists:materias_taller,id_materia_taller'],
            'nivel_id' => ['required', 'integer', 'exists:niveles,id_nivel'],
            'nombre_grupo' => [
                'required',
                'string',
                'max:50',
                Rule::unique('grupos_taller', 'nombre_grupo')
                    ->where('materia_taller_id', $this->input('materia_taller_id'))
                    ->where('nivel_id', $this->input('nivel_id'))
                    ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo),
            ],
        ];
    }
}
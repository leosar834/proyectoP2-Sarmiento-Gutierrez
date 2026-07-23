<?php

namespace App\Http\Requests\Api\GruposEdFisica;

use App\Models\GrupoEdFisica;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Asignación por lote a un grupo de educación física — narrativa:
 * "herramientas de asignación por lote —asignar grupos completos,
 * filtrar por especialidad o por división—".
 *
 * Se suma una cuarta forma de seleccionar, `inscripcion_ids`, para
 * casos que los filtros amplios no pueden armar solos — por ejemplo,
 * separar varones y mujeres dentro de un mismo curso: el schema no
 * tiene ningún campo de sexo/género en `alumnos`, así que esa
 * distinción no se puede derivar con curso/división/especialidad. Acá
 * el administrador manda la lista exacta de inscripciones (tildadas a
 * mano en la pantalla del curso) en vez de un filtro.
 *
 * Al menos UNA de las cuatro formas es obligatoria a propósito: sin
 * ninguna, el lote sería "todas las inscripciones activas del ciclo",
 * que nunca es la intención real de este endpoint.
 */
class AsignarLoteEdFisicaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        /** @var GrupoEdFisica $grupo */
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
                Rule::exists('cursos', 'id_curso')->where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id),
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
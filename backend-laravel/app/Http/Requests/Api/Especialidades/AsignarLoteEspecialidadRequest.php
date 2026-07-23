<?php

namespace App\Http\Requests\Api\Especialidades;

use App\Models\CicloLectivo;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Distribución de especialidades (Fase 4, última pieza): asigna
 * `especialidad_id` a un lote de inscripciones del ciclo. Mismo patrón
 * de selección que `AsignarLoteTallerRequest`/`AsignarLoteEdFisicaRequest`
 * — curso/división/nivel como filtro amplio, o `inscripcion_ids` para
 * selección manual —, pero acá el filtro usa `nivel_id` en vez de
 * `especialidad_id`, porque la especialidad es justamente lo que se
 * está asignando, no algo por lo que ya se pueda filtrar.
 *
 * No hay ninguna marca en el schema de "primer año del ciclo superior"
 * — y no hace falta: la narrativa describe este paso como una tarea
 * manual del administrador ("ocurre una sola vez por camada"), así que
 * es la propia institución la que elige el curso/nivel correcto al
 * llamar este endpoint, igual que ya elige a mano los cursos al armar
 * grupos de taller o educación física.
 */
class AsignarLoteEspecialidadRequest extends FormRequest
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
            'especialidad_id' => ['required', 'integer', 'exists:especialidades,id_especialidad'],

            'inscripcion_ids' => [
                'nullable',
                'array',
                'min:1',
                'required_without_all:curso_id,division_id,nivel_id',
            ],
            'inscripcion_ids.*' => [
                'integer',
                Rule::exists('inscripciones', 'id_inscripcion')
                    ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
                    ->where('estado', 'activo'),
            ],
            'curso_id' => [
                'nullable',
                'integer',
                'required_without_all:division_id,nivel_id,inscripcion_ids',
                Rule::exists('cursos', 'id_curso')->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo),
            ],
            'division_id' => [
                'nullable',
                'integer',
                'required_without_all:curso_id,nivel_id,inscripcion_ids',
                'exists:divisiones,id_division',
            ],
            'nivel_id' => [
                'nullable',
                'integer',
                'required_without_all:curso_id,division_id,inscripcion_ids',
                'exists:niveles,id_nivel',
            ],
        ];
    }
}
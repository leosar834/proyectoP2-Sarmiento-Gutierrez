<?php

namespace App\Http\Requests\Api\Cursos;

use Illuminate\Foundation\Http\FormRequest;

class ActualizarCursoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        // Deliberadamente solo `turno`. `nivel_id`/`division_id`/
        // `ciclo_lectivo_id` son la identidad del curso (son la unique
        // key compuesta uq_cursos_nivel_division_ciclo) — "editarlos"
        // sería en realidad convertir este curso en otro distinto, con
        // el riesgo de arrastrar inscripciones/planillas que ya
        // referencian este id_curso a un nivel/división equivocado. Si
        // el curso está mal creado, la vía correcta es eliminarlo (si
        // todavía no tiene inscripciones) y crear el correcto.
        return [
            'turno' => ['required', 'string', 'in:mañana,tarde,noche'],
        ];
    }
}

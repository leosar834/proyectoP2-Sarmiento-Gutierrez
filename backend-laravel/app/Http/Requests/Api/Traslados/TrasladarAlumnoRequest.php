<?php

namespace App\Http\Requests\Api\Traslados;

use App\Models\CicloLectivo;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Traslado manual de un alumno a un curso del ciclo lectivo abierto —
 * narrativa: "permanecen disponibles los traslados manuales para los
 * casos que rompen la regla general, como recursantes, cambios de
 * división o el regreso de egresados". `curso_id` tiene que ser un curso
 * de ESE ciclo (se valida acá el formato; que el ciclo esté abierto se
 * valida en el controlador porque necesita cargarlo).
 *
 * `condicion` es una decisión explícita del administrador en cada
 * traslado (¿el alumno queda regular o recursante en el curso de
 * destino?) — no se infiere, para no adivinar sobre algo que es
 * justamente la razón de ser de un traslado manual.
 */
class TrasladarAlumnoRequest extends FormRequest
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
            'alumno_id' => ['required', 'integer'],
            'curso_id' => [
                'required',
                'integer',
                Rule::exists('cursos', 'id_curso')->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo),
            ],
            'condicion' => ['required', 'string', 'in:regular,recursante'],
            // Nullable a propósito: si no viene, el controlador la hereda
            // de la inscripción más reciente del alumno (memoria del
            // legajo, mismo criterio que ya usa AperturaCicloController
            // al promocionar) en vez de borrarla sin querer.
            'especialidad_id' => ['nullable', 'integer', 'exists:especialidades,id_especialidad'],
        ];
    }
}

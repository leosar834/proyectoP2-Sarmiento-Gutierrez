<?php

namespace App\Http\Requests\Api\Asistencia;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Abre la planilla del día para un curso o grupo. Siempre es HOY —
 * crear una planilla para una fecha pasada no es un caso de este
 * endpoint (eso es corrección histórica, ver CorregirDetalleRequest);
 * el propio trigger `trg_planillas_before_insert` de MySQL solo exige
 * el permiso diario abierto cuando `fecha = CURDATE()`, así que ni
 * tiene sentido dejar que el cliente mande otra fecha acá.
 */
class CrearPlanillaRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'area' => ['required', 'in:teorica,taller,ed_fisica'],
            'curso_id' => ['required_if:area,teorica', 'integer', 'exists:cursos,id_curso'],
            'grupo_taller_id' => ['required_if:area,taller', 'integer', 'exists:grupos_taller,id_grupo_taller'],
            'grupo_ed_fisica_id' => ['required_if:area,ed_fisica', 'integer', 'exists:grupos_ed_fisica,id_grupo_ed_fisica'],
        ];
    }
}

<?php

namespace App\Http\Requests\Api\Institucion;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Edición de la ficha de la institución (ver InstitucionController y
 * App\Models\Institucion). Mismas reglas de identificación que el
 * bloque `institucion.*` de RegistroAdministradorRequest, pero acá
 * planas (no anidadas) porque este endpoint es exclusivamente esto, sin
 * datos de usuario alrededor — MÁS `modalidad`, que a propósito no está
 * en el registro inicial (ver el docblock de App\Models\Institucion):
 * se elige acá, después, nunca en el alta.
 */
class ActualizarInstitucionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:150'],
            'domicilio' => ['required', 'string', 'max:200'],
            'cue' => ['required', 'string', 'max:20'],
            'localidad' => ['required', 'string', 'max:100'],
            'provincia' => ['required', 'string', 'max:100'],
            'modalidad' => ['required', 'string', 'in:tecnico_profesional_contraturno,secundaria_comun_orientaciones'],
        ];
    }
}

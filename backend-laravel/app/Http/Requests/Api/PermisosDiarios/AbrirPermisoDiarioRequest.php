<?php

namespace App\Http\Requests\Api\PermisosDiarios;

use Illuminate\Foundation\Http\FormRequest;

/**
 * `hora_limite` es opcional — si no viene, el controller usa el mismo
 * default que la columna en la base (`23:59:59`, narrativa/doc_bd
 * sección 6.5). Se deja como override puntual por si algún día se abre
 * el permiso más tarde de lo habitual y hace falta acortar la ventana
 * de ese día en particular, sin tocar el default de la institución.
 */
class AbrirPermisoDiarioRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'hora_limite' => ['nullable', 'date_format:H:i:s'],
        ];
    }
}

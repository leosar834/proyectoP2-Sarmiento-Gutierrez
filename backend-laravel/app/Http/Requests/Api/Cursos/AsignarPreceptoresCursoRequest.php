<?php

namespace App\Http\Requests\Api\Cursos;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Reemplaza (sync, no acumula) los preceptores responsables de un
 * curso — narrativa RF1: "Asignar uno o más preceptores responsables a
 * cada curso y división".
 *
 * A propósito `present` en vez de `required`: `required` de Laravel
 * considera "vacío" (y por lo tanto inválido) a un array con 0
 * elementos, lo que impediría mandar `"usuario_ids": []` para dejar un
 * curso temporalmente sin preceptor asignado — un caso real (ej. el
 * preceptor titular se da de baja y todavía no se nombró reemplazo).
 * `present` solo exige que la clave venga en el body, sin importar si
 * el array está vacío.
 */
class AsignarPreceptoresCursoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'usuario_ids' => ['present', 'array'],
            'usuario_ids.*' => ['integer', 'exists:usuarios,id_usuario'],
        ];
    }
}

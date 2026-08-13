<?php

namespace App\Http\Requests\Api\CiclosLectivos;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Alta del PRIMER ciclo lectivo de una instalación nueva — ver el
 * docblock de `CiclosLectivosController::crear()`. A diferencia de
 * `AbrirCicloRequest` (Fase 3, abrir el siguiente), acá no hay ningún
 * ciclo anterior del que tomar el año para comparar: la única regla es
 * que el año no se repita, algo que ya cubre `unique` sobre la tabla.
 */
class CrearCicloRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'anio' => ['required', 'integer', 'min:2000', 'max:2100', 'unique:ciclos_lectivos,anio'],
            'fecha_inicio' => ['required', 'date'],
        ];
    }
}

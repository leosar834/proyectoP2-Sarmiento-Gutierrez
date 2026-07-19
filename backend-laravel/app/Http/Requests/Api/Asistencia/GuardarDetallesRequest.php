<?php

namespace App\Http\Requests\Api\Asistencia;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Carga o corrige el estado de una lista de alumnos dentro de la
 * planilla del día — un solo POST con todo el curso/grupo, tal como lo
 * describe RF2 ("el preceptor marca el estado de cada alumno... el
 * sistema valida que todos tengan un estado asignado antes de
 * confirmar"). No es upsert parcial de a uno: el cliente manda la
 * planilla completa cada vez que guarda.
 */
class GuardarDetallesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'detalles' => ['required', 'array', 'min:1'],
            'detalles.*.inscripcion_id' => ['required', 'integer', 'exists:inscripciones,id_inscripcion'],
            'detalles.*.estado' => ['required', 'in:presente,ausente,tardanza,falta_justificada'],
            'detalles.*.observaciones' => ['nullable', 'string', 'max:255'],
        ];
    }
}

<?php

namespace App\Http\Requests\Api\Traslados;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Baja de UNA inscripción puntual a mitad de año (abandono, traslado a
 * otra institución, etc.) — distinto del desenlace de fin de ciclo
 * (`DesenlacesController`, Fase 2) y distinto de eliminar el legajo
 * (`AlumnosController::eliminar`). El legajo del alumno no se toca.
 */
class DarDeBajaInscripcionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'motivo_baja' => ['required', 'string', 'max:255'],
            // Nullable a propósito: si no se manda, se usa la fecha de
            // hoy — mismo criterio de default que ya usa
            // AperturaCicloController para fecha_baja.
            'fecha_baja' => ['nullable', 'date'],
        ];
    }
}

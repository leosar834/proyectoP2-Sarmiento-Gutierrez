<?php

namespace App\Http\Requests\Api\CiclosLectivos;

use App\Models\CicloLectivo;
use Illuminate\Foundation\Http\FormRequest;

/**
 * Fase 3 del "Proceso de Cierre y Apertura en Cuatro Fases": el
 * administrador da de alta el ciclo lectivo siguiente indicando su año
 * y fecha de inicio — el resto (clonar cursos, generar inscripciones
 * según los desenlaces ya definidos en la Fase 2) lo hace el sistema,
 * ver AperturaCicloController.
 */
class AbrirCicloRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        /** @var CicloLectivo $cicloAnterior */
        $cicloAnterior = $this->route('ciclo');

        return [
            'anio' => ['required', 'integer', 'gt:' . $cicloAnterior->anio, 'unique:ciclos_lectivos,anio'],
            'fecha_inicio' => ['required', 'date'],
        ];
    }
}
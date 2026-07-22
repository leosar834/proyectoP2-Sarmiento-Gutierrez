<?php

namespace App\Http\Requests\Api\Justificaciones;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Alta de una justificación (RF5). `area_receptora` viaja explícito en
 * vez de inferirse en silencio del rol del usuario, porque el
 * controller necesita cruzarlo contra los roles reales de quien la
 * carga — un dato que el cliente puede errar, no algo de lo que fiarse
 * ciegamente (ver `JustificacionesController::usuarioPuedeRecibirEn()`).
 */
class RegistrarJustificacionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'inscripcion_id' => ['required', 'integer', 'exists:inscripciones,id_inscripcion'],
            'fecha_inicio' => ['required', 'date'],
            'fecha_fin' => ['required', 'date', 'after_or_equal:fecha_inicio'],
            'tipo' => ['required', 'in:certificado_medico,nota_tutor'],
            'fecha_presentacion' => ['required', 'date'],
            'area_receptora' => ['required', 'in:preceptoria,taller'],
        ];
    }
}

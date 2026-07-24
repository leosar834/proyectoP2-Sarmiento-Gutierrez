<?php

namespace App\Http\Requests\Api\Asistencia;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Consulta de planilla propia (narrativa, permisos exclusivos de
 * plataforma móvil: "lectura de la asistencia de los cursos asignados
 * al usuario, navegable por cualquier mes del ciclo lectivo en curso").
 * Mismo esquema de área + id que CrearPlanillaRequest, más el mes a
 * consultar.
 */
class ConsultarPlanillasRequest extends FormRequest
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
            // Formato AAAA-MM: se navega mes a mes (calendario), no
            // fecha a fecha — eso ya lo cubre crear()/una planilla
            // puntual. A propósito no se limita el rango acá: pedir un
            // mes anterior al inicio del ciclo o posterior a hoy
            // simplemente no trae planillas (no hay nada que rechazar
            // explícitamente, el cliente interpreta "vacío" como límite
            // del calendario).
            'mes' => ['required', 'date_format:Y-m'],
        ];
    }
}

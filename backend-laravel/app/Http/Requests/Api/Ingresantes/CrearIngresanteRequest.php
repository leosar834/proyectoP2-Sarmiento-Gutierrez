<?php

namespace App\Http\Requests\Api\Ingresantes;

use App\Models\CicloLectivo;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Alta de un ingresante nuevo (Fase 4, "población manual de lo que
 * falta"): crea el legajo y su inscripción en un curso de primer año
 * del ciclo lectivo indicado en la ruta. `curso_id` tiene que ser un
 * curso de ESE ciclo — que además tiene que ser de nivel uno, algo que
 * se valida en el controlador porque necesita cargar la relación
 * `nivel` (acá solo se valida formato).
 */
class CrearIngresanteRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        /** @var CicloLectivo $ciclo */
        $ciclo = $this->route('ciclo');

        return [
            'nombre' => ['required', 'string', 'max:100'],
            'apellido' => ['required', 'string', 'max:100'],
            'dni' => ['required', 'string', 'max:20'],
            'fecha_nacimiento' => ['nullable', 'date'],
            'fecha_ingreso_institucion' => ['required', 'date'],
            'curso_id' => [
                'required',
                'integer',
                Rule::exists('cursos', 'id_curso')->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo),
            ],
        ];
    }
}
<?php

namespace App\Http\Requests\Api\Cursos;

use Illuminate\Foundation\Http\FormRequest;

class CrearCursoRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nivel_id' => ['required', 'integer', 'exists:niveles,id_nivel'],
            'division_id' => ['required', 'integer', 'exists:divisiones,id_division'],
            // Los valores del enum en la base son con tilde/ñ literal
            // ('mañana'). Si al probar con curl/PowerShell da "the turno
            // field is required" pese a estar presente, es el mismo
            // problema de encoding (BOM de Out-File -Encoding utf8) que
            // ya se vio con "año" en niveles — no es un bug de esta regla.
            'turno' => ['required', 'string', 'in:mañana,tarde,noche'],
        ];
    }
}

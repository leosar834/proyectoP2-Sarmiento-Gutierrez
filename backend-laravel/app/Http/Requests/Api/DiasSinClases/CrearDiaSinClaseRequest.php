<?php

namespace App\Http\Requests\Api\DiasSinClases;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CrearDiaSinClaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        // uq_dias_sin_clases es (fecha, alcance) — si no viene `alcance`
        // en el body, el default es 'todos' (igual que la columna en la
        // base), así que el chequeo de unicidad tiene que usar ese mismo
        // default para no dejar pasar un duplicado silencioso.
        $alcance = $this->input('alcance', 'todos');

        return [
            'fecha' => [
                'required',
                'date',
                Rule::unique('dias_sin_clases', 'fecha')->where(fn ($query) => $query->where('alcance', $alcance)),
            ],
            'motivo' => ['required', 'string', 'max:100'],
            'alcance' => ['nullable', 'string', 'in:todos,mañana,tarde,noche'],
        ];
    }
}

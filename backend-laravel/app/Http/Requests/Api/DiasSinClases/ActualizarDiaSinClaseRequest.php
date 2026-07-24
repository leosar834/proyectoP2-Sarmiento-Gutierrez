<?php

namespace App\Http\Requests\Api\DiasSinClases;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ActualizarDiaSinClaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $alcance = $this->input('alcance', 'todos');
        $diaSinClaseActual = $this->route('diaSinClase');

        return [
            'fecha' => [
                'required',
                'date',
                Rule::unique('dias_sin_clases', 'fecha')
                    ->where(fn ($query) => $query->where('alcance', $alcance))
                    ->ignore($diaSinClaseActual?->id_dia_sin_clase, 'id_dia_sin_clase'),
            ],
            'motivo' => ['required', 'string', 'max:100'],
            'alcance' => ['nullable', 'string', 'in:todos,mañana,tarde,noche'],
        ];
    }
}

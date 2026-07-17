<?php

namespace App\Http\Requests\Api\Auth;

use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * `plataforma` es obligatoria: el cliente (app Flutter o Flutter web)
     * declara desde dónde entra, y esa declaración queda grabada en el
     * token — ver AuthController::login().
     */
    public function rules(): array
    {
        return [
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'plataforma' => ['required', 'in:movil,escritorio'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ];
    }
}

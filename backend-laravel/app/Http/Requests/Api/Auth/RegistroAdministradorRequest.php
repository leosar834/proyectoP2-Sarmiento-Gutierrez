<?php

namespace App\Http\Requests\Api\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Datos del primer administrador (ver RegistroAdministradorController).
 * No incluye `plataforma` como LoginRequest — este alta es siempre de
 * escritorio, no hace falta que el cliente lo declare.
 *
 * A diferencia de `CrearUsuarioRequest` (que no pide confirmación de
 * contraseña, porque ahí la carga un administrador para un tercero),
 * acá sí se pide `password_confirmation`: es la propia persona
 * escribiendo su contraseña por primera vez, sin nadie más que pueda
 * revisarla — el boceto original resolvía esto con "Vincular con
 * Google" (sin contraseña propia), pero el sistema no tiene integración
 * con Google; con contraseña propia, confirmarla es la salvaguarda
 * equivalente más simple.
 *
 * También pide, anidados bajo `institucion`, los datos de la ficha de
 * la institución (nombre, domicilio, CUE, localidad, provincia — ver
 * App\Models\Institucion): el sistema los exige desde este mismo
 * formulario, en vez de un paso de alta de institución separado, para
 * que el establecimiento quede identificado desde el primer momento sin
 * introducir soporte multi-institución que el sistema no tiene.
 */
class RegistroAdministradorRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'nombre' => ['required', 'string', 'max:100'],
            'apellido' => ['required', 'string', 'max:100'],
            'email' => ['required', 'string', 'email', 'max:150'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],

            'institucion' => ['required', 'array'],
            'institucion.nombre' => ['required', 'string', 'max:150'],
            'institucion.domicilio' => ['required', 'string', 'max:200'],
            'institucion.cue' => ['required', 'string', 'max:20'],
            'institucion.localidad' => ['required', 'string', 'max:100'],
            'institucion.provincia' => ['required', 'string', 'max:100'],
        ];
    }
}

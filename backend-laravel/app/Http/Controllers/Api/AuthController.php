<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Auth\LoginRequest;
use App\Http\Resources\UsuarioResource;
use App\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * Login por email + password. `plataforma` (movil|escritorio) queda
     * grabada como ability del token Sanctum: todo lo que se pida más
     * adelante con ese token queda acotado a esa plataforma sin importar
     * qué mande el cliente en headers de requests posteriores — ver
     * narrativa, "el permiso no se traslada de un dispositivo al otro".
     * El corte real permiso-por-permiso (tienePermiso() + la ability del
     * token) se resuelve en policies/middleware, en el próximo paso.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $datos = $request->validated();

        // SoftDeletes ya excluye acá a los usuarios borrados lógicamente
        // (Eloquent agrega WHERE deleted_at IS NULL por default).
        $usuario = Usuario::where('email', $datos['email'])->first();

        if (! $usuario || ! Hash::check($datos['password'], $usuario->password)) {
            throw ValidationException::withMessages([
                'email' => ['Las credenciales no son válidas.'],
            ]);
        }

        if (! $usuario->activo) {
            throw ValidationException::withMessages([
                'email' => ['Este usuario está desactivado. Contactá a la administración.'],
            ]);
        }

        $token = $usuario->createToken(
            $datos['device_name'] ?? $request->userAgent() ?? 'token',
            ["plataforma:{$datos['plataforma']}"]
        );

        return response()->json([
            'token' => $token->plainTextToken,
            'plataforma' => $datos['plataforma'],
            'usuario' => new UsuarioResource($usuario->load('roles')),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['mensaje' => 'Sesión cerrada.']);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json(
            new UsuarioResource($request->user()->load('roles'))
        );
    }
}

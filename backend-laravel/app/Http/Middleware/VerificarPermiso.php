<?php

namespace App\Http\Middleware;

use App\Models\Permiso;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Aplica el corte de autorización de dos pasos que describe la narrativa
 * ("Capa de Permisos" + "el permiso no se traslada de un dispositivo al
 * otro"):
 *
 *   1. La plataforma del PERMISO (fija, catálogo del sistema) tiene que
 *      coincidir con la plataforma sellada en el token en el login
 *      (ability `plataforma:movil` o `plataforma:escritorio`, ver
 *      AuthController::login()). Este es el "techo": ni el usuario más
 *      autorizado puede ejercer un permiso de escritorio logueado desde
 *      el móvil, o viceversa — el dispositivo con el que entró lo
 *      determina el token, no lo que declare el cliente en cada request.
 *   2. El ROL del usuario (libre, definido por la institución) tiene que
 *      incluir ese permiso — Usuario::tienePermiso().
 *
 * Uso en rutas, encadenado con auth:sanctum:
 *   Route::middleware(['auth:sanctum', 'permiso:tomar_asistencia'])->post(...);
 */
class VerificarPermiso
{
    public function handle(Request $request, Closure $next, string $nombrePermiso): Response
    {
        $permiso = Permiso::where('nombre', $nombrePermiso)->first();

        abort_if(
            ! $permiso,
            500,
            "Permiso '{$nombrePermiso}' no existe en el catálogo fijo — revisa el nombre usado en la ruta."
        );

        $usuario = $request->user();

        abort_unless(
            $usuario->currentAccessToken()?->can("plataforma:{$permiso->plataforma}"),
            403,
            'Esta operación no está disponible desde la plataforma con la que iniciaste sesión.'
        );

        abort_unless(
            $usuario->tienePermiso($nombrePermiso),
            403,
            'Tu rol no tiene el permiso necesario para esta operación.'
        );

        return $next($request);
    }
}

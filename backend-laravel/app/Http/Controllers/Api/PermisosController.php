<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Permiso;
use Illuminate\Http\JsonResponse;

/**
 * Catálogo FIJO de permisos del sistema (tabla `permisos`, narrativa
 * "Capa de Permisos (fija, definida por el sistema)") — ver el docblock
 * del modelo `Permiso`. Solo lectura: no hay `crear`/`actualizar`/
 * `eliminar` a propósito, la institución no lo edita, solo elige qué
 * permisos de esta lista le da a cada rol (`RolesController::
 * asignarPermisos`).
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de roles y usuarios — la pantalla "Roles y permisos" necesita
 * esta lista completa para armar el checklist de cada rol.
 */
class PermisosController extends Controller
{
    public function index(): JsonResponse
    {
        $permisos = Permiso::orderBy('plataforma')->orderBy('nombre')->get();

        return response()->json([
            'data' => $permisos->map(fn (Permiso $permiso) => [
                'id_permiso' => $permiso->id_permiso,
                'nombre' => $permiso->nombre,
                'plataforma' => $permiso->plataforma,
                'descripcion' => $permiso->descripcion,
            ])->values(),
        ]);
    }
}

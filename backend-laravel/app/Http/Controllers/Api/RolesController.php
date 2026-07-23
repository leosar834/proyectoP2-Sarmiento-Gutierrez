<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Roles\ActualizarRolRequest;
use App\Http\Requests\Api\Roles\AsignarPermisosRolRequest;
use App\Http\Requests\Api\Roles\CrearRolRequest;
use App\Models\Rol;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * RF1, "Gestión de roles y usuarios": alta/edición/baja de roles
 * libres (definidos por la institución, narrativa "Modelo de Roles y
 * Permisos Configurable") y la asignación de permisos del catálogo
 * fijo a cada uno.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión general del sistema.
 */
class RolesController extends Controller
{
    public function crear(CrearRolRequest $request): JsonResponse
    {
        $this->verificarNombreDisponible($request->validated('nombre'));

        $rol = Rol::create([
            'nombre' => $request->validated('nombre'),
            'descripcion' => $request->validated('descripcion'),
        ]);

        // `activo` tiene default a nivel de base — el objeto recién
        // creado en memoria no lo trae hasta refrescarlo.
        return response()->json(['data' => $this->formatearRol($rol->fresh())], 201);
    }

    public function index(): JsonResponse
    {
        $roles = Rol::withCount('usuarios')->with('permisos')->get();

        return response()->json([
            'data' => $roles->map(fn (Rol $rol) => $this->formatearRol($rol))->values(),
        ]);
    }

    public function actualizar(ActualizarRolRequest $request, Rol $rol): JsonResponse
    {
        $nombreNuevo = $request->validated('nombre');
        if ($nombreNuevo !== null && $nombreNuevo !== $rol->nombre) {
            $this->verificarNombreDisponible($nombreNuevo, $rol->id_rol);
        }

        $rol->update($request->validated());

        return response()->json(['data' => $this->formatearRol($rol->fresh(['permisos']))]);
    }

    /**
     * Baja lógica (SoftDeletes) — no bloquea si hay usuarios con este
     * rol asignado: es reversible, y Eloquent ya excluye los roles
     * borrados de `Usuario::roles()` automáticamente (scope global de
     * SoftDeletes aplicado también del lado "belongsToMany"), sin
     * necesidad de tocar la tabla puente acá.
     */
    public function eliminar(Rol $rol): JsonResponse
    {
        $rol->delete();

        return response()->json(['data' => ['id_rol' => $rol->id_rol, 'eliminado' => true]]);
    }

    public function asignarPermisos(AsignarPermisosRolRequest $request, Rol $rol): JsonResponse
    {
        $rol->permisos()->sync($request->validated('permiso_ids'));

        return response()->json([
            'data' => $this->formatearRol($rol->fresh(['permisos'])),
        ]);
    }

    /**
     * `uq_roles_nombre` no incluye `deleted_at` (ver nota en el modelo
     * `Rol`), así que un nombre "libre" en la UI puede en realidad
     * pertenecer a un rol dado de baja — se avisa distinto en ese caso
     * en vez de un genérico "ya está tomado".
     */
    private function verificarNombreDisponible(string $nombre, ?int $idRolExcluido = null): void
    {
        $existente = Rol::withTrashed()
            ->where('nombre', $nombre)
            ->when($idRolExcluido, fn ($q) => $q->where('id_rol', '!=', $idRolExcluido))
            ->first();

        if ($existente !== null) {
            throw ValidationException::withMessages([
                'nombre' => [$existente->trashed()
                    ? "Ya existe un rol con este nombre (id {$existente->id_rol}), pero está dado de baja — hay que restaurarlo en vez de crear uno nuevo."
                    : "Ya existe un rol con este nombre (id {$existente->id_rol})."],
            ]);
        }
    }

    private function formatearRol(Rol $rol): array
    {
        return [
            'id_rol' => $rol->id_rol,
            'nombre' => $rol->nombre,
            'descripcion' => $rol->descripcion,
            'activo' => $rol->activo,
            'cantidad_usuarios' => $rol->usuarios_count ?? $rol->usuarios()->count(),
            'permisos' => $rol->permisos->map(fn ($p) => [
                'id_permiso' => $p->id_permiso,
                'nombre' => $p->nombre,
                'plataforma' => $p->plataforma,
            ])->values(),
        ];
    }
}
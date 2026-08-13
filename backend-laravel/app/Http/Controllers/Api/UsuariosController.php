<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Usuarios\ActualizarUsuarioRequest;
use App\Http\Requests\Api\Usuarios\AsignarRolesUsuarioRequest;
use App\Http\Requests\Api\Usuarios\CrearUsuarioRequest;
use App\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * RF1, "Gestión de roles y usuarios": alta/edición/baja de los
 * usuarios que operan el sistema, y la asignación de sus roles. Nunca
 * gestiona alumnos — ver la distinción en el modelo `Usuario`.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión general del sistema.
 */
class UsuariosController extends Controller
{
    public function crear(CrearUsuarioRequest $request): JsonResponse
    {
        $this->verificarEmailDisponible($request->validated('email'));

        $usuario = DB::transaction(function () use ($request) {
            $usuario = Usuario::create([
                'nombre' => $request->validated('nombre'),
                'apellido' => $request->validated('apellido'),
                'email' => $request->validated('email'),
                'password' => $request->validated('password'),
                'activo' => $request->validated('activo') ?? true,
            ]);

            $rolIds = $request->validated('rol_ids');
            if ($rolIds !== null) {
                $usuario->roles()->sync($rolIds);
            }

            return $usuario;
        });

        return response()->json(['data' => $this->formatearUsuario($usuario->fresh(['roles']))], 201);
    }

    public function index(): JsonResponse
    {
        $usuarios = Usuario::with('roles')->get();

        return response()->json([
            'data' => $usuarios->map(fn (Usuario $usuario) => $this->formatearUsuario($usuario))->values(),
        ]);
    }

    /**
     * Usuarios dados de baja — mismo razonamiento que
     * `RolesController::eliminados()` (pedido explícito de la cátedra:
     * la baja lógica tiene que poder revertirse eligiendo de una lista).
     */
    public function eliminados(): JsonResponse
    {
        $usuarios = Usuario::onlyTrashed()->with('roles')->get();

        return response()->json([
            'data' => $usuarios->map(fn (Usuario $usuario) => $this->formatearUsuario($usuario))->values(),
        ]);
    }

    public function actualizar(ActualizarUsuarioRequest $request, Usuario $usuario): JsonResponse
    {
        $emailNuevo = $request->validated('email');
        if ($emailNuevo !== null && $emailNuevo !== $usuario->email) {
            $this->verificarEmailDisponible($emailNuevo, $usuario->id_usuario);
        }

        // `password` solo se toca si vino en el body — evita pisarla
        // con null en una edición que no la incluye.
        $datos = $request->validated();
        if (! $request->has('password')) {
            unset($datos['password']);
        }

        $usuario->update($datos);

        return response()->json(['data' => $this->formatearUsuario($usuario->fresh(['roles']))]);
    }

    /**
     * Baja lógica (SoftDeletes) — distinta del apagado reversible
     * `activo=false` (ver `ActualizarUsuarioRequest`). Bloquea que un
     * usuario se elimine a sí mismo, para no dejar la sesión actual sin
     * forma de deshacer el error.
     */
    public function eliminar(Request $request, Usuario $usuario): JsonResponse
    {
        if ($usuario->id_usuario === $request->user()->id_usuario) {
            throw ValidationException::withMessages([
                'usuario' => ['No podés eliminar tu propio usuario mientras estás logueado con él.'],
            ]);
        }

        $usuario->delete();

        return response()->json(['data' => ['id_usuario' => $usuario->id_usuario, 'eliminado' => true]]);
    }

    public function asignarRoles(AsignarRolesUsuarioRequest $request, Usuario $usuario): JsonResponse
    {
        $usuario->roles()->sync($request->validated('rol_ids'));

        return response()->json([
            'data' => $this->formatearUsuario($usuario->fresh(['roles'])),
        ]);
    }

    /**
     * Restaura un usuario dado de baja (SoftDeletes) — completa la
     * sugerencia que ya daban `crear()`/`actualizar()` cuando el email
     * pedido pertenece a un usuario borrado ("hay que restaurarlo en
     * vez de crear uno nuevo"): antes de este método esa sugerencia no
     * tenía ningún endpoint al cual apuntar. Sin type-hint de `Usuario`
     * en la firma a propósito — el binding implícito de Laravel excluye
     * los borrados lógicos por default, así que acá se busca a mano con
     * `withTrashed()`.
     */
    public function restaurar(int $usuario): JsonResponse
    {
        $usuarioModel = Usuario::withTrashed()->findOrFail($usuario);

        if (! $usuarioModel->trashed()) {
            throw ValidationException::withMessages([
                'usuario' => ['Este usuario no está dado de baja — no hay nada que restaurar.'],
            ]);
        }

        $usuarioModel->restore();

        return response()->json(['data' => $this->formatearUsuario($usuarioModel->fresh(['roles']))]);
    }

    /**
     * `uq_usuarios_email` no incluye `deleted_at` (ver nota en el
     * modelo `Usuario`), así que un email "libre" puede en realidad
     * pertenecer a un usuario dado de baja.
     */
    private function verificarEmailDisponible(string $email, ?int $idUsuarioExcluido = null): void
    {
        $existente = Usuario::withTrashed()
            ->where('email', $email)
            ->when($idUsuarioExcluido, fn ($q) => $q->where('id_usuario', '!=', $idUsuarioExcluido))
            ->first();

        if ($existente !== null) {
            throw ValidationException::withMessages([
                'email' => [$existente->trashed()
                    ? "Ya existe un usuario con este email (id {$existente->id_usuario}), pero está dado de baja — hay que restaurarlo en vez de crear uno nuevo."
                    : "Ya existe un usuario con este email (id {$existente->id_usuario})."],
            ]);
        }
    }

    private function formatearUsuario(Usuario $usuario): array
    {
        return [
            'id_usuario' => $usuario->id_usuario,
            'nombre' => $usuario->nombre,
            'apellido' => $usuario->apellido,
            'email' => $usuario->email,
            'activo' => $usuario->activo,
            'roles' => $usuario->roles->map(fn ($r) => [
                'id_rol' => $r->id_rol,
                'nombre' => $r->nombre,
            ])->values(),
        ];
    }
}
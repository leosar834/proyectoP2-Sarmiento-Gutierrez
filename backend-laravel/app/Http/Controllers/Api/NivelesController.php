<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Niveles\ActualizarNivelRequest;
use App\Http\Requests\Api\Niveles\CrearNivelRequest;
use App\Models\Nivel;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * RF1, "Gestión de cursos": catálogo de niveles/años de la
 * institución. Dato permanente (no cuelga de ningún ciclo lectivo,
 * narrativa "Datos permanentes... comprenden... la configuración
 * general"). `numero_orden` es lo que usa `AperturaCicloController`
 * para promocionar de N a N+1 — editarlo en una institución que ya
 * tiene ciclos abiertos con cursos de ese nivel es responsabilidad del
 * administrador, el endpoint no lo bloquea.
 *
 * Va detrás de `permiso:gestionar_sistema`.
 */
class NivelesController extends Controller
{
    public function crear(CrearNivelRequest $request): JsonResponse
    {
        $this->verificarOrdenDisponible($request->validated('numero_orden'));

        $nivel = Nivel::create($request->validated());

        return response()->json(['data' => $this->formatear($nivel->fresh())], 201);
    }

    public function index(): JsonResponse
    {
        $niveles = Nivel::orderBy('numero_orden')->get();

        return response()->json(['data' => $niveles->map(fn (Nivel $n) => $this->formatear($n))->values()]);
    }

    /**
     * Niveles dados de baja (SoftDeletes) — separado de `index()` a
     * propósito, para no mezclar en la misma lista lo activo con lo
     * dado de baja. Existe para que el administrador pueda ver y
     * restaurar un nivel eliminado sin depender de chocar primero con
     * el mensaje de "ya existe pero está dado de baja" al intentar
     * crear uno nuevo (pedido explícito de la cátedra: la baja lógica
     * tiene que poder revertirse desde la propia pantalla, no solo
     * como efecto secundario de un error).
     */
    public function eliminados(): JsonResponse
    {
        $niveles = Nivel::onlyTrashed()->orderBy('numero_orden')->get();

        return response()->json(['data' => $niveles->map(fn (Nivel $n) => $this->formatear($n))->values()]);
    }

    public function actualizar(ActualizarNivelRequest $request, Nivel $nivel): JsonResponse
    {
        $ordenNuevo = $request->validated('numero_orden');
        if ($ordenNuevo !== null && $ordenNuevo !== $nivel->numero_orden) {
            $this->verificarOrdenDisponible($ordenNuevo, $nivel->id_nivel);
        }

        $nivel->update($request->validated());

        return response()->json(['data' => $this->formatear($nivel->fresh())]);
    }

    public function eliminar(Nivel $nivel): JsonResponse
    {
        $nivel->delete();

        return response()->json(['data' => ['id_nivel' => $nivel->id_nivel, 'eliminado' => true]]);
    }

    /**
     * Restaura un nivel dado de baja — ver el razonamiento en
     * `UsuariosController::restaurar()`.
     */
    public function restaurar(int $nivel): JsonResponse
    {
        $nivelModel = Nivel::withTrashed()->findOrFail($nivel);

        if (! $nivelModel->trashed()) {
            throw ValidationException::withMessages([
                'nivel' => ['Este nivel no está dado de baja — no hay nada que restaurar.'],
            ]);
        }

        $nivelModel->restore();

        return response()->json(['data' => $this->formatear($nivelModel->fresh())]);
    }

    private function verificarOrdenDisponible(int $numeroOrden, ?int $idNivelExcluido = null): void
    {
        $existente = Nivel::withTrashed()
            ->where('numero_orden', $numeroOrden)
            ->when($idNivelExcluido, fn ($q) => $q->where('id_nivel', '!=', $idNivelExcluido))
            ->first();

        if ($existente !== null) {
            throw ValidationException::withMessages([
                'numero_orden' => [$existente->trashed()
                    ? "Ya existe un nivel con este número de orden (id {$existente->id_nivel}), pero está dado de baja — hay que restaurarlo en vez de crear uno nuevo."
                    : "Ya existe un nivel con este número de orden (id {$existente->id_nivel})."],
            ]);
        }
    }

    private function formatear(Nivel $nivel): array
    {
        return [
            'id_nivel' => $nivel->id_nivel,
            'nombre' => $nivel->nombre,
            'numero_orden' => $nivel->numero_orden,
        ];
    }
}
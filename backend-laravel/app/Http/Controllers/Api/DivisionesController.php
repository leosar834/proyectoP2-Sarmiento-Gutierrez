<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Divisiones\ActualizarDivisionRequest;
use App\Http\Requests\Api\Divisiones\CrearDivisionRequest;
use App\Models\Division;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * RF1, "Gestión de cursos": catálogo de divisiones (A, B, 1ra, 2da...).
 * Dato permanente, igual que `Nivel`. `uq_divisiones_nombre` tampoco
 * incluye `deleted_at` — mismo patrón de chequeo manual.
 *
 * Va detrás de `permiso:gestionar_sistema`.
 */
class DivisionesController extends Controller
{
    public function crear(CrearDivisionRequest $request): JsonResponse
    {
        $this->verificarNombreDisponible($request->validated('nombre'));

        $division = Division::create($request->validated());

        return response()->json(['data' => $this->formatear($division->fresh())], 201);
    }

    public function index(): JsonResponse
    {
        $divisiones = Division::orderBy('nombre')->get();

        return response()->json(['data' => $divisiones->map(fn (Division $d) => $this->formatear($d))->values()]);
    }

    public function actualizar(ActualizarDivisionRequest $request, Division $division): JsonResponse
    {
        $nombreNuevo = $request->validated('nombre');
        if ($nombreNuevo !== $division->nombre) {
            $this->verificarNombreDisponible($nombreNuevo, $division->id_division);
        }

        $division->update($request->validated());

        return response()->json(['data' => $this->formatear($division->fresh())]);
    }

    public function eliminar(Division $division): JsonResponse
    {
        $division->delete();

        return response()->json(['data' => ['id_division' => $division->id_division, 'eliminado' => true]]);
    }

    /**
     * Restaura una división dada de baja — ver el razonamiento en
     * `UsuariosController::restaurar()`.
     */
    public function restaurar(int $division): JsonResponse
    {
        $divisionModel = Division::withTrashed()->findOrFail($division);

        if (! $divisionModel->trashed()) {
            throw ValidationException::withMessages([
                'division' => ['Esta división no está dada de baja — no hay nada que restaurar.'],
            ]);
        }

        $divisionModel->restore();

        return response()->json(['data' => $this->formatear($divisionModel->fresh())]);
    }

    private function verificarNombreDisponible(string $nombre, ?int $idDivisionExcluida = null): void
    {
        $existente = Division::withTrashed()
            ->where('nombre', $nombre)
            ->when($idDivisionExcluida, fn ($q) => $q->where('id_division', '!=', $idDivisionExcluida))
            ->first();

        if ($existente !== null) {
            throw ValidationException::withMessages([
                'nombre' => [$existente->trashed()
                    ? "Ya existe una división con este nombre (id {$existente->id_division}), pero está dada de baja — hay que restaurarla en vez de crear una nueva."
                    : "Ya existe una división con este nombre (id {$existente->id_division})."],
            ]);
        }
    }

    private function formatear(Division $division): array
    {
        return [
            'id_division' => $division->id_division,
            'nombre' => $division->nombre,
        ];
    }
}
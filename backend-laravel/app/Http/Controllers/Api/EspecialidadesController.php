<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Especialidades\ActualizarEspecialidadRequest;
use App\Http\Requests\Api\Especialidades\CrearEspecialidadRequest;
use App\Models\Especialidad;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * RF1, "Gestión de cursos": catálogo de especialidades/orientaciones
 * propias de la institución (narrativa, "Especialidades y Talleres
 * Configurables"). Dato permanente. No confundir con
 * `DistribucionEspecialidadesController` — ese asigna la especialidad
 * ya existente a una inscripción puntual (Fase 4); este da de
 * alta/edita/elimina la especialidad como entidad del catálogo.
 *
 * Va detrás de `permiso:gestionar_sistema`.
 */
class EspecialidadesController extends Controller
{
    public function crear(CrearEspecialidadRequest $request): JsonResponse
    {
        $this->verificarNombreDisponible($request->validated('nombre'));

        $especialidad = Especialidad::create($request->validated());

        return response()->json(['data' => $this->formatear($especialidad->fresh())], 201);
    }

    public function index(): JsonResponse
    {
        $especialidades = Especialidad::orderBy('nombre')->get();

        return response()->json(['data' => $especialidades->map(fn (Especialidad $e) => $this->formatear($e))->values()]);
    }

    public function actualizar(ActualizarEspecialidadRequest $request, Especialidad $especialidad): JsonResponse
    {
        $nombreNuevo = $request->validated('nombre');
        if ($nombreNuevo !== $especialidad->nombre) {
            $this->verificarNombreDisponible($nombreNuevo, $especialidad->id_especialidad);
        }

        $especialidad->update($request->validated());

        return response()->json(['data' => $this->formatear($especialidad->fresh())]);
    }

    public function eliminar(Especialidad $especialidad): JsonResponse
    {
        $especialidad->delete();

        return response()->json(['data' => ['id_especialidad' => $especialidad->id_especialidad, 'eliminado' => true]]);
    }

    private function verificarNombreDisponible(string $nombre, ?int $idEspecialidadExcluida = null): void
    {
        $existente = Especialidad::withTrashed()
            ->where('nombre', $nombre)
            ->when($idEspecialidadExcluida, fn ($q) => $q->where('id_especialidad', '!=', $idEspecialidadExcluida))
            ->first();

        if ($existente !== null) {
            throw ValidationException::withMessages([
                'nombre' => [$existente->trashed()
                    ? "Ya existe una especialidad con este nombre (id {$existente->id_especialidad}), pero está dada de baja — hay que restaurarla en vez de crear una nueva."
                    : "Ya existe una especialidad con este nombre (id {$existente->id_especialidad})."],
            ]);
        }
    }

    private function formatear(Especialidad $especialidad): array
    {
        return [
            'id_especialidad' => $especialidad->id_especialidad,
            'nombre' => $especialidad->nombre,
        ];
    }
}
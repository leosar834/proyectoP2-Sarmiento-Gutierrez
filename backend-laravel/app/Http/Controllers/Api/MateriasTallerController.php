<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\MateriasTaller\ActualizarMateriaTallerRequest;
use App\Http\Requests\Api\MateriasTaller\CrearMateriaTallerRequest;
use App\Models\MateriaTaller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * "Estructura académica, parte 2": catálogo de materias/talleres de cada
 * especialidad (tabla `materias_taller`). A diferencia de `Curso`, esto
 * NO depende de un ciclo lectivo puntual — es un dato permanente, igual
 * que `Especialidad` (de hecho `regimen_cursada` es justamente lo que la
 * narrativa pide que sea configurable por materia, ver el docblock del
 * modelo). Los grupos de taller (`GrupoTaller`, Fase 4) sí son por ciclo
 * y se arman aparte, sobre estas materias ya existentes.
 *
 * Nota deliberada: `nombre` NO tiene chequeo de duplicados. El schema no
 * le puso una UNIQUE KEY a `materias_taller.nombre` (a diferencia de
 * niveles/divisiones/especialidades, que sí la tienen) — a diferencia de
 * esas, acá es razonable que dos especialidades distintas tengan una
 * materia con el mismo nombre (ej. "Dibujo Técnico" en Electromecánica Y
 * en Construcción). Se respeta el diseño del schema en vez de inventar
 * una regla de negocio que no está.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de la estructura académica.
 */
class MateriasTallerController extends Controller
{
    public function crear(CrearMateriaTallerRequest $request): JsonResponse
    {
        $materiaTaller = MateriaTaller::create($request->validated());

        return response()->json(['data' => $this->formatear($materiaTaller->fresh('especialidad'))], 201);
    }

    public function index(Request $request): JsonResponse
    {
        $materiasTaller = MateriaTaller::with('especialidad')
            ->when($request->query('especialidad_id'), fn ($q, $especialidadId) => $q->where('especialidad_id', $especialidadId))
            ->orderBy('nombre')
            ->get();

        return response()->json(['data' => $materiasTaller->map(fn (MateriaTaller $m) => $this->formatear($m))->values()]);
    }

    /**
     * Materias de taller dadas de baja — mismo razonamiento que
     * `NivelesController::eliminados()`. A diferencia de Especialidad,
     * acá no hay atajo "(id X)" al crear (no hay unique key sobre
     * `nombre`, ver el docblock de esta clase) — este listado es la
     * ÚNICA forma de restaurar una materia de taller borrada.
     */
    public function eliminados(Request $request): JsonResponse
    {
        $materiasTaller = MateriaTaller::onlyTrashed()
            ->with('especialidad')
            ->when($request->query('especialidad_id'), fn ($q, $especialidadId) => $q->where('especialidad_id', $especialidadId))
            ->orderBy('nombre')
            ->get();

        return response()->json(['data' => $materiasTaller->map(fn (MateriaTaller $m) => $this->formatear($m))->values()]);
    }

    public function actualizar(ActualizarMateriaTallerRequest $request, MateriaTaller $materiaTaller): JsonResponse
    {
        $materiaTaller->update($request->validated());

        return response()->json(['data' => $this->formatear($materiaTaller->fresh('especialidad'))]);
    }

    public function eliminar(MateriaTaller $materiaTaller): JsonResponse
    {
        // Si ya tiene grupos de taller armados (Fase 4, aunque estén de
        // un ciclo ya cerrado), eliminarla dejaría huérfanos esos grupos
        // y las planillas de asistencia que referencian grupo_taller_id.
        $tieneGrupos = $materiaTaller->gruposTaller()->exists();
        if ($tieneGrupos) {
            throw ValidationException::withMessages([
                'materia_taller' => ['Esta materia/taller ya tiene grupos de taller creados — no se puede eliminar.'],
            ]);
        }

        $materiaTaller->delete();

        return response()->json(['data' => ['id_materia_taller' => $materiaTaller->id_materia_taller, 'eliminado' => true]]);
    }

    /**
     * Restaura una materia/taller dada de baja — ver el razonamiento en
     * `UsuariosController::restaurar()`. Sin guard de ciclo: igual que
     * `Especialidad`, es un dato permanente que no cuelga de ningún
     * ciclo lectivo puntual (ver el docblock de esta clase).
     */
    public function restaurar(int $materiaTaller): JsonResponse
    {
        $materiaTallerModel = MateriaTaller::withTrashed()->findOrFail($materiaTaller);

        if (! $materiaTallerModel->trashed()) {
            throw ValidationException::withMessages([
                'materia_taller' => ['Esta materia/taller no está dada de baja — no hay nada que restaurar.'],
            ]);
        }

        $materiaTallerModel->restore();

        return response()->json(['data' => $this->formatear($materiaTallerModel->fresh('especialidad'))]);
    }

    private function formatear(MateriaTaller $materiaTaller): array
    {
        return [
            'id_materia_taller' => $materiaTaller->id_materia_taller,
            'especialidad_id' => $materiaTaller->especialidad_id,
            'especialidad_nombre' => $materiaTaller->especialidad?->nombre,
            'nombre' => $materiaTaller->nombre,
            'regimen_cursada' => $materiaTaller->regimen_cursada,
        ];
    }
}

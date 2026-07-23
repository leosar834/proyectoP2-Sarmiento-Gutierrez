<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\GruposTaller\AsignarLoteTallerRequest;
use App\Http\Requests\Api\GruposTaller\CrearGrupoTallerRequest;
use App\Models\CicloLectivo;
use App\Models\GrupoTaller;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Fase 4 ("población manual de lo que falta"), tercera pieza:
 * redistribución en grupos de taller del ciclo nuevo — mismo patrón
 * general que `GruposEdFisicaController`, con dos diferencias reales:
 * un grupo de taller es específico de una materia Y un nivel (no solo
 * del ciclo), y un alumno puede estar en varios grupos de taller a la
 * vez (uno por cada materia que cursa), a diferencia de educación
 * física donde solo puede estar en uno.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de la estructura académica.
 */
class GruposTallerController extends Controller
{
    public function crear(CrearGrupoTallerRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'ciclo' => ['Los grupos se crean sobre un ciclo lectivo abierto — este está cerrado y archivado de solo lectura.'],
            ]);
        }

        $grupo = GrupoTaller::create([
            'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
            'materia_taller_id' => $request->validated('materia_taller_id'),
            'nivel_id' => $request->validated('nivel_id'),
            'nombre_grupo' => $request->validated('nombre_grupo'),
        ]);

        return response()->json(['data' => $this->formatearGrupo($grupo)], 201);
    }

    public function index(CicloLectivo $ciclo): JsonResponse
    {
        $grupos = GrupoTaller::where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->withCount('inscripciones')
            ->get();

        return response()->json([
            'data' => $grupos->map(fn ($g) => $this->formatearGrupo($g))->values(),
        ]);
    }

    /**
     * Asignación por lote: REEMPLAZA la membresía de la MISMA materia
     * (no de todo el ciclo, como en educación física) — un alumno
     * puede estar simultáneamente en un grupo de "Electricidad" y otro
     * de "Dibujo Técnico", así que reasignarlo dentro de una materia no
     * debe tocar sus grupos de las demás. Selección de a quién asignar,
     * mismo criterio que en educación física: `inscripcion_ids` para
     * lista manual (ej. separar por sexo, ver la nota en
     * `AsignarLoteTallerRequest`), o curso/división/especialidad como
     * filtro amplio si no viene la lista.
     */
    public function asignarLote(AsignarLoteTallerRequest $request, GrupoTaller $grupo): JsonResponse
    {
        if ($grupo->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'grupo' => ['La asignación por lote solo aplica sobre un ciclo lectivo abierto.'],
            ]);
        }

        $inscripcionIdsExplicitos = $request->validated('inscripcion_ids');

        if ($inscripcionIdsExplicitos !== null && $inscripcionIdsExplicitos !== []) {
            $inscripcionIds = collect($inscripcionIdsExplicitos)->unique()->values();

            // La lista explícita puede venir de una pantalla distinta a
            // la del filtro amplio — confirmamos que sea del mismo
            // nivel que el grupo, para no colar un alumno de otro año.
            $fueraDeNivel = Inscripcion::whereIn('id_inscripcion', $inscripcionIds)
                ->whereHas('curso', fn ($q) => $q->where('nivel_id', '!=', $grupo->nivel_id))
                ->pluck('id_inscripcion');

            if ($fueraDeNivel->isNotEmpty()) {
                throw ValidationException::withMessages([
                    'inscripcion_ids' => ['Las inscripciones ' . $fueraDeNivel->implode(', ') . ' no son del nivel de este grupo.'],
                ]);
            }
        } else {
            $query = Inscripcion::where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                ->where('estado', 'activo')
                ->whereHas('curso', fn ($q) => $q->where('nivel_id', $grupo->nivel_id));

            if ($request->validated('curso_id')) {
                $query->where('curso_id', $request->validated('curso_id'));
            }
            if ($request->validated('division_id')) {
                $query->whereHas('curso', fn ($q) => $q->where('division_id', $request->validated('division_id')));
            }
            if ($request->validated('especialidad_id')) {
                $query->where('especialidad_id', $request->validated('especialidad_id'));
            }

            $inscripcionIds = $query->pluck('id_inscripcion');
        }

        $asignados = DB::transaction(function () use ($inscripcionIds, $grupo) {
            if ($inscripcionIds->isEmpty()) {
                return 0;
            }

            // Reemplazo acotado a los grupos de la MISMA materia en este
            // ciclo — no se tocan las membresías de otras materias.
            $gruposDeLaMateria = GrupoTaller::where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                ->where('materia_taller_id', $grupo->materia_taller_id)
                ->pluck('id_grupo_taller');

            DB::table('alumnos_grupos_taller')
                ->whereIn('inscripcion_id', $inscripcionIds)
                ->whereIn('grupo_taller_id', $gruposDeLaMateria)
                ->delete();

            DB::table('alumnos_grupos_taller')->insert(
                $inscripcionIds->map(fn ($id) => [
                    'inscripcion_id' => $id,
                    'grupo_taller_id' => $grupo->id_grupo_taller,
                ])->all()
            );

            return $inscripcionIds->count();
        });

        return response()->json([
            'data' => [
                'grupo_taller_id' => $grupo->id_grupo_taller,
                'asignados' => $asignados,
            ],
        ]);
    }

    private function formatearGrupo(GrupoTaller $grupo): array
    {
        return [
            'id_grupo_taller' => $grupo->id_grupo_taller,
            'ciclo_lectivo_id' => $grupo->ciclo_lectivo_id,
            'materia_taller_id' => $grupo->materia_taller_id,
            'nivel_id' => $grupo->nivel_id,
            'nombre_grupo' => $grupo->nombre_grupo,
            'alumnos_asignados' => $grupo->inscripciones_count ?? 0,
        ];
    }
}
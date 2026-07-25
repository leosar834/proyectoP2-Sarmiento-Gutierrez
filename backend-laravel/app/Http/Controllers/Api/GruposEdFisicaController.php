<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\GruposEdFisica\AsignarLoteEdFisicaRequest;
use App\Http\Requests\Api\GruposEdFisica\AsignarProfesorGrupoEdFisicaRequest;
use App\Http\Requests\Api\GruposEdFisica\CrearGrupoEdFisicaRequest;
use App\Models\CicloLectivo;
use App\Models\GrupoEdFisica;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Fase 4 ("población manual de lo que falta"), segunda pieza:
 * redistribución en grupos de educación física del ciclo nuevo.
 * Narrativa: "el curso principal es la fuente de verdad ... luego se
 * desvincula de los grupos ... del año anterior, que no se arrastran;
 * y finalmente el administrador lo reasigna a los grupos del nuevo
 * año ... con herramientas de asignación por lote —asignar grupos
 * completos, filtrar por especialidad o por división—".
 *
 * También cubre RF1 ("Asignar un profesor a cada grupo de educación
 * física") vía `asignarProfesor()`, para reasignar el profesor de un
 * grupo ya creado — la asignación inicial ya la exige `crear()`
 * (`profesor_id` obligatorio, columna NOT NULL).
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de la estructura académica (cursos, desenlaces, ingresantes).
 */
class GruposEdFisicaController extends Controller
{
    public function crear(CrearGrupoEdFisicaRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'ciclo' => ['Los grupos se crean sobre un ciclo lectivo abierto — este está cerrado y archivado de solo lectura.'],
            ]);
        }

        $grupo = GrupoEdFisica::create([
            'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
            'nombre_grupo' => $request->validated('nombre_grupo'),
            'regimen_cursada' => $request->validated('regimen_cursada'),
            'profesor_id' => $request->validated('profesor_id'),
        ]);

        return response()->json(['data' => $this->formatearGrupo($grupo)], 201);
    }

    public function index(CicloLectivo $ciclo): JsonResponse
    {
        $grupos = GrupoEdFisica::where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->withCount('inscripciones')
            ->get();

        return response()->json([
            'data' => $grupos->map(fn ($g) => $this->formatearGrupo($g))->values(),
        ]);
    }

    /**
     * Asignación por lote: REEMPLAZA (no acumula) la membresía de
     * educación física de cada inscripción encontrada. A diferencia de
     * taller (donde un alumno puede estar en varios grupos a la vez,
     * uno por materia), acá un alumno solo puede estar en un grupo de
     * ed. física por ciclo — no hay "otra materia" que justifique una
     * segunda membresía simultánea. Por eso reinvocar esta acción con
     * otro grupo destino sirve para MOVER alumnos entre grupos, en vez
     * de ir acumulando membresías duplicadas cada vez que se reintenta.
     *
     * Selección de a quién asignar: si viene `inscripcion_ids`, se usa
     * exactamente esa lista (caso típico: separar varones y mujeres
     * dentro de un mismo curso, algo que el schema no puede derivar
     * solo, ver la nota en `AsignarLoteEdFisicaRequest`) e ignora
     * cualquier otro filtro que haya venido junto, para no tener que
     * resolver "intersección vs. unión" entre una lista explícita y un
     * filtro amplio. Si no viene, se arma con curso/división/
     * especialidad como filtro.
     */
    public function asignarLote(AsignarLoteEdFisicaRequest $request, GrupoEdFisica $grupo): JsonResponse
    {
        if ($grupo->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'grupo' => ['La asignación por lote solo aplica sobre un ciclo lectivo abierto.'],
            ]);
        }

        $inscripcionIdsExplicitos = $request->validated('inscripcion_ids');

        if ($inscripcionIdsExplicitos !== null && $inscripcionIdsExplicitos !== []) {
            $inscripcionIds = collect($inscripcionIdsExplicitos)->unique()->values();
        } else {
            $query = Inscripcion::where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                ->where('estado', 'activo');

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

            $gruposDelCiclo = GrupoEdFisica::where('ciclo_lectivo_id', $grupo->ciclo_lectivo_id)
                ->pluck('id_grupo_ed_fisica');

            // Se borra cualquier membresía previa de ed. física de estas
            // inscripciones EN ESTE CICLO (nunca en otros) antes de
            // insertar la nueva — así queda "reemplazo", no acumulación.
            DB::table('alumnos_grupos_ed_fisica')
                ->whereIn('inscripcion_id', $inscripcionIds)
                ->whereIn('grupo_ed_fisica_id', $gruposDelCiclo)
                ->delete();

            DB::table('alumnos_grupos_ed_fisica')->insert(
                $inscripcionIds->map(fn ($id) => [
                    'inscripcion_id' => $id,
                    'grupo_ed_fisica_id' => $grupo->id_grupo_ed_fisica,
                ])->all()
            );

            return $inscripcionIds->count();
        });

        return response()->json([
            'data' => [
                'grupo_ed_fisica_id' => $grupo->id_grupo_ed_fisica,
                'asignados' => $asignados,
            ],
        ]);
    }

    /**
     * Narrativa RF1: "Asignar un profesor a cada grupo de educación
     * física". Reasigna el profesor de un grupo ya existente (cambio a
     * mitad de año) — no hay caso de "vacío": la columna es NOT NULL,
     * un grupo de ed. física siempre tiene exactamente un profesor.
     */
    public function asignarProfesor(AsignarProfesorGrupoEdFisicaRequest $request, GrupoEdFisica $grupo): JsonResponse
    {
        if ($grupo->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'grupo' => ['No se puede modificar el profesor de un grupo de un ciclo lectivo cerrado y archivado de solo lectura.'],
            ]);
        }

        $grupo->update(['profesor_id' => $request->validated('profesor_id')]);

        return response()->json(['data' => $this->formatearGrupo($grupo->fresh())]);
    }

    private function formatearGrupo(GrupoEdFisica $grupo): array
    {
        return [
            'id_grupo_ed_fisica' => $grupo->id_grupo_ed_fisica,
            'ciclo_lectivo_id' => $grupo->ciclo_lectivo_id,
            'nombre_grupo' => $grupo->nombre_grupo,
            'regimen_cursada' => $grupo->regimen_cursada,
            'profesor_id' => $grupo->profesor_id,
            'alumnos_asignados' => $grupo->inscripciones_count ?? 0,
        ];
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Especialidades\AsignarLoteEspecialidadRequest;
use App\Models\CicloLectivo;
use App\Models\Inscripcion;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Fase 4 ("población manual de lo que falta"), última pieza: la
 * distribución de especialidades para los alumnos que llegan al primer
 * año del ciclo superior (narrativa, "Manejo de la Especialidad en el
 * Ciclo Superior").
 *
 * A diferencia de los grupos de taller/ed. física, acá no hay una
 * tabla puente que gestionar: `especialidad_id` es una columna directa
 * de `inscripciones`, y `AperturaCicloController` ya la propaga sola de
 * una inscripción a la siguiente en los años sucesivos (ver el `create`
 * de `Inscripcion` en la Fase 3) — este endpoint solo necesita
 * completarla la primera vez.
 *
 * Reemplazo directo del campo, sin chequear si ya tenía una asignada:
 * mismo criterio de "reemplazar, no acumular" que grupos_ed_fisica, útil
 * también para corregir una distribución mal hecha sin pasos extra.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de la estructura académica de la Fase 4.
 */
class DistribucionEspecialidadesController extends Controller
{
    public function asignarLote(AsignarLoteEspecialidadRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'ciclo' => ['La distribución de especialidades solo aplica sobre un ciclo lectivo abierto.'],
            ]);
        }

        $especialidadId = $request->validated('especialidad_id');
        $inscripcionIdsExplicitos = $request->validated('inscripcion_ids');

        if ($inscripcionIdsExplicitos !== null && $inscripcionIdsExplicitos !== []) {
            $inscripcionIds = collect($inscripcionIdsExplicitos)->unique()->values();
        } else {
            $query = Inscripcion::where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
                ->where('estado', 'activo');

            if ($request->validated('curso_id')) {
                $query->where('curso_id', $request->validated('curso_id'));
            }
            if ($request->validated('division_id')) {
                $query->whereHas('curso', fn ($q) => $q->where('division_id', $request->validated('division_id')));
            }
            if ($request->validated('nivel_id')) {
                $query->whereHas('curso', fn ($q) => $q->where('nivel_id', $request->validated('nivel_id')));
            }

            $inscripcionIds = $query->pluck('id_inscripcion');
        }

        $asignados = DB::transaction(function () use ($inscripcionIds, $especialidadId) {
            if ($inscripcionIds->isEmpty()) {
                return 0;
            }

            return Inscripcion::whereIn('id_inscripcion', $inscripcionIds)
                ->update(['especialidad_id' => $especialidadId]);
        });

        return response()->json([
            'data' => [
                'especialidad_id' => $especialidadId,
                'asignados' => $asignados,
            ],
        ]);
    }
}
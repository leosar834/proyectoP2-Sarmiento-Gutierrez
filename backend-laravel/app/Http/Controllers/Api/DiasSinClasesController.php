<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\DiasSinClases\ActualizarDiaSinClaseRequest;
use App\Http\Requests\Api\DiasSinClases\CrearDiaSinClaseRequest;
use App\Models\CicloLectivo;
use App\Models\DiaSinClase;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * Calendario escolar: días sin clases (feriados, actos, jornadas
 * institucionales) declarados por ciclo lectivo. El efecto real de esto
 * no es solo informativo — `AsistenciaController::crear()` lo consulta
 * para rechazar la apertura de una planilla en un día declarado sin
 * clases, que es lo que hace cierta la premisa de `sp_recalcular_contador`
 * de que "los días sin clases quedan excluidos por construcción".
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de la estructura académica.
 */
class DiasSinClasesController extends Controller
{
    public function crear(CrearDiaSinClaseRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'ciclo' => ['El calendario se gestiona sobre un ciclo lectivo abierto — este está cerrado y archivado de solo lectura.'],
            ]);
        }

        $dia = DiaSinClase::create([
            'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
            'fecha' => $request->validated('fecha'),
            'motivo' => $request->validated('motivo'),
            'alcance' => $request->validated('alcance') ?? 'todos',
        ]);

        return response()->json(['data' => $this->formatear($dia)], 201);
    }

    public function index(CicloLectivo $ciclo): JsonResponse
    {
        $dias = DiaSinClase::where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->orderBy('fecha')
            ->get();

        return response()->json(['data' => $dias->map(fn (DiaSinClase $d) => $this->formatear($d))->values()]);
    }

    public function actualizar(ActualizarDiaSinClaseRequest $request, DiaSinClase $diaSinClase): JsonResponse
    {
        if ($diaSinClase->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'dia_sin_clase' => ['No se puede editar el calendario de un ciclo lectivo cerrado y archivado de solo lectura.'],
            ]);
        }

        $diaSinClase->update([
            'fecha' => $request->validated('fecha'),
            'motivo' => $request->validated('motivo'),
            'alcance' => $request->validated('alcance') ?? 'todos',
        ]);

        return response()->json(['data' => $this->formatear($diaSinClase->fresh())]);
    }

    public function eliminar(DiaSinClase $diaSinClase): JsonResponse
    {
        if ($diaSinClase->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'dia_sin_clase' => ['No se puede editar el calendario de un ciclo lectivo cerrado y archivado de solo lectura.'],
            ]);
        }

        // Hard delete a propósito: DiaSinClase no lleva SoftDeletes (ver
        // el docblock del modelo) y nada más referencia esta fila por FK.
        $diaSinClase->delete();

        return response()->json(['data' => ['id_dia_sin_clase' => $diaSinClase->id_dia_sin_clase, 'eliminado' => true]]);
    }

    private function formatear(DiaSinClase $dia): array
    {
        return [
            'id_dia_sin_clase' => $dia->id_dia_sin_clase,
            'ciclo_lectivo_id' => $dia->ciclo_lectivo_id,
            'fecha' => $dia->fecha->toDateString(),
            'motivo' => $dia->motivo,
            'alcance' => $dia->alcance,
        ];
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Alertas\ListarAlertasRequest;
use App\Http\Resources\AlertaResource;
use App\Models\Alerta;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Implementa el lado de aplicación de RF6 (Alertas Automáticas). La
 * generación en sí de `limite_inasistencias` y `seguimiento` ya la hace
 * MySQL (`sp_recalcular_contador`, ver App\Models\Alerta); acá solo
 * queda listarlas y marcarlas como atendidas.
 *
 * Ambas rutas van detrás de `permiso:ver_reportes` — es el permiso más
 * cercano del catálogo fijo a "visibilidad institucional", y lo tienen
 * jefa_preceptores, administrador_sistema, jefe_taller y director. El
 * rol operativo `preceptor` no lo tiene en la matriz de la EETN.° 1 ya
 * commiteada, así que por ahora no ve alertas desde acá — decisión
 * tomada explícitamente para no reabrir esa matriz sin pedirlo aparte.
 */
class AlertasController extends Controller
{
    public function index(ListarAlertasRequest $request): JsonResponse
    {
        $estado = $request->validated('estado') ?? 'activa';

        $alertas = Alerta::with(['inscripcion.alumno', 'inscripcion.curso.nivel', 'inscripcion.curso.division'])
            ->where('estado', $estado)
            ->orderByDesc('fecha_generacion')
            ->get();

        return AlertaResource::collection($alertas)->response();
    }

    public function atender(Request $request, Alerta $alerta): JsonResponse
    {
        if ($alerta->estado === 'atendida') {
            throw ValidationException::withMessages([
                'alerta' => ['Esta alerta ya fue atendida.'],
            ]);
        }

        $alerta->update(['estado' => 'atendida']);

        return (new AlertaResource($alerta->load(['inscripcion.alumno', 'inscripcion.curso.nivel', 'inscripcion.curso.division'])))
            ->response();
    }
}

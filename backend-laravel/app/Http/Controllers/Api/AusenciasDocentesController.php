<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\AusenciasDocentes\NotificarAusenciaDocenteRequest;
use App\Models\AusenciaDocente;
use App\Models\GrupoEdFisica;
use App\Models\GrupoTaller;
use App\Models\PermisoDiario;
use App\Models\PlanillaAsistencia;
use App\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Auto-reporte de ausencia del profesor de taller/educación física —
 * funcionalidad pedida explícitamente por la cátedra, fuera de la
 * narrativa original. Ver el docblock de App\Models\AusenciaDocente
 * para el detalle de diseño (por qué solo taller/ed. física, por qué
 * siempre HOY, por qué sin SoftDeletes).
 *
 * Va detrás de `permiso:tomar_asistencia` — es la contracara de abrir
 * la planilla para el mismo grupo (mismo usuario, mismo permiso, mismo
 * día), así que reusarlo tiene más sentido que inventar un permiso
 * nuevo fuera del catálogo fijo de siete.
 */
class AusenciasDocentesController extends Controller
{
    /**
     * Notifica la ausencia de HOY para uno o más grupos propios. Es
     * idempotente por grupo+fecha (ver `procesarUnGrupo`): reintentar la
     * misma notificación (ej. doble tap en la app) no falla, devuelve la
     * fila que ya existía.
     */
    public function crear(NotificarAusenciaDocenteRequest $request): JsonResponse
    {
        $usuario = $request->user();
        $fecha = now()->toDateString();

        if (! PermisoDiario::estaVigenteHoy()) {
            throw ValidationException::withMessages([
                'fecha' => ['No hay un permiso diario abierto para tomar asistencia hoy — no corresponde notificar una ausencia fuera de esa ventana.'],
            ]);
        }

        $creadas = DB::transaction(function () use ($request, $usuario, $fecha) {
            $resultado = [];

            foreach ($request->validated('grupos') as $item) {
                $resultado[] = $this->procesarUnGrupo($item, $usuario, $fecha);
            }

            return $resultado;
        });

        return response()->json([
            'data' => collect($creadas)->map(fn (AusenciaDocente $a) => $this->formatear($a))->values(),
        ], 201);
    }

    /**
     * Las ausencias que el propio usuario logueado notificó para hoy —
     * para que la app pueda mostrar "ya avisaste tu falta en estos
     * grupos" sin tener que recordarlo del lado del cliente.
     */
    public function index(Request $request): JsonResponse
    {
        $usuario = $request->user();

        $ausencias = AusenciaDocente::where('usuario_id', $usuario->id_usuario)
            ->whereDate('fecha', now()->toDateString())
            ->get();

        return response()->json([
            'data' => $ausencias->map(fn (AusenciaDocente $a) => $this->formatear($a))->values(),
        ]);
    }

    /**
     * Da de baja una notificación propia (ej. el profesor se equivocó
     * de grupo, o al final sí puede ir a dar clase). Self-service a
     * propósito: solo quien la notificó puede cancelarla — no hay caso
     * de uso pedido para que un tercero la cancele en su nombre.
     */
    public function eliminar(Request $request, AusenciaDocente $ausenciaDocente): JsonResponse
    {
        $usuario = $request->user();

        if ($ausenciaDocente->usuario_id !== $usuario->id_usuario) {
            throw ValidationException::withMessages([
                'ausencia' => ['Solo el profesor que notificó esta ausencia puede darla de baja.'],
            ]);
        }

        // Hard delete a propósito, mismo criterio que DiaSinClase: no es
        // historial inmutable, es una notificación puntual reversible.
        $ausenciaDocente->delete();

        return response()->json(['data' => ['id_ausencia_docente' => $ausenciaDocente->id_ausencia_docente, 'eliminado' => true]]);
    }

    private function procesarUnGrupo(array $item, Usuario $usuario, string $fecha): AusenciaDocente
    {
        $area = $item['area'];

        $grupo = $area === 'taller'
            ? GrupoTaller::with('cicloLectivo')->find($item['grupo_taller_id'])
            : GrupoEdFisica::with('cicloLectivo')->find($item['grupo_ed_fisica_id']);

        // No debería pasar (el Request ya valida `exists:`), pero por
        // las dudas de una condición de carrera con un borrado entre la
        // validación y acá — mismo criterio que AsistenciaController::index().
        if ($grupo === null) {
            throw ValidationException::withMessages([
                'grupos' => ['Uno de los grupos indicados no existe.'],
            ]);
        }

        if ($grupo->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'grupos' => ['Uno de los grupos indicados no pertenece a un ciclo lectivo abierto.'],
            ]);
        }

        $pertenece = $area === 'taller'
            ? $grupo->profesores()->where('id_usuario', $usuario->id_usuario)->exists()
            : $grupo->profesor_id === $usuario->id_usuario;

        if (! $pertenece) {
            throw ValidationException::withMessages([
                'grupos' => ['Uno de los grupos indicados no está asignado a tu usuario como profesor.'],
            ]);
        }

        $grupoTallerId = $area === 'taller' ? $grupo->id_grupo_taller : null;
        $grupoEdFisicaId = $area === 'ed_fisica' ? $grupo->id_grupo_ed_fisica : null;

        // Si ya se tomó asistencia hoy para este grupo, notificar la
        // ausencia ahora sería contradecir datos que ya existen — se
        // rechaza en vez de aceptar y dejar el estado inconsistente.
        $yaHayPlanilla = PlanillaAsistencia::where('area', $area)
            ->where('grupo_taller_id', $grupoTallerId)
            ->where('grupo_ed_fisica_id', $grupoEdFisicaId)
            ->whereDate('fecha', $fecha)
            ->exists();

        if ($yaHayPlanilla) {
            throw ValidationException::withMessages([
                'grupos' => ['Ya se registró asistencia hoy para uno de los grupos indicados — no corresponde notificar una ausencia después de tomada la asistencia.'],
            ]);
        }

        $existente = AusenciaDocente::where('area', $area)
            ->where('grupo_taller_id', $grupoTallerId)
            ->where('grupo_ed_fisica_id', $grupoEdFisicaId)
            ->whereDate('fecha', $fecha)
            ->first();

        return $existente ?? AusenciaDocente::create([
            'usuario_id' => $usuario->id_usuario,
            'area' => $area,
            'grupo_taller_id' => $grupoTallerId,
            'grupo_ed_fisica_id' => $grupoEdFisicaId,
            'fecha' => $fecha,
        ]);
    }

    private function formatear(AusenciaDocente $a): array
    {
        return [
            'id_ausencia_docente' => $a->id_ausencia_docente,
            'usuario_id' => $a->usuario_id,
            'area' => $a->area,
            'grupo_taller_id' => $a->grupo_taller_id,
            'grupo_ed_fisica_id' => $a->grupo_ed_fisica_id,
            'fecha' => $a->fecha->toDateString(),
        ];
    }
}

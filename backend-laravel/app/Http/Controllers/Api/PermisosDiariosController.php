<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\PermisosDiarios\AbrirPermisoDiarioRequest;
use App\Models\PermisoDiario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * RF2, "el jefe de preceptores abre manualmente a diario el permiso
 * para tomar asistencia" (narrativa, Alcance; ver también el docblock
 * de App\Models\PermisoDiario y doc_bd.txt sección 6.5). Hasta este
 * commit no existía ningún endpoint HTTP para esa apertura — la única
 * forma de crear la fila era manual, directo en la base — así que la
 * jefa de preceptores/administrador no tenía, en la práctica, forma de
 * habilitar el día desde la versión web.
 *
 * El cierre NO es manual salvo el caso explícito de `cerrar()`: pasada
 * `hora_limite` el permiso queda cerrado solo, sin que nadie tenga que
 * hacer nada (`PermisoDiario::estaVigenteHoy()`, espejo de
 * `vista_permisos_diarios_vigentes`). Por eso acá no hay un CRUD
 * completo, solo `abrir()` (la única acción que la narrativa exige),
 * `cerrar()` (el cierre anticipado explícito que el modelo ya admitía
 * vía `cerrado_manual` pero que tampoco tenía endpoint) y `hoy()` para
 * que la pantalla de escritorio pueda mostrar el estado sin adivinarlo.
 *
 * `permisos_diarios` no tiene `ciclo_lectivo_id` (UNIQUE por `fecha`
 * únicamente, ver schema.sql sección 5) — por eso las rutas van planas,
 * sin anidar bajo `/ciclos-lectivos/{ciclo}/...` como sí hace
 * `dias_sin_clases`.
 *
 * Va detrás de `permiso:gestionar_sistema`: es jefa de
 * preceptores/administrador quien abre el día, desde la versión web —
 * mismo permiso que ya usan `CierreCicloController` y
 * `DiasSinClasesController` para el resto de la gestión diaria/de
 * calendario.
 */
class PermisosDiariosController extends Controller
{
    /**
     * Abre (o reabre, si ya se había cerrado manual o automáticamente)
     * el permiso de HOY. Idempotente hacia el error, no hacia el éxito
     * silencioso: si ya está abierto y vigente, rechaza en vez de
     * pisar `usuario_apertura_id`/`hora_apertura` sin que quien llama
     * se entere de que no era la primera apertura del día.
     */
    public function abrir(AbrirPermisoDiarioRequest $request): JsonResponse
    {
        $usuario = $request->user();
        $fecha = now()->toDateString();

        if (PermisoDiario::estaVigenteHoy()) {
            throw ValidationException::withMessages([
                'fecha' => ['El permiso para tomar asistencia de hoy ya está abierto.'],
            ]);
        }

        // updateOrCreate por `fecha` (no `create`): si hoy ya se había
        // abierto y después se cerró (manual o por hora límite vencida),
        // esto lo reabre en la misma fila en vez de chocar con
        // uq_permisos_diarios_fecha.
        $permiso = PermisoDiario::updateOrCreate(
            ['fecha' => $fecha],
            [
                'usuario_apertura_id' => $usuario->id_usuario,
                'hora_apertura' => now(),
                'hora_limite' => $request->validated('hora_limite') ?? '23:59:59',
                'cerrado_manual' => false,
            ]
        );

        return response()->json([
            'data' => $this->formatear($permiso->fresh()),
        ], $permiso->wasRecentlyCreated ? 201 : 200);
    }

    /**
     * Cierre anticipado explícito de HOY — el caso que doc_bd.txt
     * describe como "`cerrado_manual` permite un cierre anticipado
     * explícito si hiciera falta". No es el flujo normal (el cierre
     * normal es automático, contra `hora_limite`), por eso es una
     * acción aparte y no algo que pase solo.
     */
    public function cerrar(Request $request): JsonResponse
    {
        $permiso = PermisoDiario::whereDate('fecha', now()->toDateString())->first();

        if (! $permiso) {
            throw ValidationException::withMessages([
                'fecha' => ['Hoy todavía no se abrió ningún permiso para tomar asistencia — no hay nada que cerrar.'],
            ]);
        }

        if ($permiso->cerrado_manual) {
            throw ValidationException::withMessages([
                'fecha' => ['El permiso de hoy ya está cerrado manualmente.'],
            ]);
        }

        $permiso->update(['cerrado_manual' => true]);

        return response()->json(['data' => $this->formatear($permiso->fresh())]);
    }

    /**
     * Estado del día para la pantalla de escritorio — evita que la
     * jefa de preceptores/administrador tenga que "probar" abriendo o
     * mirando la base para saber si hoy ya está habilitado.
     */
    public function hoy(Request $request): JsonResponse
    {
        $permiso = PermisoDiario::whereDate('fecha', now()->toDateString())->first();

        return response()->json([
            'data' => [
                'abierto' => PermisoDiario::estaVigenteHoy(),
                'permiso' => $permiso ? $this->formatear($permiso) : null,
            ],
        ]);
    }

    private function formatear(PermisoDiario $permiso): array
    {
        return [
            'id_permiso_diario' => $permiso->id_permiso_diario,
            'fecha' => $permiso->fecha->toDateString(),
            'usuario_apertura_id' => $permiso->usuario_apertura_id,
            'hora_apertura' => $permiso->hora_apertura->toDateTimeString(),
            'hora_limite' => $permiso->hora_limite,
            'cerrado_manual' => $permiso->cerrado_manual,
        ];
    }
}

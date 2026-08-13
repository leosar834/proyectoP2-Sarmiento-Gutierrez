<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\CiclosLectivos\CrearCicloRequest;
use App\Models\CicloLectivo;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * Alta del PRIMER ciclo lectivo de una instalación nueva — distinto de
 * `AperturaCicloController::abrir()` (Fase 3 del "Proceso de Cierre y
 * Apertura en Cuatro Fases"), que exige un ciclo anterior ya CERRADO
 * del cual clonar la estructura de cursos y generar inscripciones. Acá
 * no hay nada de qué clonar: es el punto de partida de la institución,
 * antes de que exista un solo curso o alumno cargado.
 *
 * Por eso el guard es el mismo criterio que usa
 * `RegistroAdministradorController` para el primer administrador:
 * "esto nunca pasó antes en esta instalación". A partir de este primer
 * ciclo, cualquier ciclo lectivo siguiente se da de alta siempre vía
 * `AperturaCicloController` — este `crear()` no se vuelve a usar nunca
 * más en la vida de la instalación.
 *
 * Va detrás de `permiso:gestionar_sistema`.
 */
class CiclosLectivosController extends Controller
{
    public function crear(CrearCicloRequest $request): JsonResponse
    {
        if (CicloLectivo::query()->exists()) {
            throw ValidationException::withMessages([
                'anio' => ['Ya existe un ciclo lectivo cargado. Los siguientes se crean cerrando el ciclo actual y abriendo el próximo, no desde acá.'],
            ]);
        }

        $ciclo = CicloLectivo::create([
            'anio' => $request->validated('anio'),
            'fecha_inicio' => $request->validated('fecha_inicio'),
            'estado' => 'abierto',
        ]);

        return response()->json(['data' => $this->formatear($ciclo->fresh())], 201);
    }

    public function index(): JsonResponse
    {
        $ciclos = CicloLectivo::query()->orderBy('anio', 'desc')->get();

        return response()->json([
            'data' => $ciclos->map(fn (CicloLectivo $ciclo) => $this->formatear($ciclo))->values(),
        ]);
    }

    private function formatear(CicloLectivo $ciclo): array
    {
        return [
            'id_ciclo_lectivo' => $ciclo->id_ciclo_lectivo,
            'anio' => $ciclo->anio,
            'fecha_inicio' => $ciclo->fecha_inicio?->toDateString(),
            'fecha_fin' => $ciclo->fecha_fin?->toDateString(),
            'estado' => $ciclo->estado,
            'fecha_cierre' => $ciclo->fecha_cierre?->toDateTimeString(),
        ];
    }
}

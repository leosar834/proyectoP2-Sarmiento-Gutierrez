<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Cursos\ActualizarCursoRequest;
use App\Http\Requests\Api\Cursos\CrearCursoRequest;
use App\Models\CicloLectivo;
use App\Models\Curso;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * "Estructura académica, parte 2": gestión manual de `cursos` (nivel +
 * división + turno dentro de un ciclo lectivo puntual).
 *
 * Por qué hace falta un CRUD manual pese a que `AperturaCicloController`
 * ya clona cursos automáticamente de un ciclo al siguiente: esa clonación
 * solo corre en la Fase 3 (cierre/apertura) y solo replica combinaciones
 * nivel+división que YA existían en el ciclo anterior. Hacen falta cursos
 * creados a mano para: (1) el ciclo lectivo inicial de la institución,
 * que no tiene ciclo anterior del cual clonar, y (2) una combinación
 * nivel+división nueva que se abre en un ciclo ya en curso (ej. la
 * institución agrega una "1ro C" a mitad de año). De hecho
 * `IngresantesController::crear` ya asume que el curso de destino existe
 * (hace `findOrFail`) — sin este controlador no había forma de crear ese
 * curso antes del primer ingresante.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * gestión de la estructura académica.
 */
class CursosController extends Controller
{
    public function crear(CrearCursoRequest $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'ciclo' => ['Los cursos se crean sobre un ciclo lectivo abierto — este está cerrado y archivado de solo lectura.'],
            ]);
        }

        $nivelId = $request->validated('nivel_id');
        $divisionId = $request->validated('division_id');

        $this->verificarCombinacionDisponible($nivelId, $divisionId, $ciclo->id_ciclo_lectivo);

        $curso = Curso::create([
            'nivel_id' => $nivelId,
            'division_id' => $divisionId,
            'ciclo_lectivo_id' => $ciclo->id_ciclo_lectivo,
            'turno' => $request->validated('turno'),
        ]);

        return response()->json(['data' => $this->formatear($curso->fresh(['nivel', 'division']))], 201);
    }

    public function index(CicloLectivo $ciclo): JsonResponse
    {
        $cursos = Curso::with(['nivel', 'division'])
            ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->get()
            ->sortBy([
                fn ($c) => $c->nivel->numero_orden,
                fn ($c) => $c->division->nombre,
            ])
            ->values();

        return response()->json(['data' => $cursos->map(fn (Curso $c) => $this->formatear($c))->values()]);
    }

    public function actualizar(ActualizarCursoRequest $request, Curso $curso): JsonResponse
    {
        if ($curso->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'curso' => ['No se puede editar un curso de un ciclo lectivo cerrado y archivado de solo lectura.'],
            ]);
        }

        $curso->update(['turno' => $request->validated('turno')]);

        return response()->json(['data' => $this->formatear($curso->fresh(['nivel', 'division']))]);
    }

    public function eliminar(Curso $curso): JsonResponse
    {
        if ($curso->cicloLectivo->estado !== 'abierto') {
            throw ValidationException::withMessages([
                'curso' => ['No se puede eliminar un curso de un ciclo lectivo cerrado y archivado de solo lectura.'],
            ]);
        }

        // Nunca se elimina un curso que ya tiene inscripciones (activas
        // o históricas) — las planillas de asistencia también referencian
        // curso_id directamente, así que borrarlo dejaría huérfanos esos
        // registros. Si el curso está mal cargado y todavía no tiene
        // ningún alumno, esto lo permite sin problema.
        $tieneInscripciones = $curso->inscripciones()->exists();
        if ($tieneInscripciones) {
            throw ValidationException::withMessages([
                'curso' => ['Este curso ya tiene inscripciones asociadas — no se puede eliminar.'],
            ]);
        }

        $curso->delete();

        return response()->json(['data' => ['id_curso' => $curso->id_curso, 'eliminado' => true]]);
    }

    private function verificarCombinacionDisponible(int $nivelId, int $divisionId, int $cicloLectivoId): void
    {
        // uq_cursos_nivel_division_ciclo no incluye deleted_at, mismo
        // patrón de chequeo manual "trashed-aware" que en niveles,
        // divisiones, especialidades, roles y usuarios.
        $existente = Curso::withTrashed()
            ->where('nivel_id', $nivelId)
            ->where('division_id', $divisionId)
            ->where('ciclo_lectivo_id', $cicloLectivoId)
            ->first();

        if ($existente !== null) {
            throw ValidationException::withMessages([
                'nivel_id' => [$existente->trashed()
                    ? "Ya existe un curso con esta combinación de nivel y división en este ciclo (id {$existente->id_curso}), pero está dado de baja — hay que restaurarlo en vez de crear uno nuevo."
                    : "Ya existe un curso con esta combinación de nivel y división en este ciclo (id {$existente->id_curso})."],
            ]);
        }
    }

    private function formatear(Curso $curso): array
    {
        return [
            'id_curso' => $curso->id_curso,
            'nivel_id' => $curso->nivel_id,
            'nivel_nombre' => $curso->nivel?->nombre,
            'division_id' => $curso->division_id,
            'division_nombre' => $curso->division?->nombre,
            'ciclo_lectivo_id' => $curso->ciclo_lectivo_id,
            'turno' => $curso->turno,
        ];
    }
}

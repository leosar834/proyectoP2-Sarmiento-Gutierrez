<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CicloLectivo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Resuelve "qué curso o grupos son míos" para el usuario logueado, del
 * lado del ciclo lectivo abierto — es el paso que le falta al cliente
 * (móvil o web) antes de poder llamar a `POST /planillas`, que ya exige
 * un `curso_id` / `grupo_taller_id` / `grupo_ed_fisica_id` concreto.
 *
 * A propósito no se filtra esta ruta con un `permiso:` puntual, igual
 * que `/me`: se limita a devolver la propia pertenencia del usuario
 * autenticado leída directo de las tablas puente (`usuarios_cursos`,
 * `usuarios_grupos_taller`, `profesor_id` en `grupos_ed_fisica`), no
 * datos de terceros — así que no hay nada que autorizar más allá de
 * estar logueado. Un usuario sin ninguna asignación (ej. `director`)
 * simplemente recibe una lista vacía.
 */
class AsignacionesController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $usuario = $request->user();
        $ciclo = CicloLectivo::where('estado', 'abierto')->first();

        if (! $ciclo) {
            return response()->json(['data' => []]);
        }

        $cursos = $usuario->cursos()
            ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->with(['nivel', 'division'])
            ->get()
            ->map(fn ($curso) => [
                'area' => 'teorica',
                'id' => $curso->id_curso,
                'etiqueta' => "{$curso->nivel->nombre} {$curso->division->nombre} ({$curso->turno})",
            ]);

        $gruposTaller = $usuario->gruposTaller()
            ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->with('materiaTaller')
            ->get()
            ->map(fn ($grupo) => [
                'area' => 'taller',
                'id' => $grupo->id_grupo_taller,
                'etiqueta' => "{$grupo->materiaTaller->nombre} — {$grupo->nombre_grupo}",
                'rol_en_grupo' => $grupo->pivot->rol_en_grupo,
            ]);

        $gruposEdFisica = $usuario->gruposEdFisicaComoProfesor()
            ->where('ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->get()
            ->map(fn ($grupo) => [
                'area' => 'ed_fisica',
                'id' => $grupo->id_grupo_ed_fisica,
                'etiqueta' => $grupo->nombre_grupo,
            ]);

        return response()->json([
            'data' => $cursos->concat($gruposTaller)->concat($gruposEdFisica)->values(),
        ]);
    }
}

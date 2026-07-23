<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CicloLectivo;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Fase 1 del "Proceso de Cierre y Apertura en Cuatro Fases" (narrativa)
 * — RF1, "Dar inicio y fin del ciclo lectivo". Delega el cálculo pesado
 * a `sp_cerrar_ciclo` (ver database/sql/schema.sql, sección 14): este
 * controller solo valida que el ciclo no esté ya cerrado, invoca el
 * procedimiento y devuelve el resultado.
 *
 * Las fases 2 a 4 (definir desenlaces, clonar estructura y generar
 * inscripciones, población manual) quedan para más adelante — la
 * propia narrativa las separa a propósito, porque requieren decisión
 * humana entre cada una.
 */
class CierreCicloController extends Controller
{
    public function cerrar(Request $request, CicloLectivo $ciclo): JsonResponse
    {
        if ($ciclo->estado === 'cerrado') {
            throw ValidationException::withMessages([
                'ciclo' => ['Este ciclo lectivo ya está cerrado.'],
            ]);
        }

        DB::statement('CALL sp_cerrar_ciclo(?)', [$ciclo->id_ciclo_lectivo]);

        $ciclo->refresh();

        $resultadosGenerados = DB::table('resultados_finales')
            ->join('inscripciones', 'inscripciones.id_inscripcion', '=', 'resultados_finales.inscripcion_id')
            ->where('inscripciones.ciclo_lectivo_id', $ciclo->id_ciclo_lectivo)
            ->count();

        return response()->json([
            'data' => [
                'ciclo' => [
                    'id_ciclo_lectivo' => $ciclo->id_ciclo_lectivo,
                    'anio' => $ciclo->anio,
                    'estado' => $ciclo->estado,
                    'fecha_cierre' => $ciclo->fecha_cierre,
                ],
                'resultados_generados' => $resultadosGenerados,
            ],
        ]);
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Exports\PlantillaImportacionAlumnosExport;
use App\Http\Requests\Api\Alumnos\ImportarAlumnosRequest;
use App\Imports\AlumnosImport;
use App\Models\CicloLectivo;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;
use Maatwebsite\Excel\Facades\Excel;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

/**
 * Carga masiva de alumnos desde una planilla Excel (legajo + inscripción
 * al curso correspondiente, en el mismo paso) — ver el docblock de
 * `AlumnosImport` para el porqué de que esto sea un controlador aparte
 * de `IngresantesController`/`AlumnosController` en vez de una opción
 * más ahí.
 *
 * `plantilla()` va SIN `auth:sanctum` a propósito (ver routes/api.php):
 * es un archivo estático sin datos de la institución, el mismo para
 * cualquiera — no hay nada que proteger, y dejarlo público evita tener
 * que resolver descarga de archivos autenticada del lado de Flutter
 * (headers `Authorization` en una descarga de archivo binario) para
 * algo que no lo necesita.
 */
class ImportacionAlumnosController extends Controller
{
    public function plantilla(): BinaryFileResponse
    {
        return Excel::download(new PlantillaImportacionAlumnosExport(), 'plantilla_alumnos.xlsx');
    }

    public function importar(ImportarAlumnosRequest $request): JsonResponse
    {
        $ciclo = CicloLectivo::where('estado', 'abierto')->first();
        if (! $ciclo) {
            throw ValidationException::withMessages([
                'archivo' => ['No hay ningún ciclo lectivo abierto — hace falta uno para poder inscribir alumnos.'],
            ]);
        }

        $importacion = new AlumnosImport($ciclo->id_ciclo_lectivo);
        Excel::import($importacion, $request->file('archivo'));

        $creados = collect($importacion->resultados)->where('estado', 'creado')->count();
        $salteados = collect($importacion->resultados)->where('estado', 'salteado')->count();

        return response()->json([
            'data' => [
                'creados' => $creados,
                'salteados' => $salteados,
                'detalle' => $importacion->resultados,
            ],
        ]);
    }
}

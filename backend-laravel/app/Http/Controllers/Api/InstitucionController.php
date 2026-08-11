<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Institucion\ActualizarInstitucionRequest;
use App\Http\Resources\InstitucionResource;
use App\Models\Institucion;
use Illuminate\Http\JsonResponse;
use Illuminate\Validation\ValidationException;

/**
 * Ficha de la institución (tabla `institucion`, fila única) — ver el
 * docblock de App\Models\Institucion. `mostrar()` la expone para
 * pintarla en el panel de administración (encabezados, reportes
 * impresos, etc.); `actualizar()` es la única forma de modificarla
 * después del alta inicial que hace RegistroAdministradorController —
 * siempre editable por el administrador, nunca queda fija.
 *
 * Va detrás de `permiso:gestionar_sistema`, igual que el resto de la
 * configuración del sistema (roles, usuarios).
 */
class InstitucionController extends Controller
{
    public function mostrar(): JsonResponse
    {
        return response()->json([
            'data' => new InstitucionResource($this->obtenerInstitucion()),
        ]);
    }

    public function actualizar(ActualizarInstitucionRequest $request): JsonResponse
    {
        $institucion = $this->obtenerInstitucion();

        $institucion->update($request->validated());

        return response()->json([
            'data' => new InstitucionResource($institucion->fresh()),
        ]);
    }

    /**
     * Siempre debería existir — se crea junto con el primer
     * administrador (ver RegistroAdministradorController::crear()) y
     * este controller entero vive detrás de auth:sanctum, así que para
     * llegar acá ya tuvo que existir al menos un administrador. Si no
     * está, el problema real es una instalación inconsistente, no algo
     * que este controller pueda resolver inventando datos.
     */
    private function obtenerInstitucion(): Institucion
    {
        $institucion = Institucion::find(1);

        if ($institucion === null) {
            throw ValidationException::withMessages([
                'institucion' => ['Todavía no se cargaron los datos de la institución.'],
            ]);
        }

        return $institucion;
    }
}

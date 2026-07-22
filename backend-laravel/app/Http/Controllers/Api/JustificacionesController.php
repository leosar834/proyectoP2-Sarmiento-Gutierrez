<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Justificaciones\ListarPendientesRequest;
use App\Http\Requests\Api\Justificaciones\RegistrarJustificacionRequest;
use App\Http\Resources\JustificacionResource;
use App\Models\Inscripcion;
use App\Models\Justificacion;
use App\Models\Usuario;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Implementa RF5 (Gestión de Faltas Justificadas): un padre/madre/tutor
 * presenta la justificación en uno de dos puntos posibles —
 * preceptoría principal o el área de taller — y quien la recibe queda
 * registrado como responsable de que el sector opuesto se entere. Este
 * controller modela esa notificación cruzada como dos pasos explícitos
 * (`crear` desde el sector receptor, `notificar` desde el sector
 * opuesto), en vez de darla por hecha automáticamente al guardar: la
 * narrativa distingue "recibir" de "notificar al otro punto" como dos
 * responsabilidades separadas, y el estado `pendiente`/`notificada` de
 * la tabla existe justamente para poder rastrear si ese segundo paso ya
 * ocurrió o no.
 *
 * Todas las rutas van detrás de `permiso:justificar_inasistencias`
 * (exclusivo de plataforma móvil) — ver routes/api.php.
 */
class JustificacionesController extends Controller
{
    public function crear(RegistrarJustificacionRequest $request): JsonResponse
    {
        $datos = $request->validated();
        $usuario = $request->user();
        $area = $datos['area_receptora'];

        if (! $this->usuarioTieneRolEnArea($usuario, $area)) {
            throw ValidationException::withMessages([
                'area_receptora' => ['Tu rol no corresponde a ese punto de recepción.'],
            ]);
        }

        if (! $this->inscripcionPerteneceAlArea($usuario, (int) $datos['inscripcion_id'], $area)) {
            throw ValidationException::withMessages([
                'inscripcion_id' => ['Ese alumno no pertenece a un curso/grupo tuyo.'],
            ]);
        }

        $justificacion = Justificacion::create([
            ...$datos,
            'usuario_receptor_id' => $usuario->id_usuario,
        ]);

        // create() no vuelve a leer la fila: `estado_notificacion` quedaría
        // en null en el objeto en memoria aunque la columna ya tenga su
        // default ('pendiente') aplicado en MySQL. Se relee para que la
        // respuesta muestre el valor real, no el que Eloquent nunca pidió.
        $justificacion = $justificacion->fresh(['inscripcion.alumno', 'usuarioReceptor']);

        return (new JustificacionResource($justificacion))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * Justificaciones que le tocan notificar al sector OPUESTO al que
     * indica `mi_area` — es decir, las que ese sector todavía no marcó
     * como recibidas.
     */
    public function pendientes(ListarPendientesRequest $request): JsonResponse
    {
        $usuario = $request->user();
        $miArea = $request->validated('mi_area');

        if (! $this->usuarioTieneRolEnArea($usuario, $miArea)) {
            throw ValidationException::withMessages([
                'mi_area' => ['Tu rol no corresponde a ese sector.'],
            ]);
        }

        $areaOpuesta = $miArea === 'preceptoria' ? 'taller' : 'preceptoria';

        $justificaciones = Justificacion::with(['inscripcion.alumno', 'usuarioReceptor'])
            ->where('area_receptora', $areaOpuesta)
            ->where('estado_notificacion', 'pendiente')
            ->orderBy('fecha_presentacion')
            ->get();

        return JustificacionResource::collection($justificaciones)->response();
    }

    /**
     * Marca como notificada una justificación — la ejecuta alguien del
     * sector OPUESTO al que la recibió originalmente, confirmando que
     * ya se enteró.
     */
    public function notificar(Request $request, Justificacion $justificacion): JsonResponse
    {
        $usuario = $request->user();
        $areaOpuesta = $justificacion->area_receptora === 'preceptoria' ? 'taller' : 'preceptoria';

        if (! $this->usuarioTieneRolEnArea($usuario, $areaOpuesta)) {
            throw ValidationException::withMessages([
                'justificacion' => ['Esta justificación no corresponde notificarla desde tu sector.'],
            ]);
        }

        if ($justificacion->estado_notificacion === 'notificada') {
            throw ValidationException::withMessages([
                'justificacion' => ['Esta justificación ya fue notificada.'],
            ]);
        }

        $justificacion->update([
            'estado_notificacion' => 'notificada',
            'fecha_notificacion' => now(),
        ]);

        return (new JustificacionResource($justificacion->load(['inscripcion.alumno', 'usuarioReceptor'])))->response();
    }

    /**
     * `preceptor` recibe en preceptoría principal; `preceptor_taller`,
     * `profesor_taller` y `jefe_taller` reciben en el área de taller —
     * tal cual los tres puntos de recepción que enumera la narrativa
     * para el sector de taller.
     */
    private function rolesValidosParaArea(string $area): array
    {
        return match ($area) {
            'preceptoria' => ['preceptor'],
            'taller' => ['preceptor_taller', 'profesor_taller', 'jefe_taller'],
            default => [],
        };
    }

    private function usuarioTieneRolEnArea(Usuario $usuario, string $area): bool
    {
        return $usuario->roles()
            ->whereIn('roles.nombre', $this->rolesValidosParaArea($area))
            ->exists();
    }

    private function inscripcionPerteneceAlArea(Usuario $usuario, int $inscripcionId, string $area): bool
    {
        return match ($area) {
            'preceptoria' => Inscripcion::where('id_inscripcion', $inscripcionId)
                ->whereIn('curso_id', $usuario->cursos()->pluck('cursos.id_curso'))
                ->exists(),
            'taller' => $usuario->gruposTaller()
                ->whereHas('inscripciones', fn ($q) => $q->where('inscripciones.id_inscripcion', $inscripcionId))
                ->exists(),
            default => false,
        };
    }
}
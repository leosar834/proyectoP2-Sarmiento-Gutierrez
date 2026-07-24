<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\Asistencia\CorregirDetalleRequest;
use App\Http\Requests\Api\Asistencia\CrearPlanillaRequest;
use App\Http\Requests\Api\Asistencia\GuardarDetallesRequest;
use App\Http\Resources\DetalleAsistenciaResource;
use App\Http\Resources\PlanillaAsistenciaResource;
use App\Models\Curso;
use App\Models\DetalleAsistencia;
use App\Models\DiaSinClase;
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
 * Implementa el flujo de RF2 (Registro de Asistencia) de la narrativa.
 * Las rutas de este controller van todas detrás de
 * `permiso:tomar_asistencia` / `permiso:editar_asistencia_del_dia` /
 * `permiso:corregir_asistencia_historica` según corresponda (ver
 * routes/api.php) — acá adentro ya se asume que el rol y la plataforma
 * están bien, lo que falta chequear es la pertenencia: que el curso o
 * grupo sea efectivamente del usuario logueado.
 *
 * Simplificación documentada a propósito: la narrativa describe para
 * taller un paso de "verificar" y otro de "enviar" antes del bloqueo
 * (RF2). Acá se modela como una sola transición (`enviar()`,
 * en_curso -> bloqueada) porque el punto de la narrativa que sí importa
 * para el sistema es el resultado — la planilla queda bloqueada y solo
 * jefa de preceptores/administrador puede corregirla después — no un
 * tercer estado intermedio persistido sin reglas propias.
 */
class AsistenciaController extends Controller
{
    /**
     * Abre la planilla del día para un curso o grupo. Siempre hoy — ver
     * la nota en CrearPlanillaRequest.
     */
    public function crear(CrearPlanillaRequest $request): JsonResponse
    {
        $datos = $request->validated();
        $usuario = $request->user();

        if (! PermisoDiario::estaVigenteHoy()) {
            throw ValidationException::withMessages([
                'fecha' => ['No hay un permiso diario abierto para tomar asistencia hoy.'],
            ]);
        }

        $diaSinClases = $this->buscarDiaSinClasesHoy($datos['area'], $datos);
        if ($diaSinClases !== null) {
            throw ValidationException::withMessages([
                'fecha' => ["Hoy es un día sin clases ({$diaSinClases->motivo}) — no se puede abrir la planilla."],
            ]);
        }

        $planilla = new PlanillaAsistencia([
            'area' => $datos['area'],
            'curso_id' => $datos['curso_id'] ?? null,
            'grupo_taller_id' => $datos['grupo_taller_id'] ?? null,
            'grupo_ed_fisica_id' => $datos['grupo_ed_fisica_id'] ?? null,
            'fecha' => now()->toDateString(),
            'usuario_registro_id' => $usuario->id_usuario,
            'estado' => 'en_curso',
        ]);

        if (! $this->usuarioPuedeOperar($usuario, $planilla)) {
            throw ValidationException::withMessages([
                'area' => ['Ese curso/grupo no está asignado a tu usuario.'],
            ]);
        }

        // Evita duplicar la planilla del día si ya se había abierto
        // (la tabla no tiene UNIQUE por curso+fecha, a diferencia de
        // otras — se resuelve acá en vez de en el schema, ver PDF sec. 6.6
        // sobre el criterio de únicos elegido para esta tabla).
        $existente = PlanillaAsistencia::query()
            ->where('area', $planilla->area)
            ->where('curso_id', $planilla->curso_id)
            ->where('grupo_taller_id', $planilla->grupo_taller_id)
            ->where('grupo_ed_fisica_id', $planilla->grupo_ed_fisica_id)
            ->whereDate('fecha', $planilla->fecha)
            ->first();

        $planilla = $existente ?? tap($planilla)->save();

        return (new PlanillaAsistenciaResource($planilla->load('detalles.inscripcion.alumno')))
            ->response()
            ->setStatusCode($existente ? 200 : 201);
    }

    /**
     * Carga o corrige el estado de todos los alumnos de la planilla,
     * de una — ver la nota en GuardarDetallesRequest. Sirve tanto para
     * la carga inicial (tomar_asistencia) como para las correcciones
     * del mismo día (editar_asistencia_del_dia); las rutas exigen el
     * segundo permiso, que en la matriz de la EETN.° 1 siempre viene
     * acompañado del primero para los roles operativos.
     */
    public function guardarDetalles(GuardarDetallesRequest $request, PlanillaAsistencia $planilla): JsonResponse
    {
        $usuario = $request->user();

        if (! $this->usuarioPuedeOperar($usuario, $planilla)) {
            throw ValidationException::withMessages([
                'planilla' => ['Esa planilla no corresponde a un curso/grupo tuyo.'],
            ]);
        }

        if (! $planilla->fecha->isToday()) {
            throw ValidationException::withMessages([
                'planilla' => ['Esta planilla no es de hoy — para corregirla hace falta el permiso de corrección histórica.'],
            ]);
        }

        if ($planilla->estaBloqueada()) {
            throw ValidationException::withMessages([
                'planilla' => ['La planilla ya está bloqueada. Solo jefa de preceptores/administrador puede corregirla.'],
            ]);
        }

        foreach ($request->validated('detalles') as $fila) {
            DetalleAsistencia::updateOrCreate(
                [
                    'planilla_id' => $planilla->id_planilla,
                    'inscripcion_id' => $fila['inscripcion_id'],
                ],
                [
                    'estado' => $fila['estado'],
                    'observaciones' => $fila['observaciones'] ?? null,
                    'hora_registro' => now(),
                ]
            );
        }

        return new PlanillaAsistenciaResource($planilla->load('detalles.inscripcion.alumno'));
    }

    /**
     * Confirma y envía la planilla de TALLER a preceptoría principal —
     * exclusivo del preceptor de taller del grupo (RF2). A partir de acá
     * el trigger de MySQL bloquea cualquier INSERT/UPDATE sobre sus
     * detalles salvo con el override de corrección administrativa.
     */
    public function enviar(Request $request, PlanillaAsistencia $planilla): JsonResponse
    {
        $usuario = $request->user();

        if ($planilla->area !== 'taller') {
            throw ValidationException::withMessages([
                'planilla' => ['Solo las planillas de taller se envían — teóricas y educación física se corrigen directamente.'],
            ]);
        }

        $esPreceptorTaller = $planilla->grupoTaller
            ->preceptorTaller()
            ->where('id_usuario', $usuario->id_usuario)
            ->exists();

        if (! $esPreceptorTaller) {
            throw ValidationException::withMessages([
                'planilla' => ['Solo el preceptor de taller de este grupo puede enviar la planilla.'],
            ]);
        }

        $idsInscripciones = $planilla->grupoTaller->inscripciones()->pluck('inscripciones.id_inscripcion');
        $idsCargados = DetalleAsistencia::where('planilla_id', $planilla->id_planilla)
            ->whereIn('inscripcion_id', $idsInscripciones)
            ->pluck('inscripcion_id');

        if ($idsCargados->count() < $idsInscripciones->count()) {
            throw ValidationException::withMessages([
                'planilla' => ['Todavía hay alumnos sin un estado cargado en esta planilla.'],
            ]);
        }

        $planilla->update(['estado' => 'bloqueada', 'hora_confirmacion' => now()]);

        return new PlanillaAsistenciaResource($planilla->load('detalles.inscripcion.alumno'));
    }

    /**
     * Corrección sin restricción de fecha (permiso
     * corregir_asistencia_historica, exclusivo de jefa de
     * preceptores/administrador). Levanta el override que espera
     * `trg_detalles_before_update` en MySQL — sin él, el trigger
     * rechaza el UPDATE de cualquier detalle cuya planilla esté
     * bloqueada, sin importar quién lo pida.
     */
    public function corregirDetalle(CorregirDetalleRequest $request, DetalleAsistencia $detalle): JsonResponse
    {
        DB::statement('SET @permitir_correccion_admin = 1');

        try {
            $detalle->update($request->validated());
        } finally {
            DB::statement('SET @permitir_correccion_admin = 0');
        }

        return (new DetalleAsistenciaResource($detalle->load('inscripcion.alumno')))
            ->response();
    }

    /**
     * Calendario escolar (RF1/estructura académica): si hoy está
     * declarado como día sin clases para el ciclo/turno de este
     * curso o grupo, no se deja abrir la planilla — es lo que hace
     * cierto el supuesto de `sp_recalcular_contador` en la base ("los
     * días sin clases quedan excluidos por construcción" de
     * `total_clases`).
     *
     * Limitación documentada a propósito: `alcance` puede acotar el
     * feriado a un turno puntual ('mañana'/'tarde'/'noche'), pero solo
     * `Curso` tiene columna `turno` — `GrupoTaller` y `GrupoEdFisica`
     * no. Para área taller/ed_fisica solo se puede chequear contra
     * `alcance = 'todos'` (día completo); un día sin clases acotado a un
     * turno puntual no tiene cómo aplicarse a esas dos áreas porque no
     * existe el dato con el que compararlo.
     */
    private function buscarDiaSinClasesHoy(string $area, array $datos): ?DiaSinClase
    {
        [$cicloLectivoId, $turno] = match ($area) {
            'teorica' => (function () use ($datos) {
                $curso = Curso::find($datos['curso_id'] ?? null);

                return [$curso?->ciclo_lectivo_id, $curso?->turno];
            })(),
            'taller' => [GrupoTaller::find($datos['grupo_taller_id'] ?? null)?->ciclo_lectivo_id, null],
            'ed_fisica' => [GrupoEdFisica::find($datos['grupo_ed_fisica_id'] ?? null)?->ciclo_lectivo_id, null],
            default => [null, null],
        };

        if ($cicloLectivoId === null) {
            return null;
        }

        $alcancesAplicables = $turno !== null ? ['todos', $turno] : ['todos'];

        return DiaSinClase::where('ciclo_lectivo_id', $cicloLectivoId)
            ->whereDate('fecha', now()->toDateString())
            ->whereIn('alcance', $alcancesAplicables)
            ->first();
    }

    private function usuarioPuedeOperar(Usuario $usuario, PlanillaAsistencia $planilla): bool
    {
        return match ($planilla->area) {
            'teorica' => $planilla->curso?->preceptores()
                ->where('id_usuario', $usuario->id_usuario)->exists() ?? false,
            'taller' => $planilla->grupoTaller?->usuarios()
                ->where('id_usuario', $usuario->id_usuario)->exists() ?? false,
            'ed_fisica' => $planilla->grupoEdFisica?->profesor_id === $usuario->id_usuario,
            default => false,
        };
    }
}

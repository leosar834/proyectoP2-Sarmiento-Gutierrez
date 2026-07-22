<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Justificación de inasistencia (tabla `justificaciones`) — RF5. Un
 * padre/madre/tutor puede presentarla en dos puntos: preceptoría
 * principal o el área de taller (jefe de taller, preceptor de taller o
 * profesor de taller). Quien la recibe (`usuario_receptor_id`,
 * `area_receptora`) es responsable de que el OTRO sector se entere —
 * `estado_notificacion` arranca en `pendiente` (default de la propia
 * columna, no se setea acá) y pasa a `notificada` cuando alguien del
 * sector opuesto la marca como leída, ver
 * `JustificacionesController::notificar()`.
 *
 * A propósito no tiene SoftDeletes: es un registro transaccional del
 * ciclo lectivo, igual que `detalles_asistencia` y `planillas_asistencia`.
 *
 * Ninguna acción de este modelo toca `contadores_asistencia`
 * directamente — el trigger `trg_justificaciones_after_insert` /
 * `_after_delete` ya recalcula `justificaciones_total` en MySQL. Las
 * justificaciones se cuentan aparte y no modifican los contadores de
 * inasistencia del alumno (narrativa, RF5).
 */
class Justificacion extends Model
{
    protected $table = 'justificaciones';

    protected $primaryKey = 'id_justificacion';

    protected $fillable = [
        'inscripcion_id',
        'fecha_inicio',
        'fecha_fin',
        'tipo',
        'fecha_presentacion',
        'area_receptora',
        'usuario_receptor_id',
        'estado_notificacion',
        'fecha_notificacion',
    ];

    protected function casts(): array
    {
        return [
            'fecha_inicio' => 'date',
            'fecha_fin' => 'date',
            'fecha_presentacion' => 'date',
            'fecha_notificacion' => 'datetime',
        ];
    }

    public function inscripcion(): BelongsTo
    {
        return $this->belongsTo(Inscripcion::class, 'inscripcion_id', 'id_inscripcion');
    }

    public function usuarioReceptor(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'usuario_receptor_id', 'id_usuario');
    }
}

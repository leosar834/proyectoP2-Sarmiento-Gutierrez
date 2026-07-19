<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Detalle de asistencia (tabla `detalles_asistencia`): una fila por
 * alumno (en realidad por `Inscripcion`, no por `Alumno` directamente —
 * misma lógica que en el resto del modelo) dentro de una planilla. Único
 * por (planilla_id, inscripcion_id): no se puede cargar dos veces al
 * mismo alumno en la misma planilla.
 *
 * No escribas en `contadores_asistencia` desde acá ni desde ningún otro
 * lado de la aplicación: los triggers `trg_detalles_after_*` de MySQL
 * recalculan esos contadores automáticamente en cada alta, baja o
 * modificación de esta tabla (y evalúan las alertas de límite de
 * inasistencias / seguimiento en el mismo movimiento). Escribirlos
 * también desde PHP duplicaría una lógica que ya está probada del lado
 * de la base — ver `Documentacion_Base_de_Datos.pdf`, sección 7.2.
 *
 * Corrección fuera de la jornada: si el trigger de bloqueo de MySQL
 * rechaza el INSERT/UPDATE porque la planilla ya está `bloqueada`, el
 * override es `DB::statement('SET @permitir_correccion_admin = 1')`
 * antes de la operación — y solo debe ejecutarlo la aplicación cuando
 * el usuario autenticado tiene el permiso `corregir_asistencia_historica`
 * (jefa de preceptores/administrador), nunca de forma incondicional.
 */
class DetalleAsistencia extends Model
{
    protected $table = 'detalles_asistencia';

    protected $primaryKey = 'id_detalle';

    protected $fillable = [
        'planilla_id',
        'inscripcion_id',
        'estado',
        'hora_registro',
        'observaciones',
    ];

    protected function casts(): array
    {
        return [
            'hora_registro' => 'datetime',
        ];
    }

    public function planilla(): BelongsTo
    {
        return $this->belongsTo(PlanillaAsistencia::class, 'planilla_id', 'id_planilla');
    }

    public function inscripcion(): BelongsTo
    {
        return $this->belongsTo(Inscripcion::class, 'inscripcion_id', 'id_inscripcion');
    }
}

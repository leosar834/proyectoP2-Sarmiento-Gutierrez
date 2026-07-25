<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Auto-reporte de ausencia de un profesor de taller/educación física
 * para un grupo y fecha puntuales (tabla `ausencias_docentes`) — no
 * aplica a preceptores (narrativa ampliada: tienen un suplente asignado
 * para cubrir su ausencia) ni a la asistencia teórica (siempre
 * obligatoria mientras haya clases). Funcionalidad pedida explícitamente
 * por la cátedra, fuera de la narrativa original.
 *
 * El efecto real de esta tabla lo hace cumplir
 * `AsistenciaController::crear()`: antes de abrir una planilla de
 * taller/ed. física consulta si existe una fila acá para ese
 * grupo+fecha, y si existe rechaza la apertura — mismo mecanismo (por
 * construcción, sin planilla no hay `detalles_asistencia`, así que
 * `sp_cerrar_ciclo` no cuenta ese día en `total_clases`) que ya usa
 * `DiaSinClase` para los días sin clases institucionales.
 *
 * Siempre es HOY — no se notifica con anticipación ni en retrospectiva,
 * a pedido explícito de la cátedra: el profesor recibe la notificación
 * para tomar asistencia el mismo día, y ese mismo día, si falta,
 * notifica su ausencia. Por eso no hay validación de "es día de clase"
 * más allá de lo que ya exige el propio grupo (ciclo abierto, profesor
 * asignado) — la fecha nunca la manda el cliente, siempre es `now()`.
 *
 * Sin SoftDeletes a propósito, mismo criterio que `DiaSinClase`: no es
 * historial inmutable, es una notificación puntual del día que el
 * propio profesor puede dar de baja (`AusenciasDocentesController::eliminar()`)
 * si se equivocó — nada más referencia esta fila por FK.
 */
class AusenciaDocente extends Model
{
    protected $table = 'ausencias_docentes';

    protected $primaryKey = 'id_ausencia_docente';

    protected $fillable = [
        'usuario_id',
        'area',
        'grupo_taller_id',
        'grupo_ed_fisica_id',
        'fecha',
    ];

    protected function casts(): array
    {
        return [
            'fecha' => 'date',
        ];
    }

    public function usuario(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'usuario_id', 'id_usuario');
    }

    public function grupoTaller(): BelongsTo
    {
        return $this->belongsTo(GrupoTaller::class, 'grupo_taller_id', 'id_grupo_taller');
    }

    public function grupoEdFisica(): BelongsTo
    {
        return $this->belongsTo(GrupoEdFisica::class, 'grupo_ed_fisica_id', 'id_grupo_ed_fisica');
    }
}

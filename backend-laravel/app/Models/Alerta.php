<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Alerta automática (tabla `alertas`) — RF6. Dos de los tres tipos que
 * define la narrativa (`limite_inasistencias` y `seguimiento`) los
 * genera el propio procedimiento `sp_recalcular_contador` en MySQL,
 * disparado desde los mismos triggers que ya recalculan
 * `contadores_asistencia` — no hay lógica de negocio que reimplementar
 * acá, la app solo lista y marca como atendidas. El tercer tipo
 * (`asistencia_perfecta`) se genera al cierre de ciclo lectivo, un
 * proceso todavía no construido.
 *
 * Por eso `$fillable` queda reducido a `estado`: la aplicación nunca
 * debe insertar una fila acá (eso ya lo hace MySQL, con su propia
 * lógica de "no duplicar si ya hay una activa del mismo tipo"), solo
 * transicionarla de `activa` a `atendida`.
 */
class Alerta extends Model
{
    protected $table = 'alertas';

    protected $primaryKey = 'id_alerta';

    protected $fillable = [
        'estado',
    ];

    protected function casts(): array
    {
        return [
            'fecha_generacion' => 'datetime',
        ];
    }

    public function inscripcion(): BelongsTo
    {
        return $this->belongsTo(Inscripcion::class, 'inscripcion_id', 'id_inscripcion');
    }
}

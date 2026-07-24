<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Día sin clases (tabla `dias_sin_clases`): feriados, actos, jornadas
 * institucionales, etc. `alcance` permite anular un solo turno
 * ('mañana'/'tarde'/'noche') en vez del día completo (default 'todos').
 *
 * Sin SoftDeletes a propósito: no está en la lista de tablas con borrado
 * lógico del schema (ver comentario de cabecera de schema.sql) — a
 * diferencia de niveles/divisiones/especialidades/cursos, nada más
 * referencia esta tabla por FK, así que un DELETE físico no deja nada
 * huérfano. Por lo mismo, el chequeo de duplicados (fecha + alcance) en
 * los FormRequest correspondientes SÍ puede usar `Rule::unique` directo,
 * sin el patrón "trashed-aware" que se usa en las demás tablas de
 * catálogo.
 *
 * Uso real: `AsistenciaController::crear()` consulta esta tabla antes de
 * abrir una planilla — es lo que hace cierto el comentario de
 * `sp_recalcular_contador` en la base ("los días sin clases quedan
 * excluidos por construcción" de `total_clases`). Sin ese chequeo, nada
 * impedía abrir una planilla en un día declarado sin clases.
 */
class DiaSinClase extends Model
{
    protected $table = 'dias_sin_clases';

    protected $primaryKey = 'id_dia_sin_clase';

    protected $fillable = [
        'ciclo_lectivo_id',
        'fecha',
        'motivo',
        'alcance',
    ];

    protected function casts(): array
    {
        return [
            'fecha' => 'date',
        ];
    }

    public function cicloLectivo(): BelongsTo
    {
        return $this->belongsTo(CicloLectivo::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }
}

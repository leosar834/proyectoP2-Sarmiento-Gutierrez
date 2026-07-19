<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Permiso diario para tomar asistencia (tabla `permisos_diarios`). La
 * apertura es manual —el jefe de preceptores abre el día explícitamente,
 * `usuario_apertura_id` es obligatorio tal como pide la narrativa— pero
 * el cierre NO se marca a mano ni depende de ningún proceso programado:
 * se calcula comparando la hora actual contra `hora_limite` (23:59:59
 * por defecto). `cerrado_manual` solo existe para un cierre anticipado
 * explícito si hiciera falta.
 *
 * La automatización completa de la apertura (a una hora fija) se evaluó,
 * se implementó y se probó, y finalmente se revirtió
 *  — ver `Documentacion_Base_de_Datos.pdf`, sección 6.5.
 * No es un olvido, es la decisión final.
 *
 * El propio trigger `trg_planillas_before_insert` en MySQL ya impide
 * crear una planilla de HOY sin este permiso abierto y vigente —
 * `estaVigenteHoy()` acá abajo es la misma regla del lado de PHP, para
 * poder validar (y dar un mensaje claro) antes de llegar a la base.
 */
class PermisoDiario extends Model
{
    protected $table = 'permisos_diarios';

    protected $primaryKey = 'id_permiso_diario';

    protected $fillable = [
        'fecha',
        'usuario_apertura_id',
        'hora_apertura',
        'hora_limite',
        'cerrado_manual',
    ];

    protected function casts(): array
    {
        return [
            'fecha' => 'date',
            'hora_apertura' => 'datetime',
            'cerrado_manual' => 'boolean',
        ];
    }

    public function usuarioApertura(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'usuario_apertura_id', 'id_usuario');
    }

    /**
     * Espejo en PHP de `vista_permisos_diarios_vigentes`: ¿hay un
     * permiso de HOY, no cerrado a mano, y todavía no pasó la hora
     * límite?
     */
    public static function estaVigenteHoy(): bool
    {
        return static::query()
            ->whereDate('fecha', now()->toDateString())
            ->where('cerrado_manual', false)
            ->whereTime('hora_limite', '>=', now()->format('H:i:s'))
            ->exists();
    }
}

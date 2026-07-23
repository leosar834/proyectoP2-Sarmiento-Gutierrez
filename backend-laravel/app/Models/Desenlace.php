<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Desenlace de fin de ciclo (tabla `desenlaces`) — Fase 2 del "Proceso
 * de Cierre y Apertura en Cuatro Fases". Una fila por inscripción,
 * decidida por el administrador sobre un ciclo ya cerrado (Fase 1):
 * `promociona`, `recursa`, `egresa` o `baja`.
 *
 * `curso_destino_id` queda NULL durante toda esta fase a propósito: el
 * curso de destino todavía no existe (recién lo crea la Fase 3, al
 * abrir el ciclo nuevo) — ver `DesenlacesController`.
 */
class Desenlace extends Model
{
    protected $table = 'desenlaces';

    protected $primaryKey = 'id_desenlace';

    /**
     * A diferencia de la mayoría de las tablas del schema, `desenlaces`
     * no tiene columnas `created_at`/`updated_at` — la fecha del
     * registro es `fecha_definicion`, que la aplicación setea a mano.
     * Sin esto, Eloquent intenta escribir `updated_at` en cada
     * `update()` y MySQL lo rechaza (columna inexistente).
     */
    public $timestamps = false;

    protected $fillable = [
        'inscripcion_id',
        'tipo_desenlace',
        'curso_destino_id',
        'usuario_definicion_id',
        'fecha_definicion',
    ];

    protected function casts(): array
    {
        return [
            'fecha_definicion' => 'datetime',
        ];
    }

    public function inscripcion(): BelongsTo
    {
        return $this->belongsTo(Inscripcion::class, 'inscripcion_id', 'id_inscripcion');
    }

    public function cursoDestino(): BelongsTo
    {
        return $this->belongsTo(Curso::class, 'curso_destino_id', 'id_curso');
    }

    public function usuarioDefinicion(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'usuario_definicion_id', 'id_usuario');
    }
}
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * "Año" del establecimiento (tabla `niveles`, ej. "1er año", "2do año").
 * `numero_orden` es el dato que usa el sistema para promocionar
 * (N -> N+1) al cierre de ciclo; `nombre` es solo la etiqueta visible —
 * ver `Documentacion_Base_de_Datos.pdf`, sección 6.3. No confundir con
 * "especialidad": el nivel es el año en sí, la especialidad es la
 * orientación (Electromecánica, etc.) que recién se define en el ciclo
 * superior.
 */
class Nivel extends Model
{
    use SoftDeletes;

    protected $table = 'niveles';

    protected $primaryKey = 'id_nivel';

    protected $fillable = [
        'nombre',
        'numero_orden',
    ];

    protected function casts(): array
    {
        return [
            'numero_orden' => 'integer',
            'deleted_at' => 'datetime',
        ];
    }

    public function cursos(): HasMany
    {
        return $this->hasMany(Curso::class, 'nivel_id', 'id_nivel');
    }

    public function gruposTaller(): HasMany
    {
        return $this->hasMany(GrupoTaller::class, 'nivel_id', 'id_nivel');
    }
}

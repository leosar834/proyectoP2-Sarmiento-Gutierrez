<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Materia/taller de una especialidad (tabla `materias_taller`).
 * `regimen_cursada` es por materia, no global — la narrativa exige que
 * cada taller pueda tener su propia duración (anual/trimestral/
 * semestral/personalizado), a diferencia del curso principal que no
 * tiene este dato.
 *
 * `especialidad_id` es nullable: las escuelas técnico-profesionales
 * recién asignan la orientación a partir de 3°/4° año, así que las
 * materias de ciclo básico (1°/2° año) se cargan sin especialidad. Ver
 * la migración `make_especialidad_nullable_en_materias_taller`.
 */
class MateriaTaller extends Model
{
    use SoftDeletes;

    protected $table = 'materias_taller';

    protected $primaryKey = 'id_materia_taller';

    protected $fillable = [
        'especialidad_id',
        'nombre',
        'regimen_cursada',
    ];

    protected function casts(): array
    {
        return [
            'deleted_at' => 'datetime',
        ];
    }

    public function especialidad(): BelongsTo
    {
        return $this->belongsTo(Especialidad::class, 'especialidad_id', 'id_especialidad');
    }

    public function gruposTaller(): HasMany
    {
        return $this->hasMany(GrupoTaller::class, 'materia_taller_id', 'id_materia_taller');
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Especialidad/orientación propia de la institución (tabla
 * `especialidades`; ej. Electromecánica, Maestro Mayor de Obra,
 * Electrónica para la EETN.° 1). Cada institución define las suyas
 * narrativa.
 *
 * Se relaciona con `MateriaTaller` (qué talleres pertenecen a la
 * especialidad) y con `Inscripcion` (recién se asigna la especialidad al
 * alumno cuando llega al ciclo superior - `especialidad_id` en
 * `inscripciones` queda NULL hasta entonces).
 */
class Especialidad extends Model
{
    use SoftDeletes;

    protected $table = 'especialidades';

    protected $primaryKey = 'id_especialidad';

    protected $fillable = [
        'nombre',
    ];

    protected function casts(): array
    {
        return [
            'deleted_at' => 'datetime',
        ];
    }

    public function materiasTaller(): HasMany
    {
        return $this->hasMany(MateriaTaller::class, 'especialidad_id', 'id_especialidad');
    }

    public function inscripciones(): HasMany
    {
        return $this->hasMany(Inscripcion::class, 'especialidad_id', 'id_especialidad');
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Ciclo lectivo (tabla `ciclos_lectivos`): el año. Es el eje al que
 * cuelga todo lo transaccional del sistema (narrativa, "Traslado de
 * datos entre ciclos lectivos" — cursos, grupos, inscripciones y
 * asistencia se asocian a un ciclo; roles, permisos, especialidades y
 * parámetros de cálculo NO, porque son datos permanentes de la
 * institución).
 *
 * Sin SoftDeletes a propósito: un ciclo lectivo no se "borra", se cierra
 * (`estado = cerrado`) y queda archivado de solo lectura — ver
 * `Documentacion_Base_de_Datos.pdf`, sección 6.2.
 */
class CicloLectivo extends Model
{
    protected $table = 'ciclos_lectivos';

    protected $primaryKey = 'id_ciclo_lectivo';

    protected $fillable = [
        'anio',
        'fecha_inicio',
        'fecha_fin',
        'estado',
        'fecha_cierre',
    ];

    protected function casts(): array
    {
        return [
            'fecha_inicio' => 'date',
            'fecha_fin' => 'date',
            'fecha_cierre' => 'datetime',
        ];
    }

    public function cursos(): HasMany
    {
        return $this->hasMany(Curso::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }

    public function gruposTaller(): HasMany
    {
        return $this->hasMany(GrupoTaller::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }

    public function gruposEdFisica(): HasMany
    {
        return $this->hasMany(GrupoEdFisica::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }

    public function inscripciones(): HasMany
    {
        return $this->hasMany(Inscripcion::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }
}

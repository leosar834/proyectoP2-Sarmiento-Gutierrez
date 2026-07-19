<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Legajo permanente del alumno (tabla `alumnos`). Esta es la distinción
 * más importante del modelo,
 * cualquier código: el legajo (identidad del alumno, esta clase) y la
 * `Inscripcion` (su vínculo con un curso en un ciclo lectivo puntual)
 * son cosas distintas. Todo lo transaccional,asistencia, contadores,
 * justificaciones, cuelga de la inscripción, no de acá. Un recursante
 * tiene una inscripción nueva cada año, todas apuntando al mismo legajo,
 * sin duplicar a la persona.
 *
 * SoftDeletes: el legajo nunca se borra ni se duplica por eso el borrado
 * acá es siempre lógico. Igual que en `Usuario`, `uq_alumnos_dni` no
 * incluye `deleted_at`: reusar el DNI de un alumno borrado exige
 * restaurarlo (`withTrashed()`) en vez de dar de alta uno nuevo.
 */
class Alumno extends Model
{
    use SoftDeletes;

    protected $table = 'alumnos';

    protected $primaryKey = 'id_alumno';

    protected $fillable = [
        'nombre',
        'apellido',
        'dni',
        'fecha_nacimiento',
        'fecha_ingreso_institucion',
    ];

    protected function casts(): array
    {
        return [
            'fecha_nacimiento' => 'date',
            'fecha_ingreso_institucion' => 'date',
            'deleted_at' => 'datetime',
        ];
    }

    /**
     * Historial completo de inscripciones del alumno (una por ciclo
     * lectivo — `uq_inscripciones_alumno_ciclo`). Para "la inscripción
     * vigente" hay que filtrar por el ciclo lectivo abierto, no asumir
     * la última fila.
     */
    public function inscripciones(): HasMany
    {
        return $this->hasMany(Inscripcion::class, 'alumno_id', 'id_alumno');
    }
}

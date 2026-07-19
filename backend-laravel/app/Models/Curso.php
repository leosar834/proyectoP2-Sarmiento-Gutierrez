<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Curso principal (tabla `cursos`) = nivel + división + ciclo lectivo +
 * turno (ej. "3° 1a", turno mañana, ciclo 2026). Es la unidad que agrupa
 * a los alumnos para las clases teóricas; los talleres y educación
 * física tienen su propio agrupamiento (`GrupoTaller` / `GrupoEdFisica`),
 * independiente de este curso.
 *
 * Puede tener más de un preceptor asignado (`usuarios_cursos`) — la
 * narrativa lo permite explícitamente ("Asignar uno o más preceptores
 * responsables a cada curso y división").
 */
class Curso extends Model
{
    use SoftDeletes;

    protected $table = 'cursos';

    protected $primaryKey = 'id_curso';

    protected $fillable = [
        'nivel_id',
        'division_id',
        'ciclo_lectivo_id',
        'turno',
    ];

    protected function casts(): array
    {
        return [
            'deleted_at' => 'datetime',
        ];
    }

    public function nivel(): BelongsTo
    {
        return $this->belongsTo(Nivel::class, 'nivel_id', 'id_nivel');
    }

    public function division(): BelongsTo
    {
        return $this->belongsTo(Division::class, 'division_id', 'id_division');
    }

    public function cicloLectivo(): BelongsTo
    {
        return $this->belongsTo(CicloLectivo::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }

    /**
     * Preceptores asignados a este curso (tabla puente `usuarios_cursos`,
     * sin columnas propias más allá de las dos FK).
     */
    public function preceptores(): BelongsToMany
    {
        return $this->belongsToMany(
            Usuario::class,
            'usuarios_cursos',
            'curso_id',
            'usuario_id',
            'id_curso',
            'id_usuario'
        );
    }

    /**
     * Inscripciones activas o históricas a este curso. Ojo: esto NO es
     * "la lista de alumnos del curso" directamente — para eso hay que
     * cruzar con `estado` (ver Inscripcion::alumno()), porque una
     * inscripción puede estar de baja o pendiente de asignación.
     */
    public function inscripciones(): HasMany
    {
        return $this->hasMany(Inscripcion::class, 'curso_id', 'id_curso');
    }
}

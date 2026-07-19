<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Grupo de taller dentro de un ciclo lectivo (tabla `grupos_taller`):
 * una `MateriaTaller` puede tener más de un grupo por ciclo (ej. "Grupo
 * 1" y "Grupo 2" del mismo taller). Se clona vacío ciclo a ciclo - lo
 * hace el futuro proceso de apertura de ciclo, no una regla automática
 * de esta tabla.
 *
 * El alumno se agrupa acá vía su `Inscripcion`, no directamente - ver
 * la nota en `Inscripcion::gruposTaller()`.
 */
class GrupoTaller extends Model
{
    use SoftDeletes;

    protected $table = 'grupos_taller';

    protected $primaryKey = 'id_grupo_taller';

    protected $fillable = [
        'materia_taller_id',
        'nivel_id',
        'ciclo_lectivo_id',
        'nombre_grupo',
    ];

    protected function casts(): array
    {
        return [
            'deleted_at' => 'datetime',
        ];
    }

    public function materiaTaller(): BelongsTo
    {
        return $this->belongsTo(MateriaTaller::class, 'materia_taller_id', 'id_materia_taller');
    }

    public function nivel(): BelongsTo
    {
        return $this->belongsTo(Nivel::class, 'nivel_id', 'id_nivel');
    }

    public function cicloLectivo(): BelongsTo
    {
        return $this->belongsTo(CicloLectivo::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }

    /**
     * Profesores y preceptor de taller del grupo, distinguidos por
     * `rol_en_grupo` (`profesor` o `preceptor_taller`). Puede haber más
     * de un profesor por grupo — narrativa, RF1.
     */
    public function usuarios(): BelongsToMany
    {
        return $this->belongsToMany(
            Usuario::class,
            'usuarios_grupos_taller',
            'grupo_taller_id',
            'usuario_id',
            'id_grupo_taller',
            'id_usuario'
        )->withPivot('rol_en_grupo');
    }

    public function profesores(): BelongsToMany
    {
        return $this->usuarios()->wherePivot('rol_en_grupo', 'profesor');
    }

    public function preceptorTaller(): BelongsToMany
    {
        return $this->usuarios()->wherePivot('rol_en_grupo', 'preceptor_taller');
    }

    /**
     * Inscripciones (alumnos) asignados a este grupo — tabla puente
     * `alumnos_grupos_taller`, se repuebla cada ciclo, no se arrastra.
     */
    public function inscripciones(): BelongsToMany
    {
        return $this->belongsToMany(
            Inscripcion::class,
            'alumnos_grupos_taller',
            'grupo_taller_id',
            'inscripcion_id',
            'id_grupo_taller',
            'id_inscripcion'
        );
    }
}

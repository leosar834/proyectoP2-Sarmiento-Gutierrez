<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Grupo de educación física dentro de un ciclo lectivo (tabla
 * `grupos_ed_fisica`). A diferencia de taller, acá hay un solo profesor
 * por grupo.
 */
class GrupoEdFisica extends Model
{
    use SoftDeletes;

    protected $table = 'grupos_ed_fisica';

    protected $primaryKey = 'id_grupo_ed_fisica';

    protected $fillable = [
        'ciclo_lectivo_id',
        'nombre_grupo',
        'regimen_cursada',
        'profesor_id',
    ];

    protected function casts(): array
    {
        return [
            'deleted_at' => 'datetime',
        ];
    }

    public function cicloLectivo(): BelongsTo
    {
        return $this->belongsTo(CicloLectivo::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }

    public function profesor(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'profesor_id', 'id_usuario');
    }

    /**
     * Inscripciones (alumnos) asignados a este grupo — tabla puente
     * `alumnos_grupos_ed_fisica`, se repuebla cada ciclo.
     */
    public function inscripciones(): BelongsToMany
    {
        return $this->belongsToMany(
            Inscripcion::class,
            'alumnos_grupos_ed_fisica',
            'grupo_ed_fisica_id',
            'inscripcion_id',
            'id_grupo_ed_fisica',
            'id_inscripcion'
        );
    }
}

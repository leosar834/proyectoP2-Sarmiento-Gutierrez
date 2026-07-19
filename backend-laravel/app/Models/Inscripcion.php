<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

/**
 * Inscripción = alumno + curso + ciclo lectivo (tabla `inscripciones`).
 * Es el vínculo transaccional del que cuelga todo lo que pasa durante
 * el año (asistencia, contadores, justificaciones, resultados finales),
 * a diferencia del legajo (`Alumno`), que es permanente. Se genera y se
 * promociona una nueva cada ciclo.
 *
 * Sin SoftDeletes a propósito (a diferencia de `Alumno`): una
 * inscripción no se "elimina", se da de baja seteando
 * `estado = baja` + `fecha_baja` + `motivo_baja`, o queda archivada de
 * solo lectura cuando se cierra su ciclo lectivo. El legajo del alumno
 * se conserva siempre aunque la inscripción quede de baja.
 *
 * `especialidad_id` queda NULL hasta que el alumno llega al ciclo
 * superior (`Documentacion_Base_de_Datos.pdf`, sección 6.4); una vez
 * asignada queda memorizada en el legajo vía esta fila, y las
 * inscripciones siguientes de los años superiores heredan ese dato.
 * `condicion` distingue `regular` de `recursante`; `estado` incluye
 * `pendiente_asignacion` para cuando el curso de destino todavía no
 * existe (recién se resuelve en la fase de apertura de ciclo).
 */
class Inscripcion extends Model
{
    protected $table = 'inscripciones';

    protected $primaryKey = 'id_inscripcion';

    protected $fillable = [
        'alumno_id',
        'curso_id',
        'ciclo_lectivo_id',
        'especialidad_id',
        'condicion',
        'estado',
        'fecha_baja',
        'motivo_baja',
    ];

    protected function casts(): array
    {
        return [
            'fecha_baja' => 'date',
        ];
    }

    public function alumno(): BelongsTo
    {
        return $this->belongsTo(Alumno::class, 'alumno_id', 'id_alumno');
    }

    public function curso(): BelongsTo
    {
        return $this->belongsTo(Curso::class, 'curso_id', 'id_curso');
    }

    public function cicloLectivo(): BelongsTo
    {
        return $this->belongsTo(CicloLectivo::class, 'ciclo_lectivo_id', 'id_ciclo_lectivo');
    }

    public function especialidad(): BelongsTo
    {
        return $this->belongsTo(Especialidad::class, 'especialidad_id', 'id_especialidad');
    }

    /**
     * Grupo(s) de taller a los que quedó distribuido el alumno en este
     * ciclo (tabla puente `alumnos_grupos_taller`). El agrupamiento se
     * arma por inscripción, no por alumno directamente, precisamente
     * para que no se arrastre de un ciclo al siguiente.
     */
    public function gruposTaller(): BelongsToMany
    {
        return $this->belongsToMany(
            GrupoTaller::class,
            'alumnos_grupos_taller',
            'inscripcion_id',
            'grupo_taller_id',
            'id_inscripcion',
            'id_grupo_taller'
        );
    }

    public function gruposEdFisica(): BelongsToMany
    {
        return $this->belongsToMany(
            GrupoEdFisica::class,
            'alumnos_grupos_ed_fisica',
            'inscripcion_id',
            'grupo_ed_fisica_id',
            'id_inscripcion',
            'id_grupo_ed_fisica'
        );
    }
}

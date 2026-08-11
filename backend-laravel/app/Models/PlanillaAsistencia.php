<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Cabecera de asistencia (tabla `planillas_asistencia`): una fila por
 * curso/grupo + área + fecha. `area` determina cuál de las tres FK
 * (`curso_id` / `grupo_taller_id` / `grupo_ed_fisica_id`) va cargada —
 * las otras dos quedan NULL, reforzado por un CHECK en la base
 * (`chk_pa_una_sola_area`). Usar `grupo()` en vez de leer las columnas
 * directamente evita tener que repetir ese `switch` en cada lugar que
 * consulta una planilla.
 *
 * `estado` es `en_curso` o `bloqueada` — dos estados, no los cuatro que
 * en algún momento se planearon aquí (`en_curso -> enviada -> verificada
 * -> bloqueada`). Simplificación documentada a propósito (ver el
 * docblock de `AsistenciaController`, que es la fuente de verdad de
 * esta decisión): la narrativa describe para taller un paso de
 * "verificar" y otro de "enviar" antes del bloqueo (RF2), pero
 * `AsistenciaController::enviar()` lo modela como una sola transición
 * (`en_curso -> bloqueada`) porque lo que importa para el sistema es el
 * resultado — la planilla queda bloqueada y solo jefa de
 * preceptores/administrador puede corregirla después — no un tercer
 * estado intermedio persistido sin reglas propias. El bloqueo real lo
 * hace cumplir el trigger de MySQL
 * (`fn_planilla_bloqueada` + `trg_detalles_before_*`), no esta clase —
 * `estaBloqueada()` es solo el mismo chequeo del lado de PHP para poder
 * dar una respuesta clara antes de llegar a la base.
 */
class PlanillaAsistencia extends Model
{
    protected $table = 'planillas_asistencia';

    protected $primaryKey = 'id_planilla';

    protected $fillable = [
        'area',
        'curso_id',
        'grupo_taller_id',
        'grupo_ed_fisica_id',
        'fecha',
        'usuario_registro_id',
        'estado',
        'hora_confirmacion',
    ];

    protected function casts(): array
    {
        return [
            'fecha' => 'date',
            'hora_confirmacion' => 'datetime',
        ];
    }

    public function curso(): BelongsTo
    {
        return $this->belongsTo(Curso::class, 'curso_id', 'id_curso');
    }

    public function grupoTaller(): BelongsTo
    {
        return $this->belongsTo(GrupoTaller::class, 'grupo_taller_id', 'id_grupo_taller');
    }

    public function grupoEdFisica(): BelongsTo
    {
        return $this->belongsTo(GrupoEdFisica::class, 'grupo_ed_fisica_id', 'id_grupo_ed_fisica');
    }

    public function usuarioRegistro(): BelongsTo
    {
        return $this->belongsTo(Usuario::class, 'usuario_registro_id', 'id_usuario');
    }

    public function detalles(): HasMany
    {
        return $this->hasMany(DetalleAsistencia::class, 'planilla_id', 'id_planilla');
    }

    /**
     * El curso o grupo real de esta planilla, cualquiera sea el área —
     * evita repetir el chequeo de `area` en cada lugar que necesita
     * "a quién le corresponde esta planilla".
     */
    public function grupo(): Curso|GrupoTaller|GrupoEdFisica|null
    {
        return match ($this->area) {
            'teorica' => $this->curso,
            'taller' => $this->grupoTaller,
            'ed_fisica' => $this->grupoEdFisica,
            default => null,
        };
    }

    public function estaBloqueada(): bool
    {
        return $this->estado === 'bloqueada';
    }
}

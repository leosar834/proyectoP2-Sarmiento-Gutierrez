<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * División (tabla `divisiones`, ej. "1a", "2a"). Junto con `Nivel` y
 * `CicloLectivo` arma un `Curso` (nivel + división + ciclo = curso
 * principal, ej. "3° 1a" del ciclo 2026).
 */
class Division extends Model
{
    use SoftDeletes;

    protected $table = 'divisiones';

    protected $primaryKey = 'id_division';

    protected $fillable = [
        'nombre',
    ];

    protected function casts(): array
    {
        return [
            'deleted_at' => 'datetime',
        ];
    }

    public function cursos(): HasMany
    {
        return $this->hasMany(Curso::class, 'division_id', 'id_division');
    }
}

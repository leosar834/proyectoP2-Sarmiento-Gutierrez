<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;

/**
 * Catálogo FIJO de permisos del sistema (tabla `permisos`), no editable
 * por la institución. `plataforma` (movil/escritorio) es el techo de lo
 * que ese permiso puede llegar a habilitar, no una asignación — ver
 * narrativa, "Capa de Permisos (fija, definida por el sistema)".
 */
class Permiso extends Model
{
    protected $table = 'permisos';

    protected $primaryKey = 'id_permiso';

    protected $fillable = [
        'nombre',
        'plataforma',
        'descripcion',
    ];

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(
            Rol::class,
            'roles_permisos',
            'permiso_id',
            'rol_id',
            'id_permiso',
            'id_rol'
        );
    }
}

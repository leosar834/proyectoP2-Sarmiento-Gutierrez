<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Rol libre, definido por la institución (tabla `roles`). El nombre lo
 * elige la institución (preceptor, tutor, celador...); lo que puede hacer
 * cada rol surge exclusivamente de los permisos fijos que se le asignan
 * vía permisos().
 *
 * SoftDeletes (deleted_at): igual que en Usuario, `uq_roles_nombre` no
 * incluye deleted_at — reusar el nombre de un rol borrado exige
 * restaurarlo (withTrashed()) en vez de crear uno nuevo con el mismo
 * nombre.
 */
class Rol extends Model
{
    use SoftDeletes;

    protected $table = 'roles';

    protected $primaryKey = 'id_rol';

    protected $fillable = [
        'nombre',
        'descripcion',
        'activo',
    ];

    protected function casts(): array
    {
        return [
            'activo' => 'boolean',
            'deleted_at' => 'datetime',
        ];
    }

    public function permisos(): BelongsToMany
    {
        return $this->belongsToMany(
            Permiso::class,
            'roles_permisos',
            'rol_id',
            'permiso_id',
            'id_rol',
            'id_permiso'
        );
    }

    public function usuarios(): BelongsToMany
    {
        return $this->belongsToMany(
            Usuario::class,
            'usuarios_roles',
            'rol_id',
            'usuario_id',
            'id_rol',
            'id_usuario'
        );
    }
}

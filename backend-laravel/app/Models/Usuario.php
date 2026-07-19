<?php

namespace App\Models;

use Database\Factories\UsuarioFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/**
 * Usuario del sistema (tabla `usuarios`): quien opera el sistema
 * (preceptor, profesor, administrador...). No confundir con `alumnos` —
 * un alumno nunca inicia sesión, no tiene fila en esta tabla.
 *
 * El permiso efectivo de un usuario surge de cruzar
 * usuarios_roles -> roles_permisos -> permisos, filtrado por la plataforma
 * desde la que ingresó (movil/escritorio). Acá solo vive la relación de
 * datos (roles()); el filtro por plataforma y el corte "qué puede hacer
 * en esta request" es responsabilidad de policies/middleware — ver
 * App\Http\Middleware\VerificarPermiso.
 *
 * SoftDeletes (deleted_at): distinto de `activo`. `activo = false` es un
 * apagado reversible que bloquea el login sin tocar el historial;
 * eliminar (deleted_at) saca al usuario de los listados y, como Eloquent
 * agrega `WHERE deleted_at IS NULL` a toda consulta por default, también
 * corta cualquier token de Sanctum ya emitido (personal_access_tokens
 * queda con un tokenable() que no resuelve más). OJO: `uq_usuarios_email`
 * no incluye deleted_at, así que un email de un usuario borrado sigue
 * "ocupado" hasta restaurarlo o borrarlo físico — la capa de aplicación
 * tiene que chequear con withTrashed() antes de un alta nueva.
 */
class Usuario extends Authenticatable
{
    /** @use HasFactory<UsuarioFactory> */
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    protected $table = 'usuarios';

    protected $primaryKey = 'id_usuario';

    protected $fillable = [
        'nombre',
        'apellido',
        'email',
        'password',
        'activo',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'activo' => 'boolean',
            'deleted_at' => 'datetime',
        ];
    }

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(
            Rol::class,
            'usuarios_roles',
            'usuario_id',
            'rol_id',
            'id_usuario',
            'id_rol'
        );
    }

    /**
     * Cursos donde este usuario es preceptor asignado (tabla puente
     * `usuarios_cursos`). Puede tener más de uno.
     */
    public function cursos(): BelongsToMany
    {
        return $this->belongsToMany(
            Curso::class,
            'usuarios_cursos',
            'usuario_id',
            'curso_id',
            'id_usuario',
            'id_curso'
        );
    }

    /**
     * Grupos de taller donde participa, como profesor o como preceptor
     * de taller — `rol_en_grupo` en el pivot distingue cuál de los dos.
     * Ver GrupoTaller::profesores() / GrupoTaller::preceptorTaller()
     * para la relación inversa ya filtrada por rol.
     */
    public function gruposTaller(): BelongsToMany
    {
        return $this->belongsToMany(
            GrupoTaller::class,
            'usuarios_grupos_taller',
            'usuario_id',
            'grupo_taller_id',
            'id_usuario',
            'id_grupo_taller'
        )->withPivot('rol_en_grupo');
    }

    /**
     * Grupos de educación física donde este usuario es EL profesor
     * (FK directa `profesor_id` en `grupos_ed_fisica`, no una tabla
     * puente — a diferencia de taller, acá es un solo profesor por
     * grupo).
     */
    public function gruposEdFisicaComoProfesor(): HasMany
    {
        return $this->hasMany(GrupoEdFisica::class, 'profesor_id', 'id_usuario');
    }

    /**
     * Chequeo de conveniencia: ¿alguno de los roles del usuario tiene este
     * permiso? Sin filtro de plataforma todavía — eso se resuelve en la
     * capa de autorización (App\Http\Middleware\VerificarPermiso), que
     * sabe si la request vino de la app o de la web.
     */
    public function tienePermiso(string $nombrePermiso): bool
    {
        return $this->roles()
            ->whereHas('permisos', fn ($q) => $q->where('permisos.nombre', $nombrePermiso))
            ->exists();
    }
}
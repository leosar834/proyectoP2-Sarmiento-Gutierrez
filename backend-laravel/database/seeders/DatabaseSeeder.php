<?php

namespace Database\Seeders;

use App\Models\Permiso;
use App\Models\Rol;
use App\Models\Usuario;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $this->seedPermisos();
        $this->seedRolesEetn1();
        $this->seedUsuarioDePrueba();
    }

    /**
     * Catálogo FIJO de permisos (narrativa, "Capa de Permisos"). Es el
     * mismo en cualquier instalación del sistema, no lo edita la
     * institución — por eso se siembra siempre igual acá y no queda
     * editable desde la web.
     */
    private function seedPermisos(): void
    {
        $permisos = [
            ['nombre' => 'toma_asistencia', 'plataforma' => 'movil',
                'descripcion' => 'Tomar asistencia de los cursos/grupos asignados.'],
            ['nombre' => 'control_edicion_asistencia_jornada', 'plataforma' => 'movil',
                'descripcion' => 'Editar la asistencia del mismo día/jornada (tardanzas incluidas).'],
            ['nombre' => 'justificacion_inasistencias', 'plataforma' => 'movil',
                'descripcion' => 'Registrar justificaciones de inasistencia presentadas por padres/tutores.'],
            ['nombre' => 'consulta_planilla_propia', 'plataforma' => 'movil',
                'descripcion' => 'Consultar la planilla de los propios cursos/grupos, navegable por mes.'],
            ['nombre' => 'gestion_general_sistema', 'plataforma' => 'escritorio',
                'descripcion' => 'Alta, modificación y baja de usuarios, roles, cursos, grupos, alumnos, calendario y ciclo lectivo.'],
            ['nombre' => 'reportes_estadisticas', 'plataforma' => 'escritorio',
                'descripcion' => 'Acceso a reportes y estadísticas institucionales, incluidos los roles de solo lectura.'],
            ['nombre' => 'control_correccion_asistencia_historica', 'plataforma' => 'escritorio',
                'descripcion' => 'Corregir asistencia sin restricción de fecha.'],
        ];

        foreach ($permisos as $permiso) {
            Permiso::query()->firstOrCreate(['nombre' => $permiso['nombre']], $permiso);
        }
    }

    /**
     * Los 7 roles de la EETN.° 1 son la CONFIGURACIÓN INICIAL precargada de
     * esa institución, no una regla fija del sistema (narrativa, "Modelo de
     * Roles y Permisos Configurable"). Se crean los roles acá, pero
     * deliberadamente SIN asignarles permisos todavía: la matriz
     * rol -> permisos tiene un punto sin resolver (jefe_taller es un rol
     * de escritorio en la narrativa, pero RF5 también lo hace receptor de
     * justificaciones, que está catalogado como permiso exclusivo de
     * móvil) — conviene cerrarlo con Leo/Nico antes de sembrarlo mal.
     */
    private function seedRolesEetn1(): void
    {
        $roles = [
            'preceptor',
            'profesor_taller',
            'preceptor_taller',
            'profesor_ed_fisica',
            'jefa_preceptores_administrador',
            'jefe_taller',
            'director',
        ];

        foreach ($roles as $nombreRol) {
            Rol::query()->firstOrCreate(['nombre' => $nombreRol]);
        }
    }

    private function seedUsuarioDePrueba(): void
    {
        $admin = Usuario::query()->firstOrCreate(
            ['email' => 'admin@sistema-asistencia.test'],
            [
                'nombre' => 'Admin',
                'apellido' => 'Sistema',
                'password' => 'password',
            ]
        );

        $rolAdmin = Rol::where('nombre', 'jefa_preceptores_administrador')->value('id_rol');
        $admin->roles()->syncWithoutDetaching([$rolAdmin]);
    }
}

<?php

namespace Database\Seeders;

use App\Models\Permiso;
use App\Models\Rol;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

/**
 * Catálogo fijo de permisos + los 8 roles precargados de la EETN.° 1
 * (narrativa, "Capa de Permisos" y "Actores y Roles del Sistema") —
 * extraído de `DatabaseSeeder` para poder correrlo solo.
 *
 * Esto es configuración institucional, no datos de prueba: hace falta
 * que exista para que el sistema funcione en absoluto, incluido el alta
 * del primer administrador real vía `POST /registro-administrador`
 * (busca el rol `administrador_sistema` por nombre). A diferencia del
 * usuario de prueba que sigue sembrando `DatabaseSeeder`, esto SÍ
 * correspondería correrlo en una instalación real.
 *
 * Para probar el registro del primer administrador desde una base
 * completamente limpia (sin cursos, alumnos, usuarios, nada):
 *
 *   php artisan migrate:fresh
 *   php artisan db:seed --class=CatalogoSeeder
 */
class CatalogoSeeder extends Seeder
{
    use WithoutModelEvents;

    public function run(): void
    {
        $permisos = $this->seedPermisos();
        $this->seedRolesEETN1($permisos);
    }

    /**
     * Catálogo fijo (narrativa, "Capa de Permisos (fija, definida por el
     * sistema)"): 4 permisos exclusivos de móvil + 3 de escritorio. La
     * institución no los edita ni los renombra.
     */
    private function seedPermisos(): array
    {
        $catalogo = [
            // Móvil — operaciones de campo, frente al alumno.
            [
                'nombre' => 'tomar_asistencia',
                'plataforma' => 'movil',
                'descripcion' => 'Registrar el estado (presente/ausente/tardanza) de los alumnos de un curso o grupo asignado.',
            ],
            [
                'nombre' => 'editar_asistencia_del_dia',
                'plataforma' => 'movil',
                'descripcion' => 'Modificar una asistencia ya cargada mientras la jornada sigue en curso (tardanzas, correcciones del mismo día).',
            ],
            [
                'nombre' => 'justificar_inasistencias',
                'plataforma' => 'movil',
                'descripcion' => 'Registrar una justificación presentada por el padre/madre/tutor y notificar al área correspondiente.',
            ],
            [
                'nombre' => 'consultar_planilla_propia',
                'plataforma' => 'movil',
                'descripcion' => 'Ver la asistencia de los propios cursos/grupos asignados, de cualquier mes del ciclo lectivo en curso.',
            ],

            // Escritorio — gestión, consulta institucional y corrección histórica.
            [
                'nombre' => 'gestionar_sistema',
                'plataforma' => 'escritorio',
                'descripcion' => 'Alta, modificación y baja de usuarios, roles, cursos, grupos, alumnos, calendario escolar y ciclo lectivo.',
            ],
            [
                'nombre' => 'ver_reportes',
                'plataforma' => 'escritorio',
                'descripcion' => 'Reportes y estadísticas institucionales (semanal/mensual/trimestral, por alumno), incluidos los roles de solo lectura.',
            ],
            [
                'nombre' => 'corregir_asistencia_historica',
                'plataforma' => 'escritorio',
                'descripcion' => 'Corregir asistencia ya registrada, sin restricción de fecha.',
            ],
        ];

        return collect($catalogo)
            ->mapWithKeys(fn (array $datos) => [$datos['nombre'] => Permiso::create($datos)])
            ->all();
    }

    /**
     * Los 8 roles de la configuración inicial precargada para la EETN.° 1
     * (narrativa, "Actores y Roles del Sistema"). "jefa_preceptores" y
     * "administrador_sistema" son dos filas con la MISMA matriz de
     * permisos a propósito: la narrativa los define como equivalentes en
     * permisos, distintos solo en el nombre visible.
     *
     * jefe_taller combina un permiso de escritorio con uno de móvil: es
     * un rol de solo lectura por la web (ve_reportes del área de
     * talleres), pero la narrativa (RF5) también lo habilita como punto
     * de recepción de justificaciones en persona, junto con
     * preceptor_taller y profesor_taller — para notificar esa
     * justificación al sistema necesita el permiso móvil
     * justificar_inasistencias. La propia narrativa prevé este caso
     * ("Capa de Roles": un mismo rol puede combinar permisos de ambas
     * plataformas), así que no es una excepción al modelo, es el modelo
     * funcionando como está descripto.
     */
    private function seedRolesEETN1(array $permisos): array
    {
        $matriz = [
            // --- Roles operativos (móvil) ---
            'preceptor' => [
                'descripcion' => 'Toma asistencia de sus cursos, gestiona tardanzas del día y recibe justificaciones de padres/tutores.',
                'permisos' => ['tomar_asistencia', 'editar_asistencia_del_dia', 'justificar_inasistencias', 'consultar_planilla_propia'],
            ],
            'profesor_taller' => [
                'descripcion' => 'Toma asistencia de sus grupos de taller asignados.',
                'permisos' => ['tomar_asistencia', 'editar_asistencia_del_dia', 'consultar_planilla_propia'],
            ],
            'preceptor_taller' => [
                'descripcion' => 'Consolida, verifica y envía la asistencia de taller a preceptoría principal; recibe justificaciones en el área de taller.',
                'permisos' => ['tomar_asistencia', 'editar_asistencia_del_dia', 'justificar_inasistencias', 'consultar_planilla_propia'],
            ],
            'profesor_ed_fisica' => [
                'descripcion' => 'Toma asistencia de sus grupos de educación física asignados.',
                'permisos' => ['tomar_asistencia', 'editar_asistencia_del_dia', 'consultar_planilla_propia'],
            ],

            // --- Roles administrativos (escritorio) ---
            'jefa_preceptores' => [
                'descripcion' => 'Acceso total: gestión del sistema, reportes y corrección histórica de asistencia. Equivalente a administrador_sistema.',
                'permisos' => ['gestionar_sistema', 'ver_reportes', 'corregir_asistencia_historica'],
            ],
            'administrador_sistema' => [
                'descripcion' => 'Acceso total: gestión del sistema, reportes y corrección histórica de asistencia. Equivalente a jefa_preceptores.',
                'permisos' => ['gestionar_sistema', 'ver_reportes', 'corregir_asistencia_historica'],
            ],
            'jefe_taller' => [
                'descripcion' => 'Solo lectura de la asistencia del área de talleres (reportes de escritorio). Recibe justificaciones en persona en el área de taller y las notifica al sistema desde el móvil.',
                'permisos' => ['ver_reportes', 'justificar_inasistencias'],
            ],
            'director' => [
                'descripcion' => 'Solo lectura de reportes y estadísticas institucionales.',
                'permisos' => ['ver_reportes'],
            ],
        ];

        $roles = [];

        foreach ($matriz as $nombre => $datos) {
            $rol = Rol::create([
                'nombre' => $nombre,
                'descripcion' => $datos['descripcion'],
                'activo' => true,
            ]);

            $rol->permisos()->attach(
                collect($datos['permisos'])->map(fn (string $p) => $permisos[$p]->id_permiso)
            );

            $roles[$nombre] = $rol;
        }

        return $roles;
    }
}

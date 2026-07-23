<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Tablas del script en orden de dependencia inversa (para poder hacer
     * DROP en down() sin pisar FKs). Los 8 triggers y la función/procedimiento
     * se van solos al hacer DROP TABLE / DROP FUNCTION / DROP PROCEDURE, así
     * que no hace falta listarlos aparte.
     */
    private array $vistas = [
        'vista_alumnos_contadores',
        'vista_permisos_diarios_vigentes',
    ];

    private array $tablas = [
        'desenlaces',
        'resultados_finales',
        'alertas',
        'justificaciones',
        'contadores_asistencia',
        'detalles_asistencia',
        'planillas_asistencia',
        'permisos_diarios',
        'dias_sin_clases',
        'alumnos_grupos_ed_fisica',
        'alumnos_grupos_taller',
        'inscripciones',
        'alumnos',
        'grupos_ed_fisica',
        'usuarios_grupos_taller',
        'grupos_taller',
        'materias_taller',
        'usuarios_cursos',
        'cursos',
        'especialidades',
        'divisiones',
        'niveles',
        'configuraciones',
        'ciclos_lectivos',
        'usuarios_roles',
        'usuarios',
        'roles_permisos',
        'roles',
        'permisos',
    ];

    /**
     * Run the migrations.
     *
     * Carga tal cual el script probado end-to-end (database/sql/schema.sql)
     * en vez de reescribir 29 tablas + 41 FKs + 8 triggers con el Schema
     * builder de Laravel: reimplementar esa lógica a mano es la forma más
     * fácil de introducir un bug que el script original ya no tiene.
     *
     * database/sql/schema.sql se mantiene en el formato "de siempre" — el
     * mismo que se puede correr a mano con
     * `mysql -u root -p --default-character-set=utf8mb4 < schema.sql`
     * (Documentacion_Base_de_Datos.pdf, sección 11) — así que quien edite
     * el script no tiene que acordarse de generar una segunda copia
     * "para Laravel". La única transformación que necesita para poder
     * viajar en un solo DB::unprepared() la hace prepararScript() acá
     * abajo, en el momento:
     *   - saca el CREATE DATABASE / USE (Laravel ya está conectado a la
     *     base configurada en .env)
     *   - saca las líneas DELIMITER $$ / DELIMITER ; (un recurso del
     *     cliente `mysql` de línea de comandos para que sepa dónde termina
     *     una sentencia con ";" adentro — un trigger, una función — que el
     *     servidor nunca necesitó) y cada END$$ pasa a ser END;, su
     *     verdadero terminador de sentencia.
     * Ver Documentacion_Base_de_Datos.pdf, sección 10 ("Correr el script
     * desde una migración de Laravel").
     */
    public function up(): void
    {
        DB::unprepared($this->prepararScript());
    }

    private function prepararScript(): string
    {
        $sql = file_get_contents(database_path('sql/schema.sql'));

        $sql = preg_replace('/CREATE DATABASE IF NOT EXISTS.*?;\s*/is', '', $sql, 1);
        $sql = preg_replace('/^USE\s+\w+\s*;\s*$/mi', '', $sql);
        $sql = preg_replace('/^[ \t]*DELIMITER[ \t]+(\$\$|;)[ \t]*$/mi', '', $sql);
        $sql = str_replace('END$$', 'END;', $sql);

        return $sql;
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        foreach ($this->vistas as $vista) {
            DB::unprepared("DROP VIEW IF EXISTS {$vista}");
        }

        DB::unprepared('DROP PROCEDURE IF EXISTS sp_cerrar_ciclo');
        DB::unprepared('DROP PROCEDURE IF EXISTS sp_recalcular_contador');
        DB::unprepared('DROP FUNCTION IF EXISTS fn_planilla_bloqueada');

        DB::unprepared('SET FOREIGN_KEY_CHECKS = 0');
        foreach ($this->tablas as $tabla) {
            DB::unprepared("DROP TABLE IF EXISTS {$tabla}");
        }
        DB::unprepared('SET FOREIGN_KEY_CHECKS = 1');
    }
};

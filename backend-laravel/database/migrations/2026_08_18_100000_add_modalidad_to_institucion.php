<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Agrega `modalidad` a `institucion` — declara si el establecimiento es
 * una escuela técnico-profesional con talleres en contraturno o una
 * secundaria común con orientaciones (sin talleres). No es un dato de
 * identificación como nombre/domicilio/CUE: es un parámetro que la app
 * usa para simplificar el menú — ver `PanelEscritorioScreen` en
 * app_flutter, que oculta "Materias de Taller" y "Grupos de Taller"
 * cuando la modalidad es `secundaria_comun_orientaciones`.
 *
 * Deliberadamente NO bloquea nada del lado del backend: una institución
 * "secundaria común" que igual crea materias/grupos de taller a mano
 * (llamando a la API directamente, o porque cambió de modalidad más
 * adelante) sigue pudiendo hacerlo — la columna es una preferencia de
 * presentación, no una regla de negocio dura. El catálogo de
 * `especialidades` (orientaciones) sigue disponible para ambas
 * modalidades por igual: una secundaria común lo usa para sus
 * orientaciones (ver `DistribucionEspecialidadesController`), una
 * técnico-profesional además lo usa como base de `materias_taller`.
 *
 * `DEFAULT 'tecnico_profesional_contraturno'`: preserva el
 * comportamiento actual (Materias de Taller/Grupos de Taller ya
 * construidos y visibles) para cualquier instalación existente que
 * corra esta migración sin haber elegido todavía — el administrador
 * puede cambiarla en cualquier momento desde "Institución".
 *
 * Migración incremental aparte + chequeo de `information_schema` antes
 * del `ALTER`, mismo patrón (y mismo motivo) que
 * 2026_08_11_100000_add_motivo_to_ausencias_docentes.php: `migrate` no
 * vuelve a ejecutar una migración ya aplicada, y una instalación nueva
 * desde cero ya trae la columna a través de schema.sql (actualizado
 * igual, sección 16), así que sin este guard un `migrate:fresh` chocaría
 * con "Duplicate column name 'modalidad'".
 */
return new class extends Migration
{
    public function up(): void
    {
        $yaExiste = DB::selectOne(<<<'SQL'
            SELECT COUNT(*) AS total
              FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME = 'institucion'
               AND COLUMN_NAME = 'modalidad'
        SQL);

        if ($yaExiste->total > 0) {
            return;
        }

        DB::unprepared(<<<'SQL'
            ALTER TABLE institucion
                ADD COLUMN modalidad ENUM('tecnico_profesional_contraturno', 'secundaria_comun_orientaciones')
                    NOT NULL DEFAULT 'tecnico_profesional_contraturno'
                    COMMENT 'Determina si la app muestra Materias de Taller/Grupos de Taller.'
                    AFTER provincia
        SQL);
    }

    public function down(): void
    {
        DB::unprepared('ALTER TABLE institucion DROP COLUMN modalidad');
    }
};

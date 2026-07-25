<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Crea `ausencias_docentes` (ver database/sql/schema.sql, sección 15)
 * contra una base que ya corrió la migración grande
 * (2026_07_17_100000_..., que carga schema.sql completo). Se agrega
 * acá como migración aparte, en vez de solo editar schema.sql, por el
 * mismo motivo que 2026_07_22_120000_add_sp_cerrar_ciclo.php: `migrate`
 * no vuelve a ejecutar una migración ya aplicada — quien ya tenía la
 * base migrada necesita este paso incremental para tener la tabla
 * nueva sin correr `migrate:fresh` (destructivo). schema.sql se
 * actualiza igual, para que una instalación nueva desde cero la tenga
 * desde la migración grande directamente.
 *
 * Funcionalidad pedida explícitamente por la cátedra (auto-reporte de
 * ausencia del profesor de taller/ed. física), fuera de la narrativa
 * original — ver el docblock de App\Models\AusenciaDocente para el
 * detalle completo del diseño.
 *
 * `CREATE TABLE IF NOT EXISTS` en vez de `DROP` + `CREATE` (a diferencia
 * de sp_cerrar_ciclo, que es un procedimiento sin datos): acá sí hay
 * filas reales que perder si esta migración se reaplicara a mano por
 * error, así que el patrón "segura de reaplicar" tiene que ser
 * no-destructivo.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
            CREATE TABLE IF NOT EXISTS ausencias_docentes (
                id_ausencia_docente  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
                usuario_id           INT UNSIGNED NOT NULL COMMENT 'Profesor que notifica su propia ausencia.',
                area                 ENUM('taller','ed_fisica') NOT NULL,
                grupo_taller_id      INT UNSIGNED NULL COMMENT 'Solo si area = taller.',
                grupo_ed_fisica_id   INT UNSIGNED NULL COMMENT 'Solo si area = ed_fisica.',
                fecha                DATE NOT NULL,
                created_at           DATETIME NULL,
                updated_at           DATETIME NULL,
                KEY idx_ad_usuario (usuario_id),
                KEY idx_ad_grupo_taller_fecha (grupo_taller_id, fecha),
                KEY idx_ad_grupo_ef_fecha (grupo_ed_fisica_id, fecha),
                UNIQUE KEY uq_ad_taller_fecha (grupo_taller_id, fecha),
                UNIQUE KEY uq_ad_ef_fecha (grupo_ed_fisica_id, fecha),
                CONSTRAINT fk_ad_usuario FOREIGN KEY (usuario_id)         REFERENCES usuarios(id_usuario),
                CONSTRAINT fk_ad_gtaller FOREIGN KEY (grupo_taller_id)    REFERENCES grupos_taller(id_grupo_taller),
                CONSTRAINT fk_ad_gef     FOREIGN KEY (grupo_ed_fisica_id) REFERENCES grupos_ed_fisica(id_grupo_ed_fisica),
                CONSTRAINT chk_ad_una_sola_area CHECK (
                    (area = 'taller'    AND grupo_taller_id    IS NOT NULL AND grupo_ed_fisica_id IS NULL) OR
                    (area = 'ed_fisica' AND grupo_ed_fisica_id IS NOT NULL AND grupo_taller_id    IS NULL)
                )
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        SQL);
    }

    public function down(): void
    {
        DB::unprepared('DROP TABLE IF EXISTS ausencias_docentes');
    }
};

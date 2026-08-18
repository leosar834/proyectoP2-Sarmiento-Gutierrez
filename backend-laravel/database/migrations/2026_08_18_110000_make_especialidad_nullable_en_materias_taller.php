<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Vuelve `especialidad_id` NULLABLE en `materias_taller` — las escuelas
 * técnico-profesionales recién asignan la orientación a partir de 3°/4°
 * año (ver el docblock de `App\Models\Institucion` sobre `modalidad`),
 * así que las materias de ciclo básico (1°/2° año) necesitan poder
 * cargarse sin especialidad. Antes de esto la columna era `NOT NULL` y
 * tanto `CrearMateriaTallerRequest` como `ActualizarMateriaTallerRequest`
 * la exigían con `required` — ambas reglas pasan a `nullable` en el
 * mismo cambio (ver esos dos archivos).
 *
 * No hace falta tocar la foreign key `fk_mt_especialidad`: MySQL/MariaDB
 * permite valores NULL en una columna con FK sin redefinir la
 * constraint, siempre que la columna en sí sea nullable.
 *
 * Migración incremental aparte + chequeo de `information_schema` antes
 * del `ALTER`, mismo patrón (y mismo motivo) que
 * 2026_08_11_100000_add_motivo_to_ausencias_docentes.php: `migrate` no
 * vuelve a ejecutar una migración ya aplicada, así que quien ya tenía la
 * tabla creada necesita este paso para relajar la columna sin
 * `migrate:fresh`. schema.sql se actualiza en paralelo (sección de
 * `materias_taller`), para que una instalación nueva desde cero la tenga
 * NULL desde la migración grande directamente — sin el chequeo acá, un
 * `migrate:fresh` en una instalación nueva volvería a ejecutar este
 * `ALTER` sobre una columna que ya es NULL, lo cual no rompe nada pero
 * es trabajo de más; el guard lo evita.
 */
return new class extends Migration
{
    public function up(): void
    {
        $yaEsNullable = DB::selectOne(<<<'SQL'
            SELECT COUNT(*) AS total
              FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME = 'materias_taller'
               AND COLUMN_NAME = 'especialidad_id'
               AND IS_NULLABLE = 'YES'
        SQL);

        if ($yaEsNullable->total > 0) {
            return;
        }

        DB::unprepared(<<<'SQL'
            ALTER TABLE materias_taller
                MODIFY COLUMN especialidad_id INT UNSIGNED NULL
        SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
            ALTER TABLE materias_taller
                MODIFY COLUMN especialidad_id INT UNSIGNED NOT NULL
        SQL);
    }
};

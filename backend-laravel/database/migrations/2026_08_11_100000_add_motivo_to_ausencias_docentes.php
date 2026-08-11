<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Agrega `motivo` (texto libre, opcional) a `ausencias_docentes` — mismo
 * campo que ya tiene `dias_sin_clases` (sección 5 de schema.sql), para
 * que el profesor pueda explicar opcionalmente por qué hoy no
 * corresponde tomar asistencia (no siempre es una ausencia literal, ver
 * el docblock actualizado de App\Models\AusenciaDocente y
 * docs/limitaciones_conocidas/calendario_escolar_alcance_turno.md).
 *
 * Migración incremental aparte, mismo motivo que
 * 2026_07_25_100000_add_ausencias_docentes.php: `migrate` no vuelve a
 * ejecutar una migración ya aplicada, así que quien ya tenía la tabla
 * creada necesita este paso para sumar la columna sin `migrate:fresh`.
 * schema.sql se actualiza igual, para que una instalación nueva desde
 * cero la tenga desde la migración grande directamente.
 *
 * Chequeo de `information_schema` antes del `ALTER` — bug real
 * encontrado el 12/08/2026: en una instalación nueva, la migración
 * grande ya crea `ausencias_docentes` CON `motivo` (porque schema.sql
 * la incluye desde la sección 15), así que este `ADD COLUMN` sin guarda
 * chocaba con "Duplicate column name 'motivo'" en cualquier
 * `migrate:fresh`. No se usa `ADD COLUMN IF NOT EXISTS` (MySQL 8.0.29+)
 * para no depender de la versión exacta de MySQL instalada.
 */
return new class extends Migration
{
    public function up(): void
    {
        $yaExiste = DB::selectOne(<<<'SQL'
            SELECT COUNT(*) AS total
              FROM information_schema.COLUMNS
             WHERE TABLE_SCHEMA = DATABASE()
               AND TABLE_NAME = 'ausencias_docentes'
               AND COLUMN_NAME = 'motivo'
        SQL);

        if ($yaExiste->total > 0) {
            return;
        }

        DB::unprepared(<<<'SQL'
            ALTER TABLE ausencias_docentes
                ADD COLUMN motivo VARCHAR(100) NULL AFTER fecha
        SQL);
    }

    public function down(): void
    {
        DB::unprepared('ALTER TABLE ausencias_docentes DROP COLUMN motivo');
    }
};

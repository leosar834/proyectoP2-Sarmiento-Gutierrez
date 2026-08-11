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
 */
return new class extends Migration
{
    public function up(): void
    {
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

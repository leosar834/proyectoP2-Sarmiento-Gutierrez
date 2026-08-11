<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Crea `institucion` (ver database/sql/schema.sql, sección 16) contra
 * una base que ya corrió la migración grande (2026_07_17_100000_...,
 * que carga schema.sql completo). Se agrega acá como migración aparte,
 * en vez de solo editar schema.sql, por el mismo motivo que
 * 2026_07_25_100000_add_ausencias_docentes.php: `migrate` no vuelve a
 * ejecutar una migración ya aplicada — quien ya tenía la base migrada
 * necesita este paso incremental para tener la tabla nueva sin correr
 * `migrate:fresh` (destructivo). schema.sql se actualiza igual, para
 * que una instalación nueva desde cero la tenga desde la migración
 * grande directamente.
 *
 * Fila única con `DEFAULT 1` + `CHECK id_institucion = 1`, mismo patrón
 * que `configuraciones` (sección 2 de schema.sql) — a diferencia de esa
 * tabla, acá NO se inserta una fila por defecto: no hay un
 * nombre/domicilio/CUE razonable para inventar. La fila la crea
 * `RegistroAdministradorController::crear()`, junto con el alta del
 * primer administrador — ver el docblock de App\Models\Institucion.
 *
 * `CREATE TABLE IF NOT EXISTS`, mismo motivo que
 * 2026_07_25_100000_add_ausencias_docentes.php: no-destructivo si esta
 * migración se reaplicara a mano por error.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared(<<<'SQL'
            CREATE TABLE IF NOT EXISTS institucion (
                id_institucion  INT UNSIGNED PRIMARY KEY DEFAULT 1,
                nombre          VARCHAR(150) NOT NULL,
                domicilio       VARCHAR(200) NOT NULL,
                cue             VARCHAR(20) NOT NULL COMMENT 'Clave Única de Establecimiento.',
                localidad       VARCHAR(100) NOT NULL,
                provincia       VARCHAR(100) NOT NULL,
                created_at      DATETIME NULL,
                updated_at      DATETIME NULL,
                CONSTRAINT chk_institucion_fila_unica CHECK (id_institucion = 1)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        SQL);
    }

    public function down(): void
    {
        DB::unprepared('DROP TABLE IF EXISTS institucion');
    }
};

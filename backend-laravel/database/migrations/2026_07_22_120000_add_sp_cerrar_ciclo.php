<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Instala sp_cerrar_ciclo (Fase 1 del cierre de ciclo — ver
 * database/sql/schema.sql, sección 14) contra una base que ya corrió la
 * migración grande (2026_07_17_100000_..., que carga schema.sql
 * completo). Se agrega acá como migración aparte, en vez de solo
 * editar schema.sql, porque `migrate` no vuelve a ejecutar una
 * migración ya aplicada — quien ya tenía la base migrada necesita este
 * paso incremental para tener el procedimiento nuevo sin correr
 * `migrate:fresh` (destructivo). schema.sql se actualiza igual, para
 * que una instalación nueva desde cero lo tenga desde la migración
 * grande directamente.
 *
 * `DROP PROCEDURE IF EXISTS` antes del `CREATE` a propósito: hace que
 * esta migración sea segura de re-aplicar a mano si hiciera falta
 * (ej. tras un `migrate:fresh` que ya lo haya creado desde el
 * schema.sql actualizado).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::unprepared('DROP PROCEDURE IF EXISTS sp_cerrar_ciclo');

        DB::unprepared(<<<'SQL'
            CREATE PROCEDURE sp_cerrar_ciclo(IN p_ciclo_lectivo_id INT UNSIGNED)
            BEGIN
                DECLARE v_umbral_pct       DECIMAL(5,2);
                DECLARE v_done             INT DEFAULT FALSE;
                DECLARE v_inscripcion_id   INT UNSIGNED;
                DECLARE v_faltas_general   DECIMAL(6,2);
                DECLARE v_total_clases     INT;
                DECLARE v_pct              DECIMAL(5,2);
                DECLARE v_condicion        VARCHAR(10);

                DECLARE cur CURSOR FOR
                    SELECT i.id_inscripcion
                      FROM inscripciones i
                     WHERE i.ciclo_lectivo_id = p_ciclo_lectivo_id
                       AND i.estado = 'activo';
                DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

                SELECT umbral_alerta_pct INTO v_umbral_pct
                  FROM configuraciones WHERE id_configuracion = 1;

                OPEN cur;
                leer_inscripciones: LOOP
                    FETCH cur INTO v_inscripcion_id;
                    IF v_done THEN
                        LEAVE leer_inscripciones;
                    END IF;

                    IF NOT EXISTS (
                        SELECT 1 FROM resultados_finales WHERE inscripcion_id = v_inscripcion_id
                    ) THEN
                        SELECT COUNT(*) INTO v_total_clases
                          FROM detalles_asistencia d
                          JOIN planillas_asistencia p ON p.id_planilla = d.planilla_id
                         WHERE d.inscripcion_id = v_inscripcion_id;

                        SELECT COALESCE(faltas_general, 0) INTO v_faltas_general
                          FROM contadores_asistencia
                         WHERE inscripcion_id = v_inscripcion_id;

                        IF v_total_clases > 0 THEN
                            SET v_pct = (v_faltas_general / v_total_clases) * 100;
                        ELSE
                            SET v_pct = 0;
                        END IF;

                        SET v_condicion = IF(v_pct >= v_umbral_pct, 'libre', 'regular');

                        INSERT INTO resultados_finales
                            (inscripcion_id, porcentaje_inasistencia, condicion_final, fecha_cierre)
                        VALUES
                            (v_inscripcion_id, v_pct, v_condicion, NOW());

                        IF v_total_clases > 0 AND v_faltas_general = 0 AND NOT EXISTS (
                            SELECT 1 FROM alertas
                             WHERE inscripcion_id = v_inscripcion_id
                               AND tipo = 'asistencia_perfecta' AND estado = 'activa'
                        ) THEN
                            INSERT INTO alertas (inscripcion_id, tipo, fecha_generacion, detalle, estado)
                            VALUES (v_inscripcion_id, 'asistencia_perfecta', NOW(),
                                    'Asistencia perfecta en el ciclo lectivo.', 'activa');
                        END IF;
                    END IF;
                END LOOP;
                CLOSE cur;

                UPDATE ciclos_lectivos
                   SET estado = 'cerrado', fecha_cierre = NOW()
                 WHERE id_ciclo_lectivo = p_ciclo_lectivo_id
                   AND estado = 'abierto';
            END
        SQL);
    }

    public function down(): void
    {
        DB::unprepared('DROP PROCEDURE IF EXISTS sp_cerrar_ciclo');
    }
};

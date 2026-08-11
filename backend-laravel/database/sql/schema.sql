-- =====================================================================
-- SISTEMA DE GESTIÓN DE ASISTENCIA PARA ALUMNOS
-- Escuela de Educación Técnica N.° 1 Cnel. Manuel Álvarez Prado
-- Motor: MySQL 8.0+  |  Backend: Laravel  |  App móvil: Flutter
--
-- Convenciones: tablas en plural | PK = id_<entidad> | FK = <entidad>_id
-- Documentación completa: ver "Documentacion_Base_de_Datos.pdf"
-- =====================================================================



SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;


-- =====================================================================
-- 1. SEGURIDAD: PERMISOS, ROLES Y USUARIOS
-- =====================================================================

-- Catálogo fijo de permisos del sistema (no editable por la institución).
CREATE TABLE permisos (
    id_permiso      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    plataforma      ENUM('movil','escritorio') NOT NULL,
    descripcion     VARCHAR(255) NULL,
    created_at      DATETIME NULL,
    updated_at      DATETIME NULL,
    UNIQUE KEY uq_permisos_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Roles libres, definidos por la institución.
CREATE TABLE roles (
    id_rol          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     VARCHAR(255) NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      DATETIME NULL,
    updated_at      DATETIME NULL,
    UNIQUE KEY uq_roles_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE roles_permisos (
    rol_id          INT UNSIGNED NOT NULL,
    permiso_id      INT UNSIGNED NOT NULL,
    PRIMARY KEY (rol_id, permiso_id),
    KEY idx_roles_permisos_permiso (permiso_id),
    CONSTRAINT fk_rp_rol     FOREIGN KEY (rol_id)     REFERENCES roles(id_rol)        ON DELETE CASCADE,
    CONSTRAINT fk_rp_permiso FOREIGN KEY (permiso_id) REFERENCES permisos(id_permiso) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usuarios (
    id_usuario      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    apellido        VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL,
    password        VARCHAR(255) NOT NULL COMMENT 'Hash de Laravel (bcrypt/argon2).',
    remember_token  VARCHAR(100) NULL,
    activo          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      DATETIME NULL,
    updated_at      DATETIME NULL,
    UNIQUE KEY uq_usuarios_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usuarios_roles (
    usuario_id      INT UNSIGNED NOT NULL,
    rol_id          INT UNSIGNED NOT NULL,
    PRIMARY KEY (usuario_id, rol_id),
    KEY idx_usuarios_roles_rol (rol_id),
    CONSTRAINT fk_ur_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_ur_rol     FOREIGN KEY (rol_id)     REFERENCES roles(id_rol)        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- 2. CICLO LECTIVO Y CONFIGURACIÓN GENERAL
-- =====================================================================

CREATE TABLE ciclos_lectivos (
    id_ciclo_lectivo INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    anio             SMALLINT UNSIGNED NOT NULL,
    fecha_inicio     DATE NOT NULL,
    fecha_fin        DATE NULL,
    estado           ENUM('abierto','cerrado') NOT NULL DEFAULT 'abierto',
    fecha_cierre     DATETIME NULL,
    created_at       DATETIME NULL,
    updated_at       DATETIME NULL,
    UNIQUE KEY uq_ciclos_lectivos_anio (anio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Fila única (CHECK obliga id_configuracion = 1): parámetros editables por
-- la institución sin tocar el script.
CREATE TABLE configuraciones (
    id_configuracion          INT UNSIGNED PRIMARY KEY DEFAULT 1,
    valor_falta                DECIMAL(4,2)  NOT NULL DEFAULT 0.50,
    tardanzas_por_falta        SMALLINT UNSIGNED NOT NULL DEFAULT 4,
    umbral_alerta_pct          DECIMAL(5,2)  NOT NULL DEFAULT 20.00,
    umbral_seguimiento_faltas  SMALLINT UNSIGNED NOT NULL DEFAULT 3,
    clases_minimas_alerta      SMALLINT UNSIGNED NOT NULL DEFAULT 20,
    updated_at                 DATETIME NULL,
    CONSTRAINT chk_configuraciones_fila_unica CHECK (id_configuracion = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO configuraciones (id_configuracion, valor_falta, tardanzas_por_falta, umbral_alerta_pct, umbral_seguimiento_faltas, clases_minimas_alerta)
VALUES (1, 0.50, 4, 20.00, 3, 20);


-- =====================================================================
-- 3. ESTRUCTURA ACADÉMICA CONFIGURABLE
-- =====================================================================

CREATE TABLE niveles (
    id_nivel        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(50) NOT NULL COMMENT 'Etiqueta visible (ej. "1er año").',
    numero_orden    SMALLINT UNSIGNED NOT NULL COMMENT 'Orden interno usado para promocionar N -> N+1.',
    created_at      DATETIME NULL,
    updated_at      DATETIME NULL,
    UNIQUE KEY uq_niveles_orden (numero_orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE divisiones (
    id_division     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(20) NOT NULL,
    created_at      DATETIME NULL,
    updated_at      DATETIME NULL,
    UNIQUE KEY uq_divisiones_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE especialidades (
    id_especialidad INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    created_at      DATETIME NULL,
    updated_at      DATETIME NULL,
    UNIQUE KEY uq_especialidades_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE cursos (
    id_curso         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nivel_id         INT UNSIGNED NOT NULL,
    division_id      INT UNSIGNED NOT NULL,
    ciclo_lectivo_id INT UNSIGNED NOT NULL,
    turno            ENUM('mañana','tarde','noche') NOT NULL,
    created_at       DATETIME NULL,
    updated_at       DATETIME NULL,
    UNIQUE KEY uq_cursos_nivel_division_ciclo (nivel_id, division_id, ciclo_lectivo_id),
    KEY idx_cursos_division (division_id),
    KEY idx_cursos_ciclo (ciclo_lectivo_id),
    CONSTRAINT fk_cursos_nivel  FOREIGN KEY (nivel_id)         REFERENCES niveles(id_nivel),
    CONSTRAINT fk_cursos_div    FOREIGN KEY (division_id)      REFERENCES divisiones(id_division),
    CONSTRAINT fk_cursos_ciclo  FOREIGN KEY (ciclo_lectivo_id) REFERENCES ciclos_lectivos(id_ciclo_lectivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usuarios_cursos (
    usuario_id      INT UNSIGNED NOT NULL,
    curso_id        INT UNSIGNED NOT NULL,
    PRIMARY KEY (usuario_id, curso_id),
    KEY idx_usuarios_cursos_curso (curso_id),
    CONSTRAINT fk_uc_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_uc_curso   FOREIGN KEY (curso_id)   REFERENCES cursos(id_curso)     ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE materias_taller (
    id_materia_taller INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    especialidad_id    INT UNSIGNED NOT NULL,
    nombre             VARCHAR(100) NOT NULL,
    regimen_cursada    ENUM('anual','trimestral','semestral','personalizado') NOT NULL,
    created_at         DATETIME NULL,
    updated_at         DATETIME NULL,
    KEY idx_materias_taller_especialidad (especialidad_id),
    CONSTRAINT fk_mt_especialidad FOREIGN KEY (especialidad_id) REFERENCES especialidades(id_especialidad)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE grupos_taller (
    id_grupo_taller    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    materia_taller_id  INT UNSIGNED NOT NULL,
    nivel_id           INT UNSIGNED NOT NULL,
    ciclo_lectivo_id   INT UNSIGNED NOT NULL,
    nombre_grupo       VARCHAR(50) NOT NULL,
    created_at         DATETIME NULL,
    updated_at         DATETIME NULL,
    UNIQUE KEY uq_grupos_taller (materia_taller_id, nivel_id, ciclo_lectivo_id, nombre_grupo),
    KEY idx_grupos_taller_nivel (nivel_id),
    KEY idx_grupos_taller_ciclo (ciclo_lectivo_id),
    CONSTRAINT fk_gt_materia FOREIGN KEY (materia_taller_id) REFERENCES materias_taller(id_materia_taller),
    CONSTRAINT fk_gt_nivel   FOREIGN KEY (nivel_id)          REFERENCES niveles(id_nivel),
    CONSTRAINT fk_gt_ciclo   FOREIGN KEY (ciclo_lectivo_id)  REFERENCES ciclos_lectivos(id_ciclo_lectivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- rol_en_grupo distingue profesor de preceptor de taller (puede haber
-- más de un profesor por grupo).
CREATE TABLE usuarios_grupos_taller (
    usuario_id       INT UNSIGNED NOT NULL,
    grupo_taller_id  INT UNSIGNED NOT NULL,
    rol_en_grupo     ENUM('profesor','preceptor_taller') NOT NULL,
    PRIMARY KEY (usuario_id, grupo_taller_id, rol_en_grupo),
    KEY idx_ugt_grupo (grupo_taller_id),
    CONSTRAINT fk_ugt_usuario FOREIGN KEY (usuario_id)      REFERENCES usuarios(id_usuario)         ON DELETE CASCADE,
    CONSTRAINT fk_ugt_grupo   FOREIGN KEY (grupo_taller_id) REFERENCES grupos_taller(id_grupo_taller) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE grupos_ed_fisica (
    id_grupo_ed_fisica INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ciclo_lectivo_id    INT UNSIGNED NOT NULL,
    nombre_grupo        VARCHAR(50) NOT NULL,
    regimen_cursada     ENUM('anual','trimestral','semestral','personalizado') NOT NULL,
    profesor_id          INT UNSIGNED NOT NULL,
    created_at           DATETIME NULL,
    updated_at           DATETIME NULL,
    UNIQUE KEY uq_grupos_ed_fisica (ciclo_lectivo_id, nombre_grupo),
    KEY idx_gef_profesor (profesor_id),
    CONSTRAINT fk_gef_ciclo    FOREIGN KEY (ciclo_lectivo_id) REFERENCES ciclos_lectivos(id_ciclo_lectivo),
    CONSTRAINT fk_gef_profesor FOREIGN KEY (profesor_id)      REFERENCES usuarios(id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- 4. ALUMNOS E INSCRIPCIONES
-- =====================================================================

-- Legajo permanente. Nunca se borra ni se duplica entre ciclos.
CREATE TABLE alumnos (
    id_alumno                  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre                     VARCHAR(100) NOT NULL,
    apellido                   VARCHAR(100) NOT NULL,
    dni                        VARCHAR(20) NOT NULL,
    fecha_nacimiento           DATE NULL,
    fecha_ingreso_institucion  DATE NOT NULL,
    created_at                 DATETIME NULL,
    updated_at                 DATETIME NULL,
    UNIQUE KEY uq_alumnos_dni (dni)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Inscripción = alumno + curso + ciclo lectivo. Es lo que se promociona
-- cada año; el alumno (legajo) nunca se toca.
CREATE TABLE inscripciones (
    id_inscripcion    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    alumno_id         INT UNSIGNED NOT NULL,
    curso_id          INT UNSIGNED NOT NULL,
    ciclo_lectivo_id  INT UNSIGNED NOT NULL,
    especialidad_id   INT UNSIGNED NULL COMMENT 'NULL hasta el ciclo superior.',
    condicion         ENUM('regular','recursante') NOT NULL DEFAULT 'regular',
    estado            ENUM('activo','egresado','baja','pendiente_asignacion') NOT NULL DEFAULT 'activo',
    fecha_baja        DATE NULL,
    motivo_baja       VARCHAR(255) NULL,
    created_at        DATETIME NULL,
    updated_at        DATETIME NULL,
    UNIQUE KEY uq_inscripciones_alumno_ciclo (alumno_id, ciclo_lectivo_id),
    KEY idx_inscripciones_curso (curso_id),
    KEY idx_inscripciones_especialidad (especialidad_id),
    CONSTRAINT fk_insc_alumno       FOREIGN KEY (alumno_id)        REFERENCES alumnos(id_alumno),
    CONSTRAINT fk_insc_curso        FOREIGN KEY (curso_id)         REFERENCES cursos(id_curso),
    CONSTRAINT fk_insc_ciclo        FOREIGN KEY (ciclo_lectivo_id) REFERENCES ciclos_lectivos(id_ciclo_lectivo),
    CONSTRAINT fk_insc_especialidad FOREIGN KEY (especialidad_id)  REFERENCES especialidades(id_especialidad)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE alumnos_grupos_taller (
    inscripcion_id   INT UNSIGNED NOT NULL,
    grupo_taller_id  INT UNSIGNED NOT NULL,
    PRIMARY KEY (inscripcion_id, grupo_taller_id),
    KEY idx_agt_grupo (grupo_taller_id),
    CONSTRAINT fk_agt_inscripcion FOREIGN KEY (inscripcion_id)  REFERENCES inscripciones(id_inscripcion)  ON DELETE CASCADE,
    CONSTRAINT fk_agt_grupo       FOREIGN KEY (grupo_taller_id) REFERENCES grupos_taller(id_grupo_taller)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE alumnos_grupos_ed_fisica (
    inscripcion_id       INT UNSIGNED NOT NULL,
    grupo_ed_fisica_id   INT UNSIGNED NOT NULL,
    PRIMARY KEY (inscripcion_id, grupo_ed_fisica_id),
    KEY idx_agef_grupo (grupo_ed_fisica_id),
    CONSTRAINT fk_agef_inscripcion FOREIGN KEY (inscripcion_id)     REFERENCES inscripciones(id_inscripcion)      ON DELETE CASCADE,
    CONSTRAINT fk_agef_grupo       FOREIGN KEY (grupo_ed_fisica_id) REFERENCES grupos_ed_fisica(id_grupo_ed_fisica)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- 5. CALENDARIO Y PERMISO DIARIO DE TOMA DE ASISTENCIA
-- =====================================================================

CREATE TABLE dias_sin_clases (
    id_dia_sin_clase  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ciclo_lectivo_id  INT UNSIGNED NOT NULL,
    fecha             DATE NOT NULL,
    motivo            VARCHAR(100) NOT NULL,
    alcance           ENUM('todos','mañana','tarde','noche') NOT NULL DEFAULT 'todos',
    created_at        DATETIME NULL,
    updated_at        DATETIME NULL,
    UNIQUE KEY uq_dias_sin_clases (fecha, alcance),
    KEY idx_dias_sin_clases_ciclo (ciclo_lectivo_id),
    CONSTRAINT fk_dsc_ciclo FOREIGN KEY (ciclo_lectivo_id) REFERENCES ciclos_lectivos(id_ciclo_lectivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- El jefe de preceptores abre el día. El cierre se calcula solo (ver
-- vista_permisos_diarios_vigentes), comparando la hora actual contra
-- hora_limite; cerrado_manual permite un cierre anticipado explícito.
CREATE TABLE permisos_diarios (
    id_permiso_diario    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    fecha                DATE NOT NULL,
    usuario_apertura_id  INT UNSIGNED NOT NULL,
    hora_apertura        DATETIME NOT NULL,
    hora_limite          TIME NOT NULL DEFAULT '23:59:59',
    cerrado_manual       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at           DATETIME NULL,
    updated_at           DATETIME NULL,
    UNIQUE KEY uq_permisos_diarios_fecha (fecha),
    KEY idx_permisos_diarios_usuario (usuario_apertura_id),
    CONSTRAINT fk_pd_usuario FOREIGN KEY (usuario_apertura_id) REFERENCES usuarios(id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- 6. ASISTENCIA: CABECERA (PLANILLA) + DETALLE
-- =====================================================================

CREATE TABLE planillas_asistencia (
    id_planilla          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    area                 ENUM('teorica','taller','ed_fisica') NOT NULL,
    curso_id             INT UNSIGNED NULL COMMENT 'Solo si area = teorica.',
    grupo_taller_id      INT UNSIGNED NULL COMMENT 'Solo si area = taller.',
    grupo_ed_fisica_id   INT UNSIGNED NULL COMMENT 'Solo si area = ed_fisica.',
    fecha                DATE NOT NULL,
    usuario_registro_id  INT UNSIGNED NOT NULL,
    estado               ENUM('en_curso','enviada','verificada','bloqueada') NOT NULL DEFAULT 'en_curso',
    hora_confirmacion    DATETIME NULL,
    created_at           DATETIME NULL,
    updated_at           DATETIME NULL,
    KEY idx_planillas_curso_fecha (curso_id, fecha),
    KEY idx_planillas_grupo_taller_fecha (grupo_taller_id, fecha),
    KEY idx_planillas_grupo_ef_fecha (grupo_ed_fisica_id, fecha),
    KEY idx_planillas_usuario (usuario_registro_id),
    CONSTRAINT fk_pa_curso    FOREIGN KEY (curso_id)           REFERENCES cursos(id_curso),
    CONSTRAINT fk_pa_gtaller  FOREIGN KEY (grupo_taller_id)    REFERENCES grupos_taller(id_grupo_taller),
    CONSTRAINT fk_pa_gef      FOREIGN KEY (grupo_ed_fisica_id) REFERENCES grupos_ed_fisica(id_grupo_ed_fisica),
    CONSTRAINT fk_pa_usuario  FOREIGN KEY (usuario_registro_id) REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_pa_una_sola_area CHECK (
        (area = 'teorica'   AND curso_id           IS NOT NULL AND grupo_taller_id IS NULL AND grupo_ed_fisica_id IS NULL) OR
        (area = 'taller'    AND grupo_taller_id    IS NOT NULL AND curso_id        IS NULL AND grupo_ed_fisica_id IS NULL) OR
        (area = 'ed_fisica' AND grupo_ed_fisica_id IS NOT NULL AND curso_id        IS NULL AND grupo_taller_id    IS NULL)
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE detalles_asistencia (
    id_detalle       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    planilla_id      INT UNSIGNED NOT NULL,
    inscripcion_id   INT UNSIGNED NOT NULL,
    estado           ENUM('presente','ausente','tardanza','falta_justificada') NOT NULL,
    hora_registro    DATETIME NOT NULL,
    observaciones    VARCHAR(255) NULL,
    created_at       DATETIME NULL,
    updated_at       DATETIME NULL,
    UNIQUE KEY uq_detalles_planilla_inscripcion (planilla_id, inscripcion_id),
    KEY idx_detalles_inscripcion (inscripcion_id),
    CONSTRAINT fk_da_planilla    FOREIGN KEY (planilla_id)    REFERENCES planillas_asistencia(id_planilla) ON DELETE CASCADE,
    CONSTRAINT fk_da_inscripcion FOREIGN KEY (inscripcion_id) REFERENCES inscripciones(id_inscripcion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- 7. CONTADORES MATERIALIZADOS (mantenidos por trigger, ver sección 11)
-- =====================================================================

CREATE TABLE contadores_asistencia (
    id_contador           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    inscripcion_id        INT UNSIGNED NOT NULL,
    faltas_teoricas       DECIMAL(6,2) NOT NULL DEFAULT 0,
    faltas_taller         DECIMAL(6,2) NOT NULL DEFAULT 0,
    faltas_ed_fisica      DECIMAL(6,2) NOT NULL DEFAULT 0,
    faltas_general        DECIMAL(6,2) NOT NULL DEFAULT 0,
    tardanzas_global      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    justificaciones_total SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    fecha_actualizacion   DATETIME NOT NULL,
    UNIQUE KEY uq_contadores_inscripcion (inscripcion_id),
    CONSTRAINT fk_ca_inscripcion FOREIGN KEY (inscripcion_id) REFERENCES inscripciones(id_inscripcion) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- 8. JUSTIFICACIONES Y ALERTAS
-- =====================================================================

CREATE TABLE justificaciones (
    id_justificacion     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    inscripcion_id       INT UNSIGNED NOT NULL,
    fecha_inicio         DATE NOT NULL,
    fecha_fin            DATE NOT NULL,
    tipo                 ENUM('certificado_medico','nota_tutor') NOT NULL,
    fecha_presentacion   DATE NOT NULL,
    area_receptora       ENUM('preceptoria','taller') NOT NULL,
    usuario_receptor_id  INT UNSIGNED NOT NULL,
    estado_notificacion  ENUM('pendiente','notificada') NOT NULL DEFAULT 'pendiente',
    fecha_notificacion   DATETIME NULL,
    created_at           DATETIME NULL,
    updated_at           DATETIME NULL,
    KEY idx_justificaciones_inscripcion (inscripcion_id),
    KEY idx_justificaciones_receptor (usuario_receptor_id),
    CONSTRAINT fk_just_inscripcion FOREIGN KEY (inscripcion_id)      REFERENCES inscripciones(id_inscripcion),
    CONSTRAINT fk_just_usuario     FOREIGN KEY (usuario_receptor_id) REFERENCES usuarios(id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Sin integración con el DAI (decisión confirmada: no se implementa).
CREATE TABLE alertas (
    id_alerta         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    inscripcion_id     INT UNSIGNED NOT NULL,
    tipo               ENUM('limite_inasistencias','seguimiento','asistencia_perfecta') NOT NULL,
    fecha_generacion   DATETIME NOT NULL,
    detalle            VARCHAR(255) NULL,
    estado             ENUM('activa','atendida') NOT NULL DEFAULT 'activa',
    created_at         DATETIME NULL,
    updated_at         DATETIME NULL,
    KEY idx_alertas_inscripcion (inscripcion_id),
    KEY idx_alertas_tipo_estado (tipo, estado),
    CONSTRAINT fk_alerta_inscripcion FOREIGN KEY (inscripcion_id) REFERENCES inscripciones(id_inscripcion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =====================================================================
-- 9. CIERRE DE CICLO: RESULTADOS FINALES Y DESENLACES
-- =====================================================================

CREATE TABLE resultados_finales (
    id_resultado_final       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    inscripcion_id           INT UNSIGNED NOT NULL,
    porcentaje_inasistencia  DECIMAL(5,2) NOT NULL,
    condicion_final          ENUM('regular','libre') NOT NULL,
    fecha_cierre             DATETIME NOT NULL,
    UNIQUE KEY uq_resultados_inscripcion (inscripcion_id),
    CONSTRAINT fk_rf_inscripcion FOREIGN KEY (inscripcion_id) REFERENCES inscripciones(id_inscripcion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE desenlaces (
    id_desenlace           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    inscripcion_id         INT UNSIGNED NOT NULL,
    tipo_desenlace         ENUM('promociona','recursa','egresa','baja') NOT NULL,
    curso_destino_id       INT UNSIGNED NULL COMMENT 'NULL si el curso destino no existe (pendiente_asignacion).',
    usuario_definicion_id  INT UNSIGNED NOT NULL,
    fecha_definicion       DATETIME NOT NULL,
    UNIQUE KEY uq_desenlaces_inscripcion (inscripcion_id),
    KEY idx_desenlaces_curso_destino (curso_destino_id),
    CONSTRAINT fk_des_inscripcion FOREIGN KEY (inscripcion_id)        REFERENCES inscripciones(id_inscripcion),
    CONSTRAINT fk_des_curso       FOREIGN KEY (curso_destino_id)      REFERENCES cursos(id_curso),
    CONSTRAINT fk_des_usuario     FOREIGN KEY (usuario_definicion_id) REFERENCES usuarios(id_usuario)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;


-- =====================================================================
-- 10. FUNCIÓN AUXILIAR: ¿LA PLANILLA ESTÁ BLOQUEADA?
-- =====================================================================


CREATE FUNCTION fn_planilla_bloqueada(p_planilla_id INT UNSIGNED)
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_estado VARCHAR(20);
    SELECT estado INTO v_estado FROM planillas_asistencia WHERE id_planilla = p_planilla_id;
    RETURN v_estado = 'bloqueada';
END;



-- =====================================================================
-- 11. PROCEDIMIENTO: RECALCULAR CONTADORES Y DISPARAR ALERTAS
-- =====================================================================
-- Se invoca desde los triggers de detalles_asistencia y justificaciones.


CREATE PROCEDURE sp_recalcular_contador(IN p_inscripcion_id INT UNSIGNED)
BEGIN
    DECLARE v_faltas_teoricas   DECIMAL(6,2);
    DECLARE v_faltas_taller     DECIMAL(6,2);
    DECLARE v_faltas_ed_fisica  DECIMAL(6,2);
    DECLARE v_tardanzas         INT;
    DECLARE v_faltas_x_tardanza DECIMAL(6,2);
    DECLARE v_faltas_general    DECIMAL(6,2);
    DECLARE v_justificaciones   INT;
    DECLARE v_valor_falta       DECIMAL(4,2);
    DECLARE v_tardanzas_x_falta INT;
    DECLARE v_umbral_pct        DECIMAL(5,2);
    DECLARE v_umbral_seguim     INT;
    DECLARE v_clases_minimas    INT;
    DECLARE v_total_clases      INT;
    DECLARE v_pct               DECIMAL(5,2);

    SELECT valor_falta, tardanzas_por_falta, umbral_alerta_pct, umbral_seguimiento_faltas, clases_minimas_alerta
      INTO v_valor_falta, v_tardanzas_x_falta, v_umbral_pct, v_umbral_seguim, v_clases_minimas
      FROM configuraciones WHERE id_configuracion = 1;

    -- total_clases cuenta las clases con planilla generada para ESTE
    -- alumno; los días sin clases quedan excluidos por construcción.
    SELECT
        COALESCE(SUM(CASE WHEN p.area='teorica'   AND d.estado='ausente' THEN v_valor_falta ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN p.area='taller'    AND d.estado='ausente' THEN v_valor_falta ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN p.area='ed_fisica' AND d.estado='ausente' THEN v_valor_falta ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN d.estado='tardanza' THEN 1 ELSE 0 END), 0),
        COUNT(*)
      INTO v_faltas_teoricas, v_faltas_taller, v_faltas_ed_fisica, v_tardanzas, v_total_clases
      FROM detalles_asistencia d
      JOIN planillas_asistencia p ON p.id_planilla = d.planilla_id
     WHERE d.inscripcion_id = p_inscripcion_id;

    SET v_faltas_x_tardanza = FLOOR(v_tardanzas / v_tardanzas_x_falta) * v_valor_falta;
    SET v_faltas_general    = v_faltas_teoricas + v_faltas_taller + v_faltas_ed_fisica + v_faltas_x_tardanza;

    SELECT COUNT(*) INTO v_justificaciones
      FROM justificaciones WHERE inscripcion_id = p_inscripcion_id;

    INSERT INTO contadores_asistencia
        (inscripcion_id, faltas_teoricas, faltas_taller, faltas_ed_fisica,
         faltas_general, tardanzas_global, justificaciones_total, fecha_actualizacion)
    VALUES
        (p_inscripcion_id, v_faltas_teoricas, v_faltas_taller, v_faltas_ed_fisica,
         v_faltas_general, v_tardanzas, v_justificaciones, NOW())
    ON DUPLICATE KEY UPDATE
        faltas_teoricas        = v_faltas_teoricas,
        faltas_taller          = v_faltas_taller,
        faltas_ed_fisica       = v_faltas_ed_fisica,
        faltas_general         = v_faltas_general,
        tardanzas_global       = v_tardanzas,
        justificaciones_total  = v_justificaciones,
        fecha_actualizacion    = NOW();

    IF v_total_clases > 0 THEN
        SET v_pct = (v_faltas_general / v_total_clases) * 100;
    ELSE
        SET v_pct = 0;
    END IF;

    -- Alerta de límite de inasistencias: no se evalúa por debajo del piso
    -- de clases_minimas_alerta (evita falsos positivos con poca muestra).
    IF v_total_clases >= v_clases_minimas AND v_pct >= v_umbral_pct AND NOT EXISTS (
        SELECT 1 FROM alertas
         WHERE inscripcion_id = p_inscripcion_id AND tipo = 'limite_inasistencias' AND estado = 'activa'
    ) THEN
        INSERT INTO alertas (inscripcion_id, tipo, fecha_generacion, detalle, estado)
        VALUES (p_inscripcion_id, 'limite_inasistencias', NOW(),
                CONCAT('Superó el umbral de inasistencias: ', v_pct, '% (umbral ', v_umbral_pct, '%).'), 'activa');
    END IF;

    -- Alerta de seguimiento (simplificación documentada en el PDF).
    IF v_faltas_general >= v_umbral_seguim AND NOT EXISTS (
        SELECT 1 FROM alertas
         WHERE inscripcion_id = p_inscripcion_id AND tipo = 'seguimiento' AND estado = 'activa'
    ) THEN
        INSERT INTO alertas (inscripcion_id, tipo, fecha_generacion, detalle, estado)
        VALUES (p_inscripcion_id, 'seguimiento', NOW(),
                CONCAT('Acumuló ', v_faltas_general, ' faltas globales.'), 'activa');
    END IF;
END;



-- =====================================================================
-- 12. TRIGGERS
-- =====================================================================

-- Permiso diario: no se puede crear una planilla nueva para HOY si no
-- hay un permiso abierto y vigente. No aplica a correcciones históricas.

CREATE TRIGGER trg_planillas_before_insert
BEFORE INSERT ON planillas_asistencia
FOR EACH ROW
BEGIN
    IF NEW.fecha = CURDATE() THEN
        IF NOT EXISTS (
            SELECT 1 FROM permisos_diarios
             WHERE fecha = CURDATE()
               AND cerrado_manual = FALSE
               AND CURTIME() <= hora_limite
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No hay un permiso diario abierto para tomar asistencia hoy.';
        END IF;
    END IF;
END;


-- Bloqueo de planillas ya enviadas/verificadas. La app debe ejecutar
-- `SET @permitir_correccion_admin = 1;` antes de una corrección
-- autorizada por jefa de preceptores/administrador.

CREATE TRIGGER trg_detalles_before_insert
BEFORE INSERT ON detalles_asistencia
FOR EACH ROW
BEGIN
    IF fn_planilla_bloqueada(NEW.planilla_id)
       AND (@permitir_correccion_admin IS NULL OR @permitir_correccion_admin = 0) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La planilla está bloqueada. Solo jefa de preceptores/administrador puede corregirla.';
    END IF;
END;

CREATE TRIGGER trg_detalles_before_update
BEFORE UPDATE ON detalles_asistencia
FOR EACH ROW
BEGIN
    IF fn_planilla_bloqueada(OLD.planilla_id)
       AND (@permitir_correccion_admin IS NULL OR @permitir_correccion_admin = 0) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'La planilla está bloqueada. Solo jefa de preceptores/administrador puede corregirla.';
    END IF;
END;


-- Recalcular contadores y evaluar alertas automáticamente.

CREATE TRIGGER trg_detalles_after_insert
AFTER INSERT ON detalles_asistencia
FOR EACH ROW
BEGIN
    CALL sp_recalcular_contador(NEW.inscripcion_id);
END;

CREATE TRIGGER trg_detalles_after_update
AFTER UPDATE ON detalles_asistencia
FOR EACH ROW
BEGIN
    CALL sp_recalcular_contador(NEW.inscripcion_id);
END;

CREATE TRIGGER trg_detalles_after_delete
AFTER DELETE ON detalles_asistencia
FOR EACH ROW
BEGIN
    CALL sp_recalcular_contador(OLD.inscripcion_id);
END;


-- Justificaciones: también recalculan el contador (justificaciones_total).

CREATE TRIGGER trg_justificaciones_after_insert
AFTER INSERT ON justificaciones
FOR EACH ROW
BEGIN
    CALL sp_recalcular_contador(NEW.inscripcion_id);
END;

CREATE TRIGGER trg_justificaciones_after_delete
AFTER DELETE ON justificaciones
FOR EACH ROW
BEGIN
    CALL sp_recalcular_contador(OLD.inscripcion_id);
END;



-- =====================================================================
-- 13. VISTAS DE APOYO
-- =====================================================================

CREATE VIEW vista_permisos_diarios_vigentes AS
SELECT *
FROM permisos_diarios
WHERE fecha = CURDATE()
  AND cerrado_manual = FALSE
  AND CURTIME() <= hora_limite;

-- Base para "planilla propia" (móvil) y reportes (escritorio).
CREATE VIEW vista_alumnos_contadores AS
SELECT
    i.id_inscripcion,
    a.id_alumno,
    a.nombre,
    a.apellido,
    a.dni,
    i.ciclo_lectivo_id,
    i.curso_id,
    i.estado AS estado_inscripcion,
    c.faltas_teoricas,
    c.faltas_taller,
    c.faltas_ed_fisica,
    c.faltas_general,
    c.tardanzas_global,
    c.justificaciones_total,
    c.fecha_actualizacion
FROM inscripciones i
JOIN alumnos a               ON a.id_alumno = i.alumno_id
LEFT JOIN contadores_asistencia c ON c.inscripcion_id = i.id_inscripcion;


-- =====================================================================
-- 14. PROCEDIMIENTO: CIERRE DE CICLO (FASE 1 DE 4)
-- =====================================================================
-- Fase 1 del "Proceso de Cierre y Apertura en Cuatro Fases" de la
-- narrativa: calcula y congela el resultado final de cada inscripción
-- activa del ciclo (porcentaje de inasistencia + condición regular/
-- libre) y marca el ciclo como cerrado. Las otras tres fases (definir
-- desenlaces, clonar estructura y generar inscripciones, población
-- manual) quedan para más adelante — son lógica de proceso con
-- decisiones humanas intercaladas entre fases, no estructura de tablas.
--
-- Simplificación documentada a propósito: la narrativa describe el
-- resultado final "por materia, respetando el régimen de cada una",
-- pero `resultados_finales` (sección 9) solo admite una fila por
-- inscripción — no hay una tabla de materias con régimen propio en
-- este modelo. Por eso acá la condición final es una sola por alumno,
-- calculada sobre el total de clases con detalle registrado para su
-- inscripción (mismo criterio que ya usa sp_recalcular_contador para
-- `faltas_general`). El umbral que separa `regular` de `libre` reusa
-- `umbral_alerta_pct` de `configuraciones`: es el único porcentaje de
-- inasistencia que existe en el modelo, no hay un parámetro aparte
-- para "pérdida de regularidad" distinto del de alerta temprana.
--
-- Idempotente a propósito: si una inscripción ya tiene fila en
-- `resultados_finales` (histórico inmutable), esta llamada la deja
-- intacta y no la recalcula — se puede volver a invocar sin romper
-- nada si quedó algún alumno sin procesar en una corrida anterior.

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

            -- Alerta de asistencia perfecta (RF6, tercer tipo): se evalúa
            -- acá y no en sp_recalcular_contador porque es un veredicto
            -- de cierre de ciclo completo, no de cada clase individual.
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
END;


-- =====================================================================
-- 15. TABLA: AUTO-REPORTE DE AUSENCIA DEL PROFESOR (TALLER / ED. FÍSICA)
-- =====================================================================
-- Funcionalidad pedida explícitamente por la cátedra, fuera de la
-- narrativa original: un profesor de taller o educación física puede
-- notificar su propia ausencia de un día puntual para un grupo puntual,
-- para que ese día no cuente asistencia en ese grupo. No aplica a
-- preceptores (tienen un suplente asignado para cubrir su ausencia) ni
-- a la asistencia teórica (siempre obligatoria mientras haya clases) —
-- por eso `area` acá solo admite 'taller'/'ed_fisica', a diferencia del
-- ENUM de `planillas_asistencia` (sección 6) que sí incluye 'teorica'.
-- `motivo` es de texto libre y opcional (igual que en `dias_sin_clases`,
-- sección 5) — en la práctica cubre cualquier razón puntual del día, no
-- solo una ausencia literal del profesor.
--
-- Siempre es HOY, sin excepción, a pedido explícito de la cátedra: el
-- profesor recibe la notificación para tomar asistencia el mismo día,
-- y ese mismo día, si falta, notifica su ausencia — no hay aviso con
-- anticipación ni carga retroactiva.
--
-- El efecto real lo hace cumplir la capa de aplicación
-- (AsistenciaController::crear()), que rechaza abrir una planilla de
-- taller/ed. física si existe una fila acá para ese grupo+fecha — mismo
-- mecanismo que usa `dias_sin_clases` (sección 5): sin planilla no hay
-- `detalles_asistencia`, así que `sp_cerrar_ciclo` (sección 14) no
-- cuenta ese día en `total_clases` para ningún alumno del grupo.
--
-- Las dos UNIQUE KEY (una por columna de grupo) reemplazan a un estado
-- "activa/cancelada": como no hay SoftDeletes, cancelar es un DELETE
-- físico (igual que `dias_sin_clases`), así que un grupo+fecha nunca
-- tiene más de una fila viva a la vez sin necesitar esa columna extra.
-- MySQL no choca dos NULL entre sí en una UNIQUE KEY, así que las filas
-- de la otra área (con esa columna en NULL) nunca colisionan entre ellas.

CREATE TABLE ausencias_docentes (
    id_ausencia_docente  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id           INT UNSIGNED NOT NULL COMMENT 'Profesor que notifica su propia ausencia.',
    area                 ENUM('taller','ed_fisica') NOT NULL,
    grupo_taller_id      INT UNSIGNED NULL COMMENT 'Solo si area = taller.',
    grupo_ed_fisica_id   INT UNSIGNED NULL COMMENT 'Solo si area = ed_fisica.',
    fecha                DATE NOT NULL,
    motivo               VARCHAR(100) NULL,
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

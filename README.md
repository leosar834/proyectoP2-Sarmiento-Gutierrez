## Sistema de control de asistencia para Escuela Tecnica N°1

## Institucion: Instituto de Educacion Superior N°7 Populorum Progressio In.Te.La

## Año 2026

## Autor/es:

### user:leosar834 email: 45761771@populorumnjujuy.ar

### user:NicoG95 email: 38975442@populorumjujuy.ar

## Profesores: Serrano Manuel, Hoyos Oscar

## Definición del problema:

### Actualmente el registro de asistencia de los alumnos se realiza mediante planillas fisicas de papel. Este metodo genera una comunicacion lenta entre preceptores, docentes de taller y docentes de educacion fisica dificultando el seguimiento diario y la verificacion de datos al finalizar cada jornada.

## Objetivo General:

### Desarrollar un sistema de asistencia digital propio para la institucion, o instituciones en general, que permita el registro de alumnos a traves de los dispositivos moviles del personal docente y administrativo.

### objetivo gral del profes

Desarrollar un sistema multiplataforma para la gestión y control de asistencia en una escuela secundaria con tres turnos, que permita registrar, monitorear y administrar de manera eficiente la asistencia de los estudiantes y docentes, optimizando los procesos institucionales, mejorando la disponibilidad de la información en tiempo real y facilitando la toma de decisiones administrativas y pedagógicas.

## Objetivos Especificos:

#### . Digitalizacion: Eliminar el uso de planillas fisicas para asistencia en talleres y aulas teoricas.

#### . Optimizacion: Agilizar la carga de datos de asistencia mediante un sistema movil que sea intuitiva tanto para profesores y preceptores.

#### . Integracion: Mejorar la comunicacion interna entre el personal administrativo (preceptores) y docentes a la hora de pasar lista y registrar asistencia

## Beneficios:

### Personal docente y preceptores: menor carga administrativa y mayor facilidad para calcular y acceder a la situacion de cada alumno en terminos de asistencia.

### Alumnos y padres: mayor control y seguridad sobre la presencia escolar.

## Alcance del Proyecto:

### El sistema cubrira la totalidad de los cursos de la Escuela Tecnica N°1 abarcando su doble turno (teoria y talleres)y hasta, en algunos casos, triple asistencia diaria(educacion fisica sumada a teoria y talleres) de cada alumno, permitiendo pasar lista y registrar la asistencia desde los telefonos celulares tanto de preceptores como de profesores.

## Cronograma de actividades

#### Etapa 1: Definicion y analisis (28/05)

##### - Definir objetivo del sistema

##### - Listar funcionalidades

##### - Identificar usuarios(roles)

##### - Definir tecnologias (Ejemplo Laravel, Flutter, MySQL)

##### - Crear backlog inicial

##### - Recoleccion de datos y conclusion

##### - Narrativa y diagrama de contexto

#### Etapa 2: Diseño UX/UI (30/06)

##### - Wireframes

##### - Flujo de navegacion

##### - Diseño base

##### - Prototipo en Figma

#### Etapa 3: Arquitectura + Base de datos (16/07)

##### - Diseño de base de datos

##### - Definir API

##### - Configurar Laravel

##### - Crear migraciones

#### Etapa 4: Backend core (13/08)

##### - Autenticacion

##### - CRUD principal

##### - Validaciones

##### - Pruebas API

#### Etapa 5: Backend avanzado (13/08)

##### - Roles y permisos

##### - Optimizacion

##### - Seguridad

#### Etapa 6: Desarrollo web (24/09)

##### - Login

##### - Dashboard

##### - CRUD

##### - Integracion API

#### Etapa 7: App movil (22/10)

##### - Login

##### - Navegacion

##### - Consumo API

#### Etapa 8: Testing + Deploy (12/11)

##### - Pruebas

##### - Correccion de bugs

##### - Deploy

## Estudio de Factibilidad

## Tecnica

#### El proyecto se considera tecnicamente viable, dado que se desarrolla utilizando herramientas de software de libre distribucion y de codigo abierto.

#### El proyecto se implementa en Laravel, el tratamiendo de los datos a traves del entorno Laragon. El desarrollador cuenta con los conocimientos basicos en desarrollo de aplicaciones web

## Economica

#### Desde el punto de vista economico, el proyecto no aplica costos significativos ya que se desarrolla con herramientas gratuitas como Laragon, Java, Laravel, Figma

## Operativa

#### El proyecto es operativamente factible, ya que responde a una necesidad existente en el establecimiento, optimizacion del registro de alumnos

## Requerimientos funcionales

#### El sistema debe registrar datos y generar reportes

## Requisitos generales

#### Interfaz simple y rapida

## Requisitos funcionales

#### - El sistema de be permitir iniciar sesion mediante usuario y contraseña o con su email.

#### - El sistemma debe registrar la asistencia de cada alumno

#### - El sistema debe generar reportes de asistencia

#### - El sistema debe permitir diferenciar roles de usuario

## Modelo de datos

### Datos de entrada

### Datos internos

### Datos de salida

## Base de datos

### Dependencias

- MySQL 8.0+ (probado contra 8.0.46). Requerido para los `CHECK` constraints reales y los `ENUM` con acentos.
- PHP 8.3+ con Laravel 13 (backend, expone la API).
- Laravel Sanctum 4.x (autenticación por token para la app Flutter móvil y la Flutter web del administrador).
- Flutter (SDK ^3.11) para la app móvil y la versión web de escritorio.

### Software (herramientas)

- Laragon (entorno local: Apache/Nginx, PHP, MySQL).
- Composer (dependencias de PHP).
- VS Code.
- Git / GitHub.

### Procedimiento de instalacion

**Backend (Laravel):**

1. `cd backend-laravel`
2. `composer install`
3. Copiar `.env.example` a `.env` y completar los datos de conexión a MySQL (por defecto: base `sistema_asistencia`, usuario `root`).
4. `php artisan key:generate`
5. Crear la base vacía (la migración crea las tablas, pero no la base en sí): `mysql -u root -e "CREATE DATABASE IF NOT EXISTS sistema_asistencia CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"`
6. `php artisan migrate` — crea las 29 tablas, función, procedimiento, 8 triggers y 2 vistas definidas en `database/sql/schema.sql`.
7. `php artisan db:seed` — carga el catálogo fijo de permisos, los 7 roles iniciales de la EETN.° 1 y un usuario administrador de prueba.
8. `php artisan serve`

**App Flutter:**

1. `cd app_flutter`
2. `flutter pub get`
3. `flutter run` (móvil) o `flutter run -d chrome` (web, para el rol de administrador de escritorio)

### Procedimientos de testing

- El esquema de base de datos (`schema.sql`) fue cargado y ejecutado contra una instancia real de MySQL 8.0.46 durante su desarrollo, probando cada trigger, la función y el procedimiento con datos de ejemplo (altas de asistencia, bloqueo de planillas, corrección con permiso de administrador, los `CHECK` de integridad y el piso mínimo de clases para la alerta de inasistencias). El detalle de cada prueba está documentado en `Documentacion_Base_de_Datos.pdf`.
- El flujo de autenticación (login por email/contraseña, emisión de token con la plataforma `movil`/`escritorio` grabada como ability de Sanctum, y acceso a una ruta protegida `/api/me` con ese token) fue probado manualmente end-to-end contra el backend corriendo localmente.
- Todavía no hay una suite de tests automatizados (PHPUnit/Pest) propia del dominio — queda pendiente para las etapas de Backend core/avanzado del cronograma.

## Estructura del repositorio

- `backend-laravel/` — API en Laravel 13 (PHP 8.3+, MySQL 8.0+). Autenticación por token con Sanctum.
- `app_flutter/` — app Flutter: móvil para los roles operativos (preceptor, profesor de taller, preceptor de taller, profesor de educación física) y web para el administrador de escritorio.
- `schema.sql` — script SQL completo del modelo de datos: 29 tablas, función, procedimiento, 8 triggers y 2 vistas. Es la fuente de verdad del esquema. `backend-laravel/database/sql/schema.sql` es la copia que efectivamente carga la migración `2026_07_17_100000_create_sistema_asistencia_schema` — se mantienen sincronizadas a mano cada vez que se edita el esquema.

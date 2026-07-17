# Sistema de Gestión de Asistencia — EETN.° 1 Cnel. Manuel Álvarez Prado

Práctica Profesionalizante II — IES N.° 7 Populorum Progressio
Leonardo Sarmiento — Nicolás Gutiérrez

Sistema de gestión de asistencia escolar, con arquitectura general y configurable por institución (roles, especialidades, talleres y parámetros de cálculo no están fijos en el código: la EETN.° 1 es la primera institución que lo adopta, no una regla del sistema).

## Estructura del repositorio

- `backend-laravel/` — API en Laravel 13 (PHP 8.3+, MySQL 8.0+). Autenticación por token con Sanctum.
- `app_flutter/` — app Flutter: móvil para los roles operativos (preceptor, profesor de taller, preceptor de taller, profesor de educación física) y web para el administrador de escritorio.
- `schema.sql` — script SQL completo del modelo de datos: 29 tablas, función, procedimiento, 8 triggers y 2 vistas. Es la fuente de verdad del esquema. `backend-laravel/database/sql/schema.sql` es la copia que efectivamente carga la migración `2026_07_17_100000_create_sistema_asistencia_schema` — se mantienen sincronizadas a mano cada vez que se edita el esquema.

## Cómo levantar el backend

1. `cd backend-laravel`
2. `composer install`
3. Copiar `.env.example` a `.env` y completar los datos de conexión a MySQL (por defecto: base `sistema_asistencia`, usuario `root`).
4. `php artisan key:generate`
5. `php artisan migrate`
6. `php artisan db:seed`
7. `php artisan serve`

## Cómo levantar la app Flutter

1. `cd app_flutter`
2. `flutter pub get`
3. `flutter run` (móvil) o `flutter run -d chrome` (web, para el rol de administrador de escritorio)

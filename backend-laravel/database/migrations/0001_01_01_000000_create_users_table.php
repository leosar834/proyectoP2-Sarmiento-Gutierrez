<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Esta migración venía con Laravel trayendo `users` y
     * `password_reset_tokens`. Se sacan las dos acá: el sistema usa la
     * tabla `usuarios` de database/sql/schema.sql (PK id_usuario, con su
     * propio catálogo de roles/permisos) y no hay flujo de autoservicio de
     * "olvidé mi contraseña" — las altas/bajas de usuarios y sus
     * contraseñas las gestiona jefa de preceptores/administrador desde la
     * web (RF1). Se conserva `sessions` porque SESSION_DRIVER=database
     * sigue en uso para el guard `web` interno de Laravel.
     */
    public function up(): void
    {
        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sessions');
    }
};

<?php

use App\Http\Controllers\Api\AsistenciaController;
use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    // RF2 — Registro de Asistencia. Cada ruta encadena, además de
    // auth:sanctum, el permiso puntual que le corresponde según la
    // narrativa (ver App\Http\Middleware\VerificarPermiso).
    Route::middleware('permiso:tomar_asistencia')
        ->post('/planillas', [AsistenciaController::class, 'crear']);

    Route::middleware('permiso:editar_asistencia_del_dia')->group(function () {
        Route::put('/planillas/{planilla}/detalles', [AsistenciaController::class, 'guardarDetalles']);
        Route::post('/planillas/{planilla}/enviar', [AsistenciaController::class, 'enviar']);
    });

    Route::middleware('permiso:corregir_asistencia_historica')
        ->put('/detalles/{detalle}/corregir', [AsistenciaController::class, 'corregirDetalle']);
});

// A medida que avancemos módulo por módulo (cursos, alumnos, reportes...)
// las rutas de cada uno se agregan acá adentro del grupo auth:sanctum,
// encadenando el middleware `permiso:<nombre>` donde corresponda.
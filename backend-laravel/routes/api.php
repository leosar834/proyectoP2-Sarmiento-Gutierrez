<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
});

// A medida que avancemos módulo por módulo (cursos, alumnos, asistencia...)
// las rutas de cada uno se agregan acá adentro del grupo auth:sanctum,
// encadenando el middleware `permiso:<nombre>` donde corresponda. Ejemplo:
// Route::middleware('permiso:tomar_asistencia')->post('/asistencia', ...);
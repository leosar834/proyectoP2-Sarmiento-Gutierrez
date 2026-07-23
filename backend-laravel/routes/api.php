<?php

use App\Http\Controllers\Api\AlertasController;
use App\Http\Controllers\Api\AsignacionesController;
use App\Http\Controllers\Api\AsistenciaController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CierreCicloController;
use App\Http\Controllers\Api\DesenlacesController;
use App\Http\Controllers\Api\JustificacionesController;
use App\Http\Controllers\Api\ReportesController;
use App\Http\Controllers\Api\AperturaCicloController;
use App\Http\Controllers\Api\IngresantesController;
use App\Http\Controllers\Api\GruposEdFisicaController;
use App\Http\Controllers\Api\GruposTallerController;
use App\Http\Controllers\Api\DistribucionEspecialidadesController;
use Illuminate\Support\Facades\Route;


Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    // Qué curso/grupos son míos, del ciclo lectivo abierto — sin
    // `permiso:` puntual, igual que /me (ver AsignacionesController).
    Route::get('/mis-asignaciones', [AsignacionesController::class, 'index']);

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

    // RF5 — Gestión de Faltas Justificadas. Registrar, listar lo
    // pendiente de notificación cruzada y marcarla como notificada
    // comparten el mismo permiso: recibir una justificación es siempre
    // una acción de plataforma móvil (ver JustificacionesController).
    Route::middleware('permiso:justificar_inasistencias')->group(function () {
        Route::post('/justificaciones', [JustificacionesController::class, 'crear']);
        Route::get('/justificaciones/pendientes', [JustificacionesController::class, 'pendientes']);
        Route::patch('/justificaciones/{justificacion}/notificar', [JustificacionesController::class, 'notificar']);
    });

    // RF6 (alertas) y RF7 (reportes) comparten el mismo permiso de
    // visibilidad institucional — ver AlertasController y
    // ReportesController.
    Route::middleware('permiso:ver_reportes')->group(function () {
        Route::get('/alertas', [AlertasController::class, 'index']);
        Route::patch('/alertas/{alerta}/atender', [AlertasController::class, 'atender']);

        Route::get('/reportes/faltas-por-curso', [ReportesController::class, 'faltasPorCurso']);
        Route::get('/reportes/faltas-por-curso/exportar', [ReportesController::class, 'exportarFaltasPorCurso']);
        Route::get('/reportes/alumnos/{inscripcion}/estadisticas', [ReportesController::class, 'estadisticasAlumno']);
    });

    // Proceso de Cierre y Apertura en Cuatro Fases. Fase 1 (cierre) y
    // Fase 2 (desenlaces) por ahora — ver CierreCicloController y
    // DesenlacesController.
    Route::middleware('permiso:gestionar_sistema')->group(function () {
        Route::post('/ciclos-lectivos/{ciclo}/cerrar', [CierreCicloController::class, 'cerrar']);
        Route::post('/ciclos-lectivos/{ciclo}/ingresantes', [IngresantesController::class, 'crear']);
        Route::post('/ciclos-lectivos/{ciclo}/abrir-siguiente', [AperturaCicloController::class, 'abrir']);
        Route::post('/ciclos-lectivos/{ciclo}/desenlaces/inicializar', [DesenlacesController::class, 'inicializar']);
        Route::get('/ciclos-lectivos/{ciclo}/desenlaces', [DesenlacesController::class, 'index']);
        Route::put('/desenlaces/{desenlace}', [DesenlacesController::class, 'actualizar']);
        Route::post('/ciclos-lectivos/{ciclo}/grupos-ed-fisica', [GruposEdFisicaController::class, 'crear']);
        Route::get('/ciclos-lectivos/{ciclo}/grupos-ed-fisica', [GruposEdFisicaController::class, 'index']);
        Route::post('/grupos-ed-fisica/{grupo}/asignar-lote', [GruposEdFisicaController::class, 'asignarLote']);
        Route::post('/ciclos-lectivos/{ciclo}/grupos-taller', [GruposTallerController::class, 'crear']);
        Route::get('/ciclos-lectivos/{ciclo}/grupos-taller', [GruposTallerController::class, 'index']);
        Route::post('/grupos-taller/{grupo}/asignar-lote', [GruposTallerController::class, 'asignarLote']);
        Route::post('/ciclos-lectivos/{ciclo}/inscripciones/asignar-especialidad-lote', [DistribucionEspecialidadesController::class, 'asignarLote']);
    });
});

// A medida que avancemos módulo por módulo (cursos, alumnos, reportes...)
// las rutas de cada uno se agregan acá adentro del grupo auth:sanctum,
// encadenando el middleware `permiso:<nombre>` donde corresponda.
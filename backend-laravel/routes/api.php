<?php

use App\Http\Controllers\Api\AlertasController;
use App\Http\Controllers\Api\AsignacionesController;
use App\Http\Controllers\Api\AsistenciaController;
use App\Http\Controllers\Api\AusenciasDocentesController;
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
use App\Http\Controllers\Api\RolesController;
use App\Http\Controllers\Api\UsuariosController;
use App\Http\Controllers\Api\NivelesController;
use App\Http\Controllers\Api\DivisionesController;
use App\Http\Controllers\Api\EspecialidadesController;
use App\Http\Controllers\Api\CursosController;
use App\Http\Controllers\Api\MateriasTallerController;
use App\Http\Controllers\Api\PermisosDiariosController;
use App\Http\Controllers\Api\DiasSinClasesController;
use App\Http\Controllers\Api\TrasladosController;
use App\Http\Controllers\Api\AlumnosController;
use Illuminate\Support\Facades\Route;


Route::post('/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {

    Route::middleware('permiso:consultar_planilla_propia')
    ->get('/planillas', [AsistenciaController::class, 'index']);

    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    // Qué curso/grupos son míos, del ciclo lectivo abierto — sin
    // `permiso:` puntual, igual que /me (ver AsignacionesController).
    Route::get('/mis-asignaciones', [AsignacionesController::class, 'index']);

    // RF2 — Registro de Asistencia. Cada ruta encadena, además de
    // auth:sanctum, el permiso puntual que le corresponde según la
    // narrativa (ver App\Http\Middleware\VerificarPermiso).
    Route::middleware('permiso:tomar_asistencia')->group(function () {
        Route::post('/planillas', [AsistenciaController::class, 'crear']);

        // Auto-reporte de ausencia del profesor de taller/ed. física —
        // pedido explícito de la cátedra, fuera de la narrativa
        // original (ver App\Models\AusenciaDocente). No aplica a
        // preceptores (suplente asignado) ni a teórica (siempre
        // obligatoria si hay clases). Comparte permiso con abrir la
        // planilla: es la contracara del mismo gesto, mismo grupo,
        // mismo día.
        Route::post('/ausencias-docentes', [AusenciasDocentesController::class, 'crear']);
        Route::get('/ausencias-docentes', [AusenciasDocentesController::class, 'index']);
        Route::delete('/ausencias-docentes/{ausenciaDocente}', [AusenciasDocentesController::class, 'eliminar']);
    });

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
        Route::get('/reportes/alumnos/{inscripcion}/estadisticas/exportar', [ReportesController::class, 'exportarEstadisticasAlumno']);
    });

    // Proceso de Cierre y Apertura en Cuatro Fases (completo): Fase 1
    // (cierre) en CierreCicloController, Fase 2 (desenlaces) en
    // DesenlacesController, Fase 3 (apertura y generación de
    // inscripciones) en AperturaCicloController, Fase 4 (población
    // manual) en IngresantesController + GruposTallerController +
    // GruposEdFisicaController + DistribucionEspecialidadesController.
    Route::middleware('permiso:gestionar_sistema')->group(function () {
        Route::post('/ciclos-lectivos/{ciclo}/cerrar', [CierreCicloController::class, 'cerrar']);
        Route::post('/ciclos-lectivos/{ciclo}/ingresantes', [IngresantesController::class, 'crear']);
        Route::post('/ciclos-lectivos/{ciclo}/abrir-siguiente', [AperturaCicloController::class, 'abrir']);
        Route::post('/ciclos-lectivos/{ciclo}/desenlaces/inicializar', [DesenlacesController::class, 'inicializar']);

        Route::get('/ciclos-lectivos/{ciclo}/desenlaces', [DesenlacesController::class, 'index']);
        Route::put('/desenlaces/{desenlace}', [DesenlacesController::class, 'actualizar']);

        Route::post('/ciclos-lectivos/{ciclo}/grupos-ed-fisica', [GruposEdFisicaController::class, 'crear']);
        Route::get('/ciclos-lectivos/{ciclo}/grupos-ed-fisica', [GruposEdFisicaController::class, 'index']);
        Route::put('/grupos-ed-fisica/{grupo}', [GruposEdFisicaController::class, 'actualizar']);
        Route::delete('/grupos-ed-fisica/{grupo}', [GruposEdFisicaController::class, 'eliminar']);

        Route::post('/grupos-ed-fisica/{grupo}/asignar-lote', [GruposEdFisicaController::class, 'asignarLote']);

        Route::post('/ciclos-lectivos/{ciclo}/grupos-taller', [GruposTallerController::class, 'crear']);
        Route::get('/ciclos-lectivos/{ciclo}/grupos-taller', [GruposTallerController::class, 'index']);
        Route::put('/grupos-taller/{grupo}', [GruposTallerController::class, 'actualizar']);
        Route::delete('/grupos-taller/{grupo}', [GruposTallerController::class, 'eliminar']);

        Route::post('/grupos-taller/{grupo}/asignar-lote', [GruposTallerController::class, 'asignarLote']);
        Route::post('/ciclos-lectivos/{ciclo}/inscripciones/asignar-especialidad-lote', [DistribucionEspecialidadesController::class, 'asignarLote']);

        Route::post('/ciclos-lectivos/{ciclo}/cursos', [CursosController::class, 'crear']);
        Route::get('/ciclos-lectivos/{ciclo}/cursos', [CursosController::class, 'index']);
        Route::put('/cursos/{curso}', [CursosController::class, 'actualizar']);
        Route::delete('/cursos/{curso}', [CursosController::class, 'eliminar']);
        Route::patch('/cursos/{curso}/restaurar', [CursosController::class, 'restaurar']);

        Route::post('/materias-taller', [MateriasTallerController::class, 'crear']);
        Route::get('/materias-taller', [MateriasTallerController::class, 'index']);
        Route::put('/materias-taller/{materiaTaller}', [MateriasTallerController::class, 'actualizar']);
        Route::delete('/materias-taller/{materiaTaller}', [MateriasTallerController::class, 'eliminar']);

        Route::post('/roles', [RolesController::class, 'crear']);
        Route::get('/roles', [RolesController::class, 'index']);
        Route::put('/roles/{rol}', [RolesController::class, 'actualizar']);
        Route::delete('/roles/{rol}', [RolesController::class, 'eliminar']);
        Route::patch('/roles/{rol}/restaurar', [RolesController::class, 'restaurar']);
        Route::put('/roles/{rol}/permisos', [RolesController::class, 'asignarPermisos']);

        Route::post('/usuarios', [UsuariosController::class, 'crear']);
        Route::get('/usuarios', [UsuariosController::class, 'index']);
        Route::put('/usuarios/{usuario}', [UsuariosController::class, 'actualizar']);
        Route::delete('/usuarios/{usuario}', [UsuariosController::class, 'eliminar']);
        Route::patch('/usuarios/{usuario}/restaurar', [UsuariosController::class, 'restaurar']);
        Route::put('/usuarios/{usuario}/roles', [UsuariosController::class, 'asignarRoles']);

        Route::post('/niveles', [NivelesController::class, 'crear']);
        Route::get('/niveles', [NivelesController::class, 'index']);
        Route::put('/niveles/{nivel}', [NivelesController::class, 'actualizar']);
        Route::delete('/niveles/{nivel}', [NivelesController::class, 'eliminar']);
        Route::patch('/niveles/{nivel}/restaurar', [NivelesController::class, 'restaurar']);

        Route::post('/divisiones', [DivisionesController::class, 'crear']);
        Route::get('/divisiones', [DivisionesController::class, 'index']);
        Route::put('/divisiones/{division}', [DivisionesController::class, 'actualizar']);
        Route::delete('/divisiones/{division}', [DivisionesController::class, 'eliminar']);
        Route::patch('/divisiones/{division}/restaurar', [DivisionesController::class, 'restaurar']);

        Route::post('/especialidades', [EspecialidadesController::class, 'crear']);
        Route::get('/especialidades', [EspecialidadesController::class, 'index']);
        Route::put('/especialidades/{especialidad}', [EspecialidadesController::class, 'actualizar']);
        Route::delete('/especialidades/{especialidad}', [EspecialidadesController::class, 'eliminar']);
        Route::patch('/especialidades/{especialidad}/restaurar', [EspecialidadesController::class, 'restaurar']);

        // RF2 — apertura diaria del permiso para tomar asistencia
        // (narrativa, Alcance: "el jefe de preceptores abre manualmente
        // a diario el permiso..."). Sin `{ciclo}`: `permisos_diarios`
        // no tiene ciclo_lectivo_id, es UNIQUE por fecha únicamente —
        // ver App\Http\Controllers\Api\PermisosDiariosController.
        Route::post('/permisos-diarios/abrir', [PermisosDiariosController::class, 'abrir']);
        Route::patch('/permisos-diarios/cerrar', [PermisosDiariosController::class, 'cerrar']);
        Route::get('/permisos-diarios/hoy', [PermisosDiariosController::class, 'hoy']);

        Route::post('/ciclos-lectivos/{ciclo}/dias-sin-clases', [DiasSinClasesController::class, 'crear']);
        Route::get('/ciclos-lectivos/{ciclo}/dias-sin-clases', [DiasSinClasesController::class, 'index']);
        Route::put('/dias-sin-clases/{diaSinClase}', [DiasSinClasesController::class, 'actualizar']);
        Route::delete('/dias-sin-clases/{diaSinClase}', [DiasSinClasesController::class, 'eliminar']);

        Route::get('/alumnos/{alumno}', [AlumnosController::class, 'mostrar']);
        Route::post('/alumnos', [AlumnosController::class, 'crear']);
        Route::get('/alumnos', [AlumnosController::class, 'index']);
        Route::put('/alumnos/{alumno}', [AlumnosController::class, 'actualizar']);
        Route::delete('/alumnos/{alumno}', [AlumnosController::class, 'eliminar']);
        Route::patch('/alumnos/{alumno}/restaurar', [AlumnosController::class, 'restaurar']);

        Route::post('/ciclos-lectivos/{ciclo}/traslados', [TrasladosController::class, 'trasladar']);

        Route::put('/inscripciones/{inscripcion}/dar-de-baja', [TrasladosController::class, 'darDeBaja']);

        Route::put('/cursos/{curso}/preceptores', [CursosController::class, 'asignarPreceptores']);
        
        Route::put('/grupos-taller/{grupo}/usuarios', [GruposTallerController::class, 'asignarUsuarios']);
        
        Route::put('/grupos-ed-fisica/{grupo}/profesor', [GruposEdFisicaController::class, 'asignarProfesor']);
    });

    
});

// A medida que avancemos módulo por módulo (cursos, alumnos, reportes...)
// las rutas de cada uno se agregan acá adentro del grupo auth:sanctum,
// encadenando el middleware `permiso:<nombre>` donde corresponda.
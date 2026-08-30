import '../models/alumno_asistencia.dart';
import '../models/asignacion.dart';
import '../models/planilla_asistencia.dart';
import 'api_client.dart';

/// Llamadas de RF2 ("Registro de Asistencia") que ya tienen pantalla:
/// `GET /mis-asignaciones`, `POST /planillas` (solo área `teorica` por
/// ahora — ver `AsistenciaController`/`MisAsignacionesScreen`), `GET
/// /planillas/{id}/alumnos` y `PUT /planillas/{id}/detalles`. `enviar()`
/// (exclusivo de taller) queda para cuando se construya esa área.
class AsistenciaRepository {
  AsistenciaRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Asignacion>> misAsignaciones() async {
    final respuesta =
        await _apiClient.get('/mis-asignaciones') as Map<String, dynamic>;
    final lista = respuesta['data'] as List;
    return lista
        .map((json) => Asignacion.fromJson(json as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Abre (o recupera, si ya se había abierto) la planilla de HOY para
  /// un curso teórico. Sin `hora_limite` ni fecha: `CrearPlanillaRequest`
  /// siempre es hoy, y solo funciona si el permiso diario está abierto
  /// (ver `PermisosDiariosScreen`) — si no, esto tira `ApiException` con
  /// ese mensaje tal cual lo arma el backend.
  Future<PlanillaAsistencia> abrirPlanillaTeorica({required int cursoId}) async {
    final respuesta = await _apiClient.post('/planillas', body: {
      'area': 'teorica',
      'curso_id': cursoId,
    }) as Map<String, dynamic>;

    return PlanillaAsistencia.fromJson(
        respuesta['data'] as Map<String, dynamic>);
  }

  Future<List<AlumnoAsistencia>> obtenerAlumnos(int idPlanilla) async {
    final respuesta = await _apiClient.get('/planillas/$idPlanilla/alumnos')
        as Map<String, dynamic>;
    final lista = respuesta['data'] as List;
    return lista
        .map((json) => AlumnoAsistencia.fromJson(json as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Guarda el estado de todos los alumnos marcados hasta ahora — no
  /// hace falta que estén completos los 30 para poder guardar (eso solo
  /// se exige al "enviar", que en teórica no existe: ver el docblock de
  /// `AsistenciaController::enviar()`). Se puede volver a llamar tantas
  /// veces como haga falta mientras dure el día.
  Future<void> guardarDetalles({
    required int idPlanilla,
    required List<DetalleParaGuardar> detalles,
  }) async {
    await _apiClient.put('/planillas/$idPlanilla/detalles', body: {
      'detalles': detalles.map((d) => d.toJson()).toList(),
    });
  }
}

/// Una fila a guardar en `PUT /planillas/{id}/detalles` — construida en
/// la pantalla a partir del `Map<inscripcionId, estado>` que va tocando
/// el usuario, no un modelo de lectura como `AlumnoAsistencia`.
class DetalleParaGuardar {
  const DetalleParaGuardar({required this.inscripcionId, required this.estado});

  final int inscripcionId;

  /// 'presente' | 'ausente' | 'tardanza' | 'falta_justificada'.
  final String estado;

  Map<String, dynamic> toJson() => {
        'inscripcion_id': inscripcionId,
        'estado': estado,
      };
}

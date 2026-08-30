import '../models/permiso_diario.dart';
import 'api_client.dart';

/// Llamadas contra `GET /permisos-diarios/hoy`, `POST
/// /permisos-diarios/abrir` y `PATCH /permisos-diarios/cerrar` (ver
/// `PermisosDiariosController` en el backend, detrás de
/// `permiso:gestionar_sistema`). Mismo criterio que
/// `InstitucionRepository`: clase plana, sin estado propio ni
/// `ChangeNotifier` — la pantalla que lo use es quien guarda el
/// resultado.
class PermisoDiarioRepository {
  PermisoDiarioRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<EstadoPermisoDiario> obtenerHoy() async {
    final respuesta =
        await _apiClient.get('/permisos-diarios/hoy') as Map<String, dynamic>;
    return EstadoPermisoDiario.fromJson(
        respuesta['data'] as Map<String, dynamic>);
  }

  /// Abre (o reabre, si ya se había cerrado) el permiso de hoy.
  /// `horaLimite` es opcional — sin especificar, el backend usa
  /// `23:59:59`. Formato esperado: 'HH:mm:ss'.
  Future<PermisoDiario> abrir({String? horaLimite}) async {
    final respuesta = await _apiClient.post('/permisos-diarios/abrir', body: {
      if (horaLimite != null) 'hora_limite': horaLimite,
    }) as Map<String, dynamic>;

    return PermisoDiario.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Cierre anticipado explícito del permiso de hoy.
  Future<PermisoDiario> cerrar() async {
    final respuesta = await _apiClient.patch('/permisos-diarios/cerrar')
        as Map<String, dynamic>;

    return PermisoDiario.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

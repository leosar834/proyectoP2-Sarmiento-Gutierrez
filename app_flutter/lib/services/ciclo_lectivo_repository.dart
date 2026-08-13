import '../models/ciclo_lectivo.dart';
import 'api_client.dart';

/// Llamadas contra `GET`/`POST /ciclos-lectivos` (ver
/// `CiclosLectivosController` en el backend, detrás de
/// `permiso:gestionar_sistema`).
///
/// Ojo con el alcance de `crear()`: solo sirve para dar de alta el
/// PRIMER ciclo lectivo de una instalación nueva — el backend rechaza
/// la llamada si ya existe alguno. Los ciclos siguientes se generan
/// siempre cerrando el actual y abriendo el próximo (Fases 1 a 4 del
/// proceso de cierre/apertura), un desarrollo aparte que todavía no
/// tiene pantalla propia.
class CicloLectivoRepository {
  CicloLectivoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CicloLectivo>> obtenerTodos() async {
    final respuesta =
        await _apiClient.get('/ciclos-lectivos') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => CicloLectivo.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<CicloLectivo> crear({
    required int anio,
    required String fechaInicio,
  }) async {
    final respuesta = await _apiClient.post('/ciclos-lectivos', body: {
      'anio': anio,
      'fecha_inicio': fechaInicio,
    }) as Map<String, dynamic>;

    return CicloLectivo.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

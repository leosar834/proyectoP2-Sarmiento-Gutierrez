import '../models/division.dart';
import 'api_client.dart';

/// Llamadas contra `/divisiones` (ver `DivisionesController` en el
/// backend, detrás de `permiso:gestionar_sistema`). Mismo criterio de
/// `restaurar()` que `NivelRepository`

class DivisionRepository {
  DivisionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Division>> obtenerTodos() async {
    final respuesta =
        await _apiClient.get('/divisiones') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Division.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Division> crear({required String nombre}) async {
    final respuesta = await _apiClient.post('/divisiones', body: {
      'nombre': nombre,
    }) as Map<String, dynamic>;

    return Division.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<Division> actualizar(int id, {required String nombre}) async {
    final respuesta = await _apiClient.put('/divisiones/$id', body: {
      'nombre': nombre,
    }) as Map<String, dynamic>;

    return Division.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _apiClient.delete('/divisiones/$id');
  }

  /// Divisiones dadas de baja — ver el mismo razonamiento en
  /// `NivelRepository.obtenerEliminados()`.
  
  Future<List<Division>> obtenerEliminados() async {
    final respuesta = await _apiClient.get('/divisiones/eliminados')
        as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Division.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Division> restaurar(int id) async {
    final respuesta = await _apiClient.patch('/divisiones/$id/restaurar')
        as Map<String, dynamic>;

    return Division.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

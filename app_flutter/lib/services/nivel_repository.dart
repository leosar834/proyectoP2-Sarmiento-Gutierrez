import '../models/nivel.dart';
import 'api_client.dart';

/// Llamadas contra `/niveles` (ver `NivelesController` en el backend,
/// detrás de `permiso:gestionar_sistema`).
///
/// `restaurar()` existe porque `crear()`/`actualizar()` del backend, al
/// chocar con un `numero_orden` que ya usó un nivel dado de baja, lo
/// dicen explícitamente en el mensaje de error ("hay que restaurarlo en
/// vez de crear uno nuevo") — ver `NivelesScreen` para dónde se ofrece
/// ese botón.

class NivelRepository {
  NivelRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Nivel>> obtenerTodos() async {
    final respuesta =
        await _apiClient.get('/niveles') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Nivel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Nivel> crear({required String nombre, required int numeroOrden}) async {
    final respuesta = await _apiClient.post('/niveles', body: {
      'nombre': nombre,
      'numero_orden': numeroOrden,
    }) as Map<String, dynamic>;

    return Nivel.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<Nivel> actualizar(
    int id, {
    required String nombre,
    required int numeroOrden,
  }) async {
    final respuesta = await _apiClient.put('/niveles/$id', body: {
      'nombre': nombre,
      'numero_orden': numeroOrden,
    }) as Map<String, dynamic>;

    return Nivel.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _apiClient.delete('/niveles/$id');
  }

  /// Niveles dados de baja: la baja
  /// lógica tiene que poder revertirse desde la propia pantalla
  /// (`NivelesScreen`), no solo como sugerencia dentro de un error al
  /// chocar con un `numero_orden` repetido.
  Future<List<Nivel>> obtenerEliminados() async {
    final respuesta =
        await _apiClient.get('/niveles/eliminados') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Nivel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Nivel> restaurar(int id) async {
    final respuesta =
        await _apiClient.patch('/niveles/$id/restaurar') as Map<String, dynamic>;

    return Nivel.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

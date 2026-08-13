import '../models/rol.dart';
import 'api_client.dart';

/// Llamadas contra `/roles` y `/roles/{rol}/permisos` (ver
/// `RolesController` en el backend, detrás de `permiso:gestionar_sistema`).

class RolRepository {
  RolRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Rol>> obtenerTodos() async {
    final respuesta = await _apiClient.get('/roles') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Rol.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Rol> crear({required String nombre, String? descripcion}) async {
    final respuesta = await _apiClient.post('/roles', body: {
      'nombre': nombre,
      'descripcion': descripcion,
    }) as Map<String, dynamic>;

    return Rol.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<Rol> actualizar(
    int id, {
    required String nombre,
    String? descripcion,
    required bool activo,
  }) async {
    final respuesta = await _apiClient.put('/roles/$id', body: {
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
    }) as Map<String, dynamic>;

    return Rol.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _apiClient.delete('/roles/$id');
  }

  /// Roles dados de baja — mismo patrón que `NivelRepository.
  /// obtenerEliminados()`: la baja lógica se puede revertir eligiendo de
  /// una lista, no solo como sugerencia dentro de un error.
  Future<List<Rol>> obtenerEliminados() async {
    final respuesta =
        await _apiClient.get('/roles/eliminados') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Rol.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Rol> restaurar(int id) async {
    final respuesta =
        await _apiClient.patch('/roles/$id/restaurar') as Map<String, dynamic>;

    return Rol.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Reemplaza (sync) la matriz completa de permisos del rol — mandar
  /// una lista vacía es válido, deja al rol temporalmente sin ningún
  /// permiso sin necesidad de eliminarlo (ver `AsignarPermisosRolRequest`
  /// en el backend).
  Future<Rol> asignarPermisos(int id, List<int> permisoIds) async {
    final respuesta = await _apiClient.put('/roles/$id/permisos', body: {
      'permiso_ids': permisoIds,
    }) as Map<String, dynamic>;

    return Rol.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

import '../models/usuario_gestion.dart';
import 'api_client.dart';

/// Llamadas contra `/usuarios` y `/usuarios/{usuario}/roles` (ver
/// `UsuariosController` en el backend, detrás de
/// `permiso:gestionar_sistema`). No confundir con `AuthRepository`, que
/// maneja login/sesión del usuario actual — este repositorio es
/// exclusivamente para la administración de la lista completa de
/// usuarios desde `UsuariosScreen`.
class UsuarioRepository {
  UsuarioRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<UsuarioGestion>> obtenerTodos() async {
    final respuesta =
        await _apiClient.get('/usuarios') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => UsuarioGestion.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<UsuarioGestion> crear({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    bool? activo,
    List<int>? rolIds,
  }) async {
    final respuesta = await _apiClient.post('/usuarios', body: {
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'password': password,
      'activo': ?activo,
      'rol_ids': ?rolIds,
    }) as Map<String, dynamic>;

    return UsuarioGestion.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// `password` solo se manda si el administrador la cambió — dejarla
  /// afuera del body evita pisarla (ver el docblock de
  /// `ActualizarUsuarioRequest` en el backend).
  Future<UsuarioGestion> actualizar(
    int id, {
    required String nombre,
    required String apellido,
    required String email,
    String? password,
    required bool activo,
  }) async {
    final respuesta = await _apiClient.put('/usuarios/$id', body: {
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
      'activo': activo,
    }) as Map<String, dynamic>;

    return UsuarioGestion.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _apiClient.delete('/usuarios/$id');
  }

  /// Usuarios dados de baja — mismo patrón que `RolRepository.
  /// obtenerEliminados()`.
  Future<List<UsuarioGestion>> obtenerEliminados() async {
    final respuesta =
        await _apiClient.get('/usuarios/eliminados') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => UsuarioGestion.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<UsuarioGestion> restaurar(int id) async {
    final respuesta = await _apiClient.patch('/usuarios/$id/restaurar')
        as Map<String, dynamic>;

    return UsuarioGestion.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Reemplaza (sync) la lista completa de roles del usuario — array
  /// vacío permitido, deja al usuario temporalmente sin ningún rol sin
  /// tener que eliminarlo.
  Future<UsuarioGestion> asignarRoles(int id, List<int> rolIds) async {
    final respuesta = await _apiClient.put('/usuarios/$id/roles', body: {
      'rol_ids': rolIds,
    }) as Map<String, dynamic>;

    return UsuarioGestion.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

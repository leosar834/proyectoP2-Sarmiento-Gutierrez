import '../models/permiso.dart';
import 'api_client.dart';

/// Llamadas contra `/permisos` (ver `PermisosController` en el backend,
/// detrás de `permiso:gestionar_sistema`). Catálogo fijo, de solo
/// lectura — no hay `crear`/`actualizar`/`eliminar` porque la
/// institución no lo edita, solo lo usa para armar el checklist de
/// `RolesScreen`.

class PermisoRepository {
  PermisoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Permiso>> obtenerTodos() async {
    final respuesta =
        await _apiClient.get('/permisos') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Permiso.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}

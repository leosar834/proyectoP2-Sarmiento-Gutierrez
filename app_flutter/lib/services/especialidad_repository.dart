import '../models/especialidad.dart';
import 'api_client.dart';

/// Llamadas contra `/especialidades` (ver `EspecialidadesController` en
/// el backend, detrás de `permiso:gestionar_sistema`).
///
/// Además de `obtenerEliminados()` (mismo patrón que
/// `NivelRepository`), el formulario de alta/edición sigue ofreciendo
/// el atajo "(id X)" a partir del mensaje de error que devuelve
/// `crear()` cuando el nombre choca con una especialidad borrada —
/// mismo patrón que ya usa `_FormularioEditarAlumno` para legajos.
class EspecialidadRepository {
  EspecialidadRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Especialidad>> obtenerTodos() async {
    final respuesta =
        await _apiClient.get('/especialidades') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Especialidad.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Especialidad> crear({required String nombre}) async {
    final respuesta = await _apiClient.post('/especialidades', body: {
      'nombre': nombre,
    }) as Map<String, dynamic>;

    return Especialidad.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<Especialidad> actualizar(int id, {required String nombre}) async {
    final respuesta = await _apiClient.put('/especialidades/$id', body: {
      'nombre': nombre,
    }) as Map<String, dynamic>;

    return Especialidad.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _apiClient.delete('/especialidades/$id');
  }

  /// Especialidades dadas de baja — ver el mismo razonamiento en
  /// `NivelRepository.obtenerEliminados()`.
  Future<List<Especialidad>> obtenerEliminados() async {
    final respuesta = await _apiClient.get('/especialidades/eliminados')
        as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Especialidad.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Especialidad> restaurar(int id) async {
    final respuesta = await _apiClient.patch('/especialidades/$id/restaurar')
        as Map<String, dynamic>;

    return Especialidad.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

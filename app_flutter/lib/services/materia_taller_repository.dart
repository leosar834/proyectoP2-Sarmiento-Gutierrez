import '../models/materia_taller.dart';
import 'api_client.dart';

/// Llamadas contra `/materias-taller` (ver `MateriasTallerController`
/// en el backend, detrás de `permiso:gestionar_sistema`).
///
/// `obtenerEliminados()` es la ÚNICA forma de restaurar una materia
/// borrada — a diferencia de `EspecialidadRepository`, acá no hay
/// atajo "(id X)" al crear, porque `nombre` no tiene restricción de
/// unicidad en el backend (a propósito, ver el docblock de
/// `MateriasTallerController`: dos especialidades distintas pueden
/// compartir el nombre de una materia).
class MateriaTallerRepository {
  MateriaTallerRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MateriaTaller>> obtenerTodos({int? especialidadId}) async {
    final respuesta = await _apiClient.get('/materias-taller', query: {
      if (especialidadId != null) 'especialidad_id': especialidadId,
    }) as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => MateriaTaller.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<MateriaTaller> crear({
    required int? especialidadId,
    required String nombre,
    required String regimenCursada,
  }) async {
    final respuesta = await _apiClient.post('/materias-taller', body: {
      'especialidad_id': especialidadId,
      'nombre': nombre,
      'regimen_cursada': regimenCursada,
    }) as Map<String, dynamic>;

    return MateriaTaller.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<MateriaTaller> actualizar(
    int id, {
    required int? especialidadId,
    required String nombre,
    required String regimenCursada,
  }) async {
    final respuesta = await _apiClient.put('/materias-taller/$id', body: {
      'especialidad_id': especialidadId,
      'nombre': nombre,
      'regimen_cursada': regimenCursada,
    }) as Map<String, dynamic>;

    return MateriaTaller.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// El backend rechaza el borrado si la materia ya tiene grupos de
  /// taller creados (aunque sean de un ciclo cerrado) — el error llega
  /// como `ApiException` normal, la pantalla lo muestra tal cual.
  Future<void> eliminar(int id) async {
    await _apiClient.delete('/materias-taller/$id');
  }

  /// Materias de taller dadas de baja — admite el mismo filtro opcional
  /// por especialidad que `obtenerTodos()`.
  Future<List<MateriaTaller>> obtenerEliminados({int? especialidadId}) async {
    final respuesta = await _apiClient.get('/materias-taller/eliminados', query: {
      if (especialidadId != null) 'especialidad_id': especialidadId,
    }) as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => MateriaTaller.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<MateriaTaller> restaurar(int id) async {
    final respuesta = await _apiClient.patch('/materias-taller/$id/restaurar')
        as Map<String, dynamic>;

    return MateriaTaller.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

import '../models/curso.dart';
import 'api_client.dart';

/// Llamadas contra `/ciclos-lectivos/{ciclo}/cursos` y `/cursos/{curso}`
/// (ver `CursosController` en el backend, detrás de
/// `permiso:gestionar_sistema`). Los cursos siempre están scopeados a
/// un ciclo lectivo puntual — no existe un "listar todos los cursos de
/// todos los ciclos".

class CursoRepository {
  CursoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Curso>> obtenerDeCiclo(int cicloLectivoId) async {
    final respuesta = await _apiClient.get('/ciclos-lectivos/$cicloLectivoId/cursos')
        as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Curso.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Curso> crear({
    required int cicloLectivoId,
    required int nivelId,
    required int divisionId,
    required String turno,
  }) async {
    final respuesta = await _apiClient.post(
      '/ciclos-lectivos/$cicloLectivoId/cursos',
      body: {
        'nivel_id': nivelId,
        'division_id': divisionId,
        'turno': turno,
      },
    ) as Map<String, dynamic>;

    return Curso.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Solo el turno es editable — nivel/división/ciclo son la identidad
  /// del curso, ver el docblock de `ActualizarCursoRequest` en el
  /// backend.
  Future<Curso> actualizarTurno(int id, {required String turno}) async {
    final respuesta = await _apiClient.put('/cursos/$id', body: {
      'turno': turno,
    }) as Map<String, dynamic>;

    return Curso.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _apiClient.delete('/cursos/$id');
  }

  Future<List<Curso>> obtenerEliminadosDeCiclo(int cicloLectivoId) async {
    final respuesta = await _apiClient.get(
      '/ciclos-lectivos/$cicloLectivoId/cursos/eliminados',
    ) as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Curso.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Curso> restaurar(int id) async {
    final respuesta =
        await _apiClient.patch('/cursos/$id/restaurar') as Map<String, dynamic>;

    return Curso.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

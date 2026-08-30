import '../models/grupo_ed_fisica.dart';
import 'api_client.dart';

/// Llamadas contra `/ciclos-lectivos/{ciclo}/grupos-ed-fisica` y
/// `/grupos-ed-fisica/{grupo}` (ver `GruposEdFisicaController` en el
/// backend, detrás de `permiso:gestionar_sistema`). Igual que
/// `GrupoTallerRepository`, siempre scopeado a un ciclo ABIERTO.
class GrupoEdFisicaRepository {
  GrupoEdFisicaRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<GrupoEdFisica>> obtenerDeCiclo(int cicloLectivoId) async {
    final respuesta = await _apiClient
        .get('/ciclos-lectivos/$cicloLectivoId/grupos-ed-fisica') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => GrupoEdFisica.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `profesorId` es obligatorio: la columna es NOT NULL, no existe un
  /// grupo de ed. física sin profesor.
  Future<GrupoEdFisica> crear({
    required int cicloLectivoId,
    required String nombreGrupo,
    required String regimenCursada,
    required int profesorId,
  }) async {
    final respuesta = await _apiClient.post(
      '/ciclos-lectivos/$cicloLectivoId/grupos-ed-fisica',
      body: {
        'nombre_grupo': nombreGrupo,
        'regimen_cursada': regimenCursada,
        'profesor_id': profesorId,
      },
    ) as Map<String, dynamic>;

    return GrupoEdFisica.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// `profesor_id` queda afuera a propósito — cambiarlo es
  /// `asignarProfesor()`, un endpoint aparte.
  Future<GrupoEdFisica> actualizar(
    int id, {
    required String nombreGrupo,
    required String regimenCursada,
  }) async {
    final respuesta = await _apiClient.put('/grupos-ed-fisica/$id', body: {
      'nombre_grupo': nombreGrupo,
      'regimen_cursada': regimenCursada,
    }) as Map<String, dynamic>;

    return GrupoEdFisica.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _apiClient.delete('/grupos-ed-fisica/$id');
  }

  /// Grupos de ed. física dados de baja de este ciclo — mismo patrón
  /// que `GrupoTallerRepository.obtenerEliminadosDeCiclo()`.
  Future<List<GrupoEdFisica>> obtenerEliminadosDeCiclo(int cicloLectivoId) async {
    final respuesta = await _apiClient.get(
      '/ciclos-lectivos/$cicloLectivoId/grupos-ed-fisica/eliminados',
    ) as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => GrupoEdFisica.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<GrupoEdFisica> restaurar(int id) async {
    final respuesta = await _apiClient.patch('/grupos-ed-fisica/$id/restaurar')
        as Map<String, dynamic>;

    return GrupoEdFisica.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Reasigna el profesor de un grupo ya existente (cambio a mitad de
  /// año) — no hay caso "vacío", la columna es NOT NULL.
  Future<GrupoEdFisica> asignarProfesor(int id, {required int profesorId}) async {
    final respuesta = await _apiClient.put('/grupos-ed-fisica/$id/profesor', body: {
      'profesor_id': profesorId,
    }) as Map<String, dynamic>;

    return GrupoEdFisica.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Asignación de alumnos por lote — REEMPLAZA (no acumula) la
  /// membresía de ed. física de cada inscripción encontrada (un
  /// alumno solo puede estar en un grupo de ed. física por ciclo, a
  /// diferencia de taller). Mismas dos formas de elegir a quién que en
  /// `GrupoTallerRepository.asignarLote()`.
  Future<int> asignarLote(
    int id, {
    List<int>? inscripcionIds,
    int? cursoId,
    int? divisionId,
    int? especialidadId,
  }) async {
    final respuesta = await _apiClient.post('/grupos-ed-fisica/$id/asignar-lote', body: {
      if (inscripcionIds != null && inscripcionIds.isNotEmpty)
        'inscripcion_ids': inscripcionIds,
      'curso_id': ?cursoId,
      'division_id': ?divisionId,
      'especialidad_id': ?especialidadId,
    }) as Map<String, dynamic>;

    final datos = respuesta['data'] as Map<String, dynamic>;
    return datos['asignados'] as int;
  }
}

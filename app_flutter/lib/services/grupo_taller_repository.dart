import '../models/grupo_taller.dart';
import 'api_client.dart';

/// Llamadas contra `/ciclos-lectivos/{ciclo}/grupos-taller` y
/// `/grupos-taller/{grupo}` (ver `GruposTallerController` en el
/// backend, detrás de `permiso:gestionar_sistema`). Los grupos de
/// taller siempre están scopeados a un ciclo lectivo ABIERTO — el
/// backend rechaza crear/editar/eliminar/restaurar/asignar sobre un
/// ciclo cerrado.
class GrupoTallerRepository {
  GrupoTallerRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<GrupoTaller>> obtenerDeCiclo(int cicloLectivoId) async {
    final respuesta = await _apiClient
        .get('/ciclos-lectivos/$cicloLectivoId/grupos-taller') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => GrupoTaller.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<GrupoTaller> crear({
    required int cicloLectivoId,
    required int materiaTallerId,
    required int nivelId,
    required String nombreGrupo,
  }) async {
    final respuesta = await _apiClient.post(
      '/ciclos-lectivos/$cicloLectivoId/grupos-taller',
      body: {
        'materia_taller_id': materiaTallerId,
        'nivel_id': nivelId,
        'nombre_grupo': nombreGrupo,
      },
    ) as Map<String, dynamic>;

    return GrupoTaller.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Solo el nombre es editable — materia/nivel/ciclo son la identidad
  /// del grupo, igual que `CursoRepository.actualizarTurno()`.
  Future<GrupoTaller> actualizar(int id, {required String nombreGrupo}) async {
    final respuesta = await _apiClient.put('/grupos-taller/$id', body: {
      'nombre_grupo': nombreGrupo,
    }) as Map<String, dynamic>;

    return GrupoTaller.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// El backend rechaza el borrado si el grupo ya tiene alumnos
  /// asignados.
  Future<void> eliminar(int id) async {
    await _apiClient.delete('/grupos-taller/$id');
  }

  /// Grupos de taller dados de baja de este ciclo — mismo patrón que
  /// `CursoRepository.obtenerEliminadosDeCiclo()`.
  Future<List<GrupoTaller>> obtenerEliminadosDeCiclo(int cicloLectivoId) async {
    final respuesta = await _apiClient.get(
      '/ciclos-lectivos/$cicloLectivoId/grupos-taller/eliminados',
    ) as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => GrupoTaller.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<GrupoTaller> restaurar(int id) async {
    final respuesta = await _apiClient.patch('/grupos-taller/$id/restaurar')
        as Map<String, dynamic>;

    return GrupoTaller.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Reemplaza (sync completo, no acumula) el personal del grupo —
  /// mandar la lista nueva completa cubre agregar, quitar o cambiarle
  /// el rol a alguien. Es la ÚNICA llamada que devuelve `personal`
  /// poblado (ver el docblock de `GrupoTaller.personal`).
  Future<GrupoTaller> asignarUsuarios(
    int id, {
    required List<AsignacionPersonalGrupoTaller> asignaciones,
  }) async {
    final respuesta = await _apiClient.put('/grupos-taller/$id/usuarios', body: {
      'asignaciones': asignaciones
          .map((a) => {'usuario_id': a.usuarioId, 'rol_en_grupo': a.rolEnGrupo})
          .toList(),
    }) as Map<String, dynamic>;

    return GrupoTaller.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Asignación de alumnos por lote — REEMPLAZA la membresía de la
  /// MISMA materia (un alumno puede estar a la vez en un grupo de otra
  /// materia sin perderlo). Dos formas mutuamente excluyentes de
  /// elegir a quién: `inscripcionIds` (selección manual, ej. separar
  /// por sexo) o el filtro amplio (`cursoId`/`divisionId`/
  /// `especialidadId`, todos opcionales y combinables) — si se manda
  /// `inscripcionIds` no vacío, el filtro amplio se ignora. El backend
  /// además restringe siempre al nivel del grupo.
  Future<int> asignarLote(
    int id, {
    List<int>? inscripcionIds,
    int? cursoId,
    int? divisionId,
    int? especialidadId,
  }) async {
    final respuesta = await _apiClient.post('/grupos-taller/$id/asignar-lote', body: {
      if (inscripcionIds != null && inscripcionIds.isNotEmpty)
        'inscripcion_ids': inscripcionIds,
      if (cursoId != null) 'curso_id': cursoId,
      if (divisionId != null) 'division_id': divisionId,
      if (especialidadId != null) 'especialidad_id': especialidadId,
    }) as Map<String, dynamic>;

    final datos = respuesta['data'] as Map<String, dynamic>;
    return datos['asignados'] as int;
  }

  /// Listado de solo lectura de quién está asignado a este grupo — no
  /// modifica nada, para eso está `asignarLote()`.
  Future<List<AlumnoDeGrupoTaller>> obtenerAlumnos(int id) async {
    final respuesta = await _apiClient.get('/grupos-taller/$id/alumnos') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => AlumnoDeGrupoTaller.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Saca a un alumno puntual de este grupo (para corregir un error de
  /// carga), sin tocar sus demás asignaciones ni reemplazar el lote
  /// entero como haría `asignarLote()`. Idempotente del lado del
  /// backend — desasignar a alguien que ya no está no es un error.
  Future<void> desasignarAlumno(int id, int inscripcionId) async {
    await _apiClient.delete('/grupos-taller/$id/alumnos/$inscripcionId');
  }
}

/// Un par (usuario, rol) tal como lo espera
/// `AsignarUsuariosGrupoTallerRequest` — `rolEnGrupo` es 'profesor' o
/// 'preceptor_taller'.
class AsignacionPersonalGrupoTaller {
  const AsignacionPersonalGrupoTaller({
    required this.usuarioId,
    required this.rolEnGrupo,
  });

  final int usuarioId;
  final String rolEnGrupo;
}

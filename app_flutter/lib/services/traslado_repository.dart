import 'api_client.dart';

/// Llamadas contra `POST /ciclos-lectivos/{ciclo}/traslados` y
/// `PUT /inscripciones/{inscripcion}/dar-de-baja` (ver
/// `TrasladosController` en el backend) — asignar/mover a un alumno de
/// curso dentro del ciclo abierto (recursantes, cambios de división,
/// regreso de egresados), y dar de baja una inscripción puntual a mitad
/// de año sin tocar el legajo.
///
/// `especialidad_id` no se expone todavía en `trasladar()` — la
/// pantalla de "Especialidades" es un desarrollo aparte, pendiente; si
/// no se manda, el backend hereda la especialidad ya asignada al
/// alumno (si tiene una), así que omitirla acá es seguro.
class TrasladoRepository {
  TrasladoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> trasladar({
    required int cicloLectivoId,
    required int alumnoId,
    required int cursoId,
    required String condicion,
  }) async {
    await _apiClient.post('/ciclos-lectivos/$cicloLectivoId/traslados', body: {
      'alumno_id': alumnoId,
      'curso_id': cursoId,
      'condicion': condicion,
    });
  }

  Future<void> darDeBaja(
    int inscripcionId, {
    required String motivoBaja,
    String? fechaBaja,
  }) async {
    await _apiClient.put('/inscripciones/$inscripcionId/dar-de-baja', body: {
      'motivo_baja': motivoBaja,
      'fecha_baja': fechaBaja,
    });
  }
}

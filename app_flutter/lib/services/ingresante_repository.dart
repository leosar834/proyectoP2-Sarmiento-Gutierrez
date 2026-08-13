import 'api_client.dart';

/// Llamada contra `POST /ciclos-lectivos/{ciclo}/ingresantes` (ver
/// `IngresantesController` en el backend) — el alta más común de un
/// alumno: crea legajo + inscripción en un curso de PRIMER año del
/// ciclo indicado, en un solo paso. Para un alumno que entra directo a
/// un año superior (pase), ver `AlumnoRepository.crear()` en su lugar.

class IngresanteRepository {
  IngresanteRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> crear({
    required int cicloLectivoId,
    required String nombre,
    required String apellido,
    required String dni,
    String? fechaNacimiento,
    required String fechaIngresoInstitucion,
    required int cursoId,
  }) async {
    await _apiClient.post('/ciclos-lectivos/$cicloLectivoId/ingresantes', body: {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'fecha_nacimiento': fechaNacimiento,
      'fecha_ingreso_institucion': fechaIngresoInstitucion,
      'curso_id': cursoId,
    });
  }
}

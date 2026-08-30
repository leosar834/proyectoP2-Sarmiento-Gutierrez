import '../models/alumno.dart';
import '../models/alumno_detalle.dart';
import 'api_client.dart';

/// Llamadas contra `/alumnos` (ver `AlumnosController` en el backend,
/// detrás de `permiso:gestionar_sistema`). Esto es SOLO el legajo —
/// asignar un curso es una operación aparte (`IngresanteRepository` /
/// `TrasladoRepository`), ver el docblock del controller.

class AlumnoRepository {
  AlumnoRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Alumno>> obtenerTodos({String? busqueda, int? cursoId}) async {
    final respuesta = await _apiClient.get('/alumnos', query: {
      if (busqueda != null && busqueda.isNotEmpty) 'busqueda': busqueda,
      'curso_id': ?cursoId,
    }) as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Alumno.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<AlumnoDetalle> obtener(int id) async {
    final respuesta =
        await _apiClient.get('/alumnos/$id') as Map<String, dynamic>;
    return AlumnoDetalle.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  /// Da de alta SOLO el legajo, sin curso — para un alumno que entra
  /// directo a un año superior (ej. un pase de otra institución). El
  /// caso más común (ingresante nuevo de 1er año) usa
  /// `IngresanteRepository.crear()` en su lugar, que crea legajo +
  /// inscripción en un solo paso.
  Future<Alumno> crear({
    required String nombre,
    required String apellido,
    required String dni,
    String? fechaNacimiento,
    required String fechaIngresoInstitucion,
  }) async {
    final respuesta = await _apiClient.post('/alumnos', body: {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'fecha_nacimiento': fechaNacimiento,
      'fecha_ingreso_institucion': fechaIngresoInstitucion,
    }) as Map<String, dynamic>;

    return Alumno.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<Alumno> actualizar(
    int id, {
    required String nombre,
    required String apellido,
    required String dni,
    String? fechaNacimiento,
    required String fechaIngresoInstitucion,
  }) async {
    final respuesta = await _apiClient.put('/alumnos/$id', body: {
      'nombre': nombre,
      'apellido': apellido,
      'dni': dni,
      'fecha_nacimiento': fechaNacimiento,
      'fecha_ingreso_institucion': fechaIngresoInstitucion,
    }) as Map<String, dynamic>;

    return Alumno.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<void> eliminar(int id) async {
    await _apiClient.delete('/alumnos/$id');
  }

  /// Legajos dados de baja — mismo patrón que `UsuarioRepository.
  /// obtenerEliminados()`.
  Future<List<Alumno>> obtenerEliminados() async {
    final respuesta =
        await _apiClient.get('/alumnos/eliminados') as Map<String, dynamic>;
    final datos = respuesta['data'] as List<dynamic>;
    return datos
        .map((item) => Alumno.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Alumno> restaurar(int id) async {
    final respuesta = await _apiClient.patch('/alumnos/$id/restaurar')
        as Map<String, dynamic>;

    return Alumno.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

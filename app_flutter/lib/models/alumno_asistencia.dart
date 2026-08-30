/// Espejo de cada fila de `AsistenciaController::alumnos()` (`GET
/// /planillas/{id}/alumnos`) — un alumno inscripto activo del curso,
/// con el estado que ya tenga cargado para la planilla de hoy (`null`
/// si todavía no se marcó nada). Es la fuente de la grilla de "tomar
/// asistencia"; el estado que el usuario va tocando en pantalla se
/// guarda aparte, en un `Map<inscripcionId, estado>` dentro del propio
/// `State` de la pantalla — este modelo no cambia una vez cargado, solo
/// trae los datos fijos del alumno + el valor con el que arrancó.
class AlumnoAsistencia {
  const AlumnoAsistencia({
    required this.inscripcionId,
    required this.idAlumno,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.estadoInicial,
  });

  factory AlumnoAsistencia.fromJson(Map<String, dynamic> json) {
    final alumno = json['alumno'] as Map<String, dynamic>;
    return AlumnoAsistencia(
      inscripcionId: json['inscripcion_id'] as int,
      idAlumno: alumno['id_alumno'] as int,
      nombre: alumno['nombre'] as String,
      apellido: alumno['apellido'] as String,
      dni: alumno['dni'] as String,
      estadoInicial: json['estado'] as String?,
    );
  }

  final int inscripcionId;
  final int idAlumno;
  final String nombre;
  final String apellido;
  final String dni;

  /// 'presente' | 'ausente' | 'tardanza' | 'falta_justificada' | null.
  final String? estadoInicial;

  String get nombreCompleto => '$apellido, $nombre';
}

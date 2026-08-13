/// Espejo de lo que devuelve `AlumnosController` (backend-laravel) — el
/// legajo permanente de un alumno (nombre, apellido, DNI, fechas). No
/// confundir con la inscripción (`InscripcionResumen`): el legajo es la
/// identidad de la persona, la inscripción es su vínculo con un curso
/// en un ciclo lectivo puntual — ver `App\Models\Alumno` en el backend.
class Alumno {
  const Alumno({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.fechaNacimiento,
    required this.fechaIngresoInstitucion,
    required this.inscripcionActual,
  });

  factory Alumno.fromJson(Map<String, dynamic> json) {
    final inscripcionJson = json['inscripcion_actual'] as Map<String, dynamic>?;
    return Alumno(
      id: json['id_alumno'] as int,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      dni: json['dni'] as String,
      fechaNacimiento: json['fecha_nacimiento'] as String?,
      fechaIngresoInstitucion: json['fecha_ingreso_institucion'] as String?,
      // Null también cuando el backend ni siquiera manda la clave (ver
      // `AlumnosController::formatearLegajo` — solo va en `index()`).
      inscripcionActual:
          inscripcionJson == null ? null : InscripcionResumen.fromJson(inscripcionJson),
    );
  }

  final int id;
  final String nombre;
  final String apellido;
  final String dni;
  final String? fechaNacimiento;
  final String? fechaIngresoInstitucion;

  /// La inscripción de este alumno en el ciclo lectivo ABIERTO, si
  /// tiene una — null tanto si nunca tuvo curso asignado como si su
  /// única inscripción es de un ciclo ya cerrado.
  final InscripcionResumen? inscripcionActual;

  String get nombreCompleto => '$apellido, $nombre';
}

/// Versión resumida de una inscripción, tal como viene anidada dentro
/// de un `Alumno` (`inscripcion_actual`) — para el historial completo
/// (todos los ciclos) ver `InscripcionHistorial` en alumno_detalle.dart.
class InscripcionResumen {
  const InscripcionResumen({
    required this.id,
    required this.cursoId,
    required this.curso,
    required this.condicion,
    required this.estado,
  });

  factory InscripcionResumen.fromJson(Map<String, dynamic> json) {
    return InscripcionResumen(
      id: json['id_inscripcion'] as int,
      cursoId: json['curso_id'] as int,
      curso: json['curso'] as String?,
      condicion: json['condicion'] as String,
      estado: json['estado'] as String,
    );
  }

  final int id;
  final int cursoId;
  final String? curso;

  /// 'regular' | 'recursante'.
  final String condicion;

  /// 'activo' | 'baja' | 'egresado' | 'pendiente_asignacion' (ver
  /// `App\Models\Inscripcion` en el backend).
  final String estado;
}

import 'alumno.dart';

/// Espejo de lo que devuelve `AlumnosController::mostrar()` —el legajo
/// completo más el historial de TODAS sus inscripciones (una por ciclo
/// lectivo). Se pide aparte del listado (`Alumno`, más liviano) porque
/// solo hace falta al abrir el detalle de un alumno puntual, por
/// ejemplo antes de decidir un traslado.
class AlumnoDetalle {
  const AlumnoDetalle({required this.alumno, required this.historial});

  factory AlumnoDetalle.fromJson(Map<String, dynamic> json) {
    final historialJson = json['inscripciones'] as List<dynamic>? ?? const [];
    return AlumnoDetalle(
      alumno: Alumno.fromJson(json),
      historial: historialJson
          .map((item) => InscripcionHistorial.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final Alumno alumno;
  final List<InscripcionHistorial> historial;
}

/// Una fila del historial completo de inscripciones de un alumno —
/// incluye el año del ciclo y la especialidad, que `InscripcionResumen`
/// (la del listado general) no necesita.
class InscripcionHistorial {
  const InscripcionHistorial({
    required this.id,
    required this.cicloLectivoId,
    required this.cicloAnio,
    required this.cursoId,
    required this.curso,
    required this.especialidadNombre,
    required this.condicion,
    required this.estado,
  });

  factory InscripcionHistorial.fromJson(Map<String, dynamic> json) {
    return InscripcionHistorial(
      id: json['id_inscripcion'] as int,
      cicloLectivoId: json['ciclo_lectivo_id'] as int,
      cicloAnio: json['ciclo_anio'] as int?,
      cursoId: json['curso_id'] as int?,
      curso: json['curso'] as String?,
      especialidadNombre: json['especialidad_nombre'] as String?,
      condicion: json['condicion'] as String,
      estado: json['estado'] as String,
    );
  }

  final int id;
  final int cicloLectivoId;
  final int? cicloAnio;
  final int? cursoId;
  final String? curso;
  final String? especialidadNombre;
  final String condicion;
  final String estado;
}

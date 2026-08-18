/// Espejo de lo que devuelve `GruposTallerController` (backend-laravel)
/// — un grupo de taller del ciclo lectivo abierto, propio de una
/// materia Y un nivel puntuales (un alumno puede estar en varios
/// grupos de taller a la vez, uno por cada materia que cursa). Ver
/// `App\Models\GrupoTaller` en el backend.
///
/// `personal` es distinto de los demás campos: el backend NUNCA lo
/// manda en `index()`/`crear()` (solo cuenta con `alumnosAsignados`),
/// únicamente viene poblado en la respuesta de
/// `GrupoTallerRepository.asignarUsuarios()` — por eso acá es nullable
/// y arranca en `null` ("todavía no se consultó/asignó en esta
/// sesión"), no en lista vacía ("no tiene personal"). La pantalla debe
/// guardar en memoria el último valor conocido, no asumir que `null`
/// significa "sin personal".
class GrupoTaller {
  const GrupoTaller({
    required this.id,
    required this.cicloLectivoId,
    required this.materiaTallerId,
    required this.nivelId,
    required this.nombreGrupo,
    required this.alumnosAsignados,
    this.personal,
  });

  factory GrupoTaller.fromJson(Map<String, dynamic> json) {
    final personalJson = json['personal'] as List<dynamic>?;
    return GrupoTaller(
      id: json['id_grupo_taller'] as int,
      cicloLectivoId: json['ciclo_lectivo_id'] as int,
      materiaTallerId: json['materia_taller_id'] as int,
      nivelId: json['nivel_id'] as int,
      nombreGrupo: json['nombre_grupo'] as String,
      alumnosAsignados: json['alumnos_asignados'] as int? ?? 0,
      personal: personalJson
          ?.map((item) => PersonalGrupo.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final int id;
  final int cicloLectivoId;
  final int materiaTallerId;
  final int nivelId;
  final String nombreGrupo;
  final int alumnosAsignados;
  final List<PersonalGrupo>? personal;

  GrupoTaller copyWith({List<PersonalGrupo>? personal}) {
    return GrupoTaller(
      id: id,
      cicloLectivoId: cicloLectivoId,
      materiaTallerId: materiaTallerId,
      nivelId: nivelId,
      nombreGrupo: nombreGrupo,
      alumnosAsignados: alumnosAsignados,
      personal: personal ?? this.personal,
    );
  }
}

/// Un profesor o preceptor de taller asignado a un `GrupoTaller`, tal
/// como viene anidado en la respuesta de `asignarUsuarios()`.
class PersonalGrupo {
  const PersonalGrupo({
    required this.usuarioId,
    required this.nombre,
    required this.apellido,
    required this.rolEnGrupo,
  });

  factory PersonalGrupo.fromJson(Map<String, dynamic> json) {
    return PersonalGrupo(
      usuarioId: json['id_usuario'] as int,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      rolEnGrupo: json['rol_en_grupo'] as String,
    );
  }

  final int usuarioId;
  final String nombre;
  final String apellido;

  /// 'profesor' | 'preceptor_taller'.
  final String rolEnGrupo;

  String get nombreCompleto => '$apellido, $nombre';
}

/// Un alumno asignado a un `GrupoTaller`, tal como viene en la respuesta
/// de `GrupoTallerRepository.obtenerAlumnos()` — de solo lectura, no
/// reemplaza `asignarLote()` para modificar la membresía.
class AlumnoDeGrupoTaller {
  const AlumnoDeGrupoTaller({
    required this.inscripcionId,
    required this.alumnoId,
    required this.nombre,
    required this.apellido,
    required this.dni,
    required this.cursoDivision,
  });

  factory AlumnoDeGrupoTaller.fromJson(Map<String, dynamic> json) {
    final alumno = json['alumno'] as Map<String, dynamic>;
    return AlumnoDeGrupoTaller(
      inscripcionId: json['id_inscripcion'] as int,
      alumnoId: alumno['id_alumno'] as int,
      nombre: alumno['nombre'] as String,
      apellido: alumno['apellido'] as String,
      dni: alumno['dni'] as String,
      cursoDivision: json['curso_division'] as String?,
    );
  }

  final int inscripcionId;
  final int alumnoId;
  final String nombre;
  final String apellido;
  final String dni;

  /// División del curso de origen (ej. "1a") — un grupo de taller junta
  /// alumnos de varias divisiones del mismo nivel (`asignarLote()` solo
  /// exige que compartan nivel, no división), así que hace falta para
  /// distinguirlos en la lista. Puede ser null si el curso de origen ya
  /// no existe.
  final String? cursoDivision;

  String get nombreCompleto => '$apellido, $nombre';
}

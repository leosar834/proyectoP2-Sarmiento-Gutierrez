/// Espejo de `AsignacionesController::index()` (`GET
/// /mis-asignaciones`) — "qué curso o grupos son míos", del ciclo
/// lectivo abierto. Cubre las tres áreas (`teorica`/`taller`/`ed_fisica`)
/// aunque por ahora, del lado de la pantalla de tomar asistencia, solo
/// se usan las de `area == 'teorica'` — ver el docblock de
/// `MisAsignacionesScreen`.
class Asignacion {
  const Asignacion({
    required this.area,
    required this.id,
    required this.etiqueta,
    this.rolEnGrupo,
  });

  factory Asignacion.fromJson(Map<String, dynamic> json) {
    return Asignacion(
      area: json['area'] as String,
      id: json['id'] as int,
      etiqueta: json['etiqueta'] as String,
      rolEnGrupo: json['rol_en_grupo'] as String?,
    );
  }

  /// 'teorica' | 'taller' | 'ed_fisica'.
  final String area;

  /// El id del curso/grupo, según `area` (no hay una FK unificada del
  /// lado del backend — por eso viaja junto con `area` en vez de tres
  /// campos separados, la mayoría en `null`).
  final int id;

  final String etiqueta;

  /// Solo presente para `area == 'taller'` ('profesor' | 'preceptor_taller').
  final String? rolEnGrupo;

  bool get esTeorica => area == 'teorica';
}

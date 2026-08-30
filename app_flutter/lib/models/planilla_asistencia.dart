/// Espejo (parcial) de `PlanillaAsistenciaResource` — la cabecera de
/// asistencia de un curso/grupo en una fecha. No mapea `detalles` acá:
/// la grilla de alumnos se pide aparte, con su propio estado ya
/// combinado, vía `GET /planillas/{id}/alumnos` (ver `AlumnoAsistencia`)
/// — más simple que mantener dos copias de la misma lista sincronizadas.
class PlanillaAsistencia {
  const PlanillaAsistencia({
    required this.idPlanilla,
    required this.area,
    required this.grupo,
    required this.fecha,
    required this.estado,
  });

  factory PlanillaAsistencia.fromJson(Map<String, dynamic> json) {
    return PlanillaAsistencia(
      idPlanilla: json['id_planilla'] as int,
      area: json['area'] as String,
      grupo: json['grupo'] as String?,
      fecha: json['fecha'] as String,
      estado: json['estado'] as String,
    );
  }

  final int idPlanilla;
  final String area;
  final String? grupo;
  final String fecha;

  /// 'en_curso' | 'bloqueada' — para `area == 'teorica'` en la práctica
  /// siempre queda en 'en_curso' (ver el docblock de
  /// `AsistenciaController::enviar()`: solo taller pasa por ese envío).
  final String estado;
}

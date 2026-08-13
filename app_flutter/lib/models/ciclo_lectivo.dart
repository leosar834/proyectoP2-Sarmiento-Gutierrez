/// Espejo de lo que devuelve `CiclosLectivosController` (backend-laravel)
/// — el ciclo lectivo (el año) del que cuelga todo lo transaccional del
/// sistema: cursos, grupos, inscripciones y asistencia. Ver
/// `App\Models\CicloLectivo` en el backend.
class CicloLectivo {
  const CicloLectivo({
    required this.id,
    required this.anio,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    required this.fechaCierre,
  });

  factory CicloLectivo.fromJson(Map<String, dynamic> json) {
    return CicloLectivo(
      id: json['id_ciclo_lectivo'] as int,
      anio: json['anio'] as int,
      fechaInicio: json['fecha_inicio'] as String?,
      fechaFin: json['fecha_fin'] as String?,
      estado: json['estado'] as String,
      fechaCierre: json['fecha_cierre'] as String?,
    );
  }

  final int id;
  final int anio;
  final String? fechaInicio;
  final String? fechaFin;

  /// 'abierto' | 'cerrado'.
  final String estado;
  final String? fechaCierre;

  bool get abierto => estado == 'abierto';
}

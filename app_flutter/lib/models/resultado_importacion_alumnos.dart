/// Una fila del Excel procesada por `AlumnosImport` (ver
/// `ImportacionAlumnosController::importar()`), ya sea que haya
/// terminado creando el alumno o salteándose por algún motivo.
class FilaImportacion {
  const FilaImportacion({
    required this.fila,
    required this.estado,
    required this.motivo,
    required this.alumno,
  });

  factory FilaImportacion.fromJson(Map<String, dynamic> json) {
    return FilaImportacion(
      fila: json['fila'] as int,
      estado: json['estado'] as String,
      motivo: json['motivo'] as String?,
      alumno: json['alumno'] as String?,
    );
  }

  /// Número de fila tal cual está en el Excel (contando el encabezado),
  /// para que quien lo lea pueda ubicarla directo en su propio archivo.
  final int fila;

  /// 'creado' | 'salteado'.
  final String estado;

  /// Motivo del salteo — `null` cuando `estado == 'creado'`.
  final String? motivo;

  /// "Apellido, Nombre (DNI ...)" — `null` cuando `estado == 'salteado'`.
  final String? alumno;

  bool get creado => estado == 'creado';
}

/// Espejo de `ImportacionAlumnosController::importar()` — el resumen
/// completo de una importación: cuántas filas se crearon, cuántas se
/// saltearon, y el detalle fila por fila para poder mostrarlo entero
/// (no solo el conteo) y que la institución sepa exactamente qué
/// corregir en su Excel antes de volver a subirlo.
class ResultadoImportacionAlumnos {
  const ResultadoImportacionAlumnos({
    required this.creados,
    required this.salteados,
    required this.detalle,
  });

  factory ResultadoImportacionAlumnos.fromJson(Map<String, dynamic> json) {
    final lista = json['detalle'] as List;
    return ResultadoImportacionAlumnos(
      creados: json['creados'] as int,
      salteados: json['salteados'] as int,
      detalle: lista
          .map((item) => FilaImportacion.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final int creados;
  final int salteados;
  final List<FilaImportacion> detalle;
}

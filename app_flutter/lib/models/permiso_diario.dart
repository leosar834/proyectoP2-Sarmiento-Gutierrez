/// Espejo de lo que devuelve `PermisosDiariosController::formatear()` en
/// el backend (`GET/POST/PATCH /permisos-diarios/...`) — el permiso para
/// tomar asistencia de un día puntual. Ver `App\Models\PermisoDiario`
/// para las reglas: la apertura es manual (jefa de preceptores/admin,
/// desde esta misma pantalla), el cierre normal es automático al pasar
/// `horaLimite`, y `cerradoManual` es solo el cierre anticipado explícito.
class PermisoDiario {
  const PermisoDiario({
    required this.idPermisoDiario,
    required this.fecha,
    required this.usuarioAperturaId,
    required this.horaApertura,
    required this.horaLimite,
    required this.cerradoManual,
  });

  factory PermisoDiario.fromJson(Map<String, dynamic> json) {
    return PermisoDiario(
      idPermisoDiario: json['id_permiso_diario'] as int,
      fecha: json['fecha'] as String,
      usuarioAperturaId: json['usuario_apertura_id'] as int,
      horaApertura: json['hora_apertura'] as String,
      horaLimite: json['hora_limite'] as String,
      cerradoManual: json['cerrado_manual'] as bool,
    );
  }

  /// 'YYYY-MM-DD'.
  final String fecha;

  final int idPermisoDiario;
  final int usuarioAperturaId;

  /// 'YYYY-MM-DD HH:mm:ss' (tal cual la arma `toDateTimeString()` del
  /// lado de Laravel).
  final String horaApertura;

  /// 'HH:mm:ss' — columna TIME de MySQL, sin cast de fecha del lado del
  /// backend, así que llega tal cual.
  final String horaLimite;

  final bool cerradoManual;

  /// 'HH:mm', para mostrar sin los segundos.
  String get horaAperturaCorta =>
      horaApertura.length >= 16 ? horaApertura.substring(11, 16) : horaApertura;

  String get horaLimiteCorta =>
      horaLimite.length >= 5 ? horaLimite.substring(0, 5) : horaLimite;
}

/// Espejo de `PermisosDiariosController::hoy()` — el estado del día para
/// que la pantalla no tenga que "adivinar" nada: si hoy no se abrió
/// ningún permiso todavía, `permiso` es `null` y `abierto` es `false`.
class EstadoPermisoDiario {
  const EstadoPermisoDiario({required this.abierto, required this.permiso});

  factory EstadoPermisoDiario.fromJson(Map<String, dynamic> json) {
    final permisoJson = json['permiso'] as Map<String, dynamic>?;
    return EstadoPermisoDiario(
      abierto: json['abierto'] as bool,
      permiso: permisoJson == null ? null : PermisoDiario.fromJson(permisoJson),
    );
  }

  final bool abierto;
  final PermisoDiario? permiso;
}

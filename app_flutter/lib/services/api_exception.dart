/// Excepción para cualquier respuesta no-2xx del backend. Distingue los
/// casos que la UI necesita tratar distinto:
///
/// - 401 (no autenticado / token inválido o vencido — ver el fix del
///   backend en bootstrap/app.php): la sesión ya no sirve, hay que
///   mandar al usuario de vuelta al login.
/// - 403 (plataforma o permiso no habilitado — VerificarPermiso): la
///   sesión sigue siendo válida, pero esta acción puntual no está
///   permitida.
/// - 422 (validación — Laravel `ValidationException`): `errors` trae el
///   detalle campo por campo tal cual lo arma Laravel
///   (`{"campo": ["mensaje1", "mensaje2"]}`), para mostrarlo en el
///   formulario correspondiente.
/// - Cualquier otro código, o error de red/parseo: `mensaje` es lo único
///   confiable para mostrar.
class ApiException implements Exception {
  ApiException({
    required this.mensaje,
    this.statusCode,
    this.errors,
  });

  /// Error de red (sin conexión, timeout, host inalcanzable) — no hay
  /// `statusCode` porque el pedido nunca llegó a completarse.
  factory ApiException.red([String? detalle]) {
    return ApiException(
      mensaje: detalle ??
          'No se pudo conectar con el servidor. Verificá tu conexión y que '
              'el backend esté corriendo.',
    );
  }

  final String mensaje;
  final int? statusCode;
  final Map<String, List<String>>? errors;

  bool get esNoAutenticado => statusCode == 401;
  bool get esPermisoDenegado => statusCode == 403;
  bool get esValidacion => statusCode == 422;

  /// Primer mensaje de error para un campo puntual, si `esValidacion`.
  String? errorDeCampo(String campo) => errors?[campo]?.first;

  @override
  String toString() => 'ApiException($statusCode): $mensaje';
}

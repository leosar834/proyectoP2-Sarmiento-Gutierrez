import 'package:flutter/foundation.dart';

import '../models/usuario.dart';
import '../services/api_client.dart';
import '../services/api_exception.dart';
import '../services/auth_repository.dart';
import '../services/session_storage.dart';

/// - `desconocido`: todavía no se terminó de chequear si hay una sesión
///   guardada (estado inicial, mientras dura `cargarSesionGuardada()`).
/// - `autenticando`: hay un login en curso (para poder deshabilitar el
///   botón/mostrar loading en la futura pantalla de login).
/// - `autenticado` / `noAutenticado`: resultado final, ya estable.
enum AuthStatus { desconocido, autenticando, autenticado, noAutenticado }

/// Estado de sesión de toda la app — un solo `AuthProvider` vive arriba
/// de todo en `main.dart` (`ChangeNotifierProvider`), y cualquier
/// pantalla/servicio que necesite el usuario logueado, la plataforma
/// actual, o el `ApiClient` ya autenticado, lo consigue de acá (vía
/// `context.watch<AuthProvider>()` o `context.read<AuthProvider>()`)
/// en vez de pasarlo a mano por los constructores.
///
/// El `ApiClient` vive DENTRO de este provider (no al revés) porque el
/// token que usa depende directamente del estado de sesión — no tiene
/// sentido que existan por separado y haya que mantenerlos sincronizados
/// desde afuera.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    ApiClient? apiClient,
    AuthRepository? authRepository,
    SessionStorage? sessionStorage,
  })  : apiClient = apiClient ?? ApiClient(),
        _sessionStorage = sessionStorage ?? SessionStorage() {
    _authRepository = authRepository ?? AuthRepository(this.apiClient);
  }

  final ApiClient apiClient;
  late final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;

  AuthStatus _status = AuthStatus.desconocido;
  Usuario? _usuario;
  String? _plataforma;

  AuthStatus get status => _status;
  Usuario? get usuario => _usuario;

  /// `'movil'` o `'escritorio'` — la plataforma con la que se selló el
  /// token actual. Null si no hay sesión.
  String? get plataforma => _plataforma;

  bool get estaAutenticado => _status == AuthStatus.autenticado;

  /// Se llama una sola vez, al arrancar la app (ver `SplashScreen`).
  /// Si hay una sesión guardada la deja usable de entrada (con los datos
  /// cacheados) y, en paralelo, la valida contra `GET /me` — si el token
  /// ya no sirve (vencido, revocado), cae a `noAutenticado` sin que la
  /// pantalla de splash tenga que saber nada de esa lógica.
  Future<void> cargarSesionGuardada() async {
    final sesion = await _sessionStorage.leer();

    if (sesion == null) {
      _status = AuthStatus.noAutenticado;
      notifyListeners();
      return;
    }

    apiClient.setToken(sesion.token);
    _usuario = sesion.usuario;
    _plataforma = sesion.plataforma;
    _status = AuthStatus.autenticado;
    notifyListeners();

    try {
      _usuario = await _authRepository.me();
      notifyListeners();
    } on ApiException catch (error) {
      if (error.esNoAutenticado) {
        await _limpiarSesion();
      }
      // Otros errores (sin red, servidor caído) no cierran la sesión
      // local — se sigue usando el usuario cacheado hasta que se pueda
      // volver a validar.
    }
  }

  /// Lanza `ApiException` si falla (credenciales inválidas, usuario
  /// desactivado, sin conexión, etc.) — la pantalla de login la captura
  /// para mostrar el error correspondiente.
  Future<void> login({
    required String email,
    required String password,
    required String plataforma,
  }) async {
    _status = AuthStatus.autenticando;
    notifyListeners();

    try {
      final resultado = await _authRepository.login(
        email: email,
        password: password,
        plataforma: plataforma,
      );
      await _aplicarResultadoAutenticado(resultado);
    } catch (_) {
      _status = AuthStatus.noAutenticado;
      notifyListeners();
      rethrow;
    }
  }

  /// Alta del primer administrador (ver `AuthRepository.registrarAdministrador`).
  /// Mismo manejo de estado/errores que `login()` — el backend deja al
  /// usuario ya logueado, así que un alta exitosa termina exactamente
  /// igual que un login exitoso. Incluye los datos de la institución
  /// (nombre, domicilio, CUE, localidad, provincia): el backend los
  /// exige desde este mismo alta, no hay paso separado.
  Future<void> registrarAdministrador({
    required String nombre,
    required String apellido,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String institucionNombre,
    required String institucionDomicilio,
    required String institucionCue,
    required String institucionLocalidad,
    required String institucionProvincia,
  }) async {
    _status = AuthStatus.autenticando;
    notifyListeners();

    try {
      final resultado = await _authRepository.registrarAdministrador(
        nombre: nombre,
        apellido: apellido,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
        institucionNombre: institucionNombre,
        institucionDomicilio: institucionDomicilio,
        institucionCue: institucionCue,
        institucionLocalidad: institucionLocalidad,
        institucionProvincia: institucionProvincia,
      );
      await _aplicarResultadoAutenticado(resultado);
    } catch (_) {
      _status = AuthStatus.noAutenticado;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _aplicarResultadoAutenticado(ResultadoLogin resultado) async {
    apiClient.setToken(resultado.token);
    await _sessionStorage.guardar(
      token: resultado.token,
      plataforma: resultado.plataforma,
      usuario: resultado.usuario,
    );

    _usuario = resultado.usuario;
    _plataforma = resultado.plataforma;
    _status = AuthStatus.autenticado;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } on ApiException {
      // Best-effort: si el logout del lado del servidor falla (sin red,
      // token ya vencido) igual se cierra la sesión local — desde el
      // punto de vista de quien usa la app, "cerrar sesión" siempre
      // tiene que funcionar.
    }

    await _limpiarSesion();
  }

  Future<void> _limpiarSesion() async {
    apiClient.setToken(null);
    await _sessionStorage.limpiar();
    _usuario = null;
    _plataforma = null;
    _status = AuthStatus.noAutenticado;
    notifyListeners();
  }
}

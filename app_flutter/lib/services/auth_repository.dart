import '../models/usuario.dart';
import 'api_client.dart';

/// Resultado de un login exitoso — ver `AuthController::login()` del
/// backend, que devuelve exactamente estos tres campos.
class ResultadoLogin {
  const ResultadoLogin({
    required this.token,
    required this.plataforma,
    required this.usuario,
  });

  final String token;
  final String plataforma;
  final Usuario usuario;
}

/// Llamadas de auth contra el backend (`POST /login`, `POST /logout`,
/// `GET /me`). No sabe nada de `SharedPreferences`/storage ni de
/// `ChangeNotifier` — eso es responsabilidad de `AuthProvider`, que es
/// quien orquesta este repositorio + `SessionStorage`.
class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  /// `plataforma` tiene que ser `'movil'` o `'escritorio'` — el backend
  /// la valida (`LoginRequest`) y la sella en el token; ver el docblock
  /// de `ApiConfig` y de `AuthProvider` para el resto del contrato.
  Future<ResultadoLogin> login({
    required String email,
    required String password,
    required String plataforma,
  }) async {
    final respuesta = await _apiClient.post('/login', body: {
      'email': email,
      'password': password,
      'plataforma': plataforma,
    }) as Map<String, dynamic>;

    return ResultadoLogin(
      token: respuesta['token'] as String,
      plataforma: respuesta['plataforma'] as String,
      usuario: Usuario.fromJson(respuesta['usuario'] as Map<String, dynamic>),
    );
  }

  /// Alta pública del primer administrador (`POST /registro-administrador`
  /// — ver `RegistroAdministradorController`). Devuelve exactamente la
  /// misma forma que `login()` (token + plataforma + usuario, siempre
  /// `'escritorio'`): el backend deja al administrador recién creado ya
  /// logueado, sin que tenga que volver a escribir sus credenciales.
  ///
  /// Los datos de `institucion*` viajan anidados bajo la clave
  /// `institucion` — el backend los usa para crear, en la misma
  /// transacción, la ficha de la institución (ver
  /// `RegistroAdministradorRequest`/`App\Models\Institucion`). No hay
  /// paso de alta de institución aparte: se piden acá mismo.
  Future<ResultadoLogin> registrarAdministrador({
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
    final respuesta = await _apiClient.post('/registro-administrador', body: {
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'institucion': {
        'nombre': institucionNombre,
        'domicilio': institucionDomicilio,
        'cue': institucionCue,
        'localidad': institucionLocalidad,
        'provincia': institucionProvincia,
      },
    }) as Map<String, dynamic>;

    return ResultadoLogin(
      token: respuesta['token'] as String,
      plataforma: respuesta['plataforma'] as String,
      usuario: Usuario.fromJson(respuesta['usuario'] as Map<String, dynamic>),
    );
  }

  /// Invalida el token del lado del servidor. Si falla (ej. sin
  /// conexión), quien llama igual debe limpiar la sesión local — un
  /// logout tiene que "funcionar" siempre desde el punto de vista del
  /// usuario, aunque el token quede vivo en el servidor hasta que
  /// expire o se lo revoque manualmente.
  Future<void> logout() async {
    await _apiClient.post('/logout');
  }

  Future<Usuario> me() async {
    final respuesta = await _apiClient.get('/me') as Map<String, dynamic>;
    return Usuario.fromJson(respuesta);
  }
}

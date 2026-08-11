import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Resuelve la URL base del backend (`backend-laravel`, corriendo local
/// con `php artisan serve` en el puerto 8000) según dónde se está
/// ejecutando la app — ver guia_setup_flutter.md, sección 5.
///
/// - Emulador Android: el emulador ve a la PC anfitriona como `10.0.2.2`,
///   no como `127.0.0.1`.
/// - Chrome / Windows desktop / iOS simulator / macOS: `127.0.0.1` sirve
///   directo, porque corren en la misma máquina que el backend.
/// - Dispositivo físico en la misma red que el backend: ninguno de los
///   dos anteriores sirve — hace falta la IP de la PC en la red local.
///   No hay forma de adivinar eso desde acá, así que se cubre con
///   `--dart-define=API_BASE_URL=http://<ip-de-tu-pc>:8000/api` al
///   correr `flutter run` (ver ejemplo en el README de la app).
class ApiConfig {
  ApiConfig._();

  static const String _overrideFromDefine = String.fromEnvironment(
    'API_BASE_URL',
  );

  /// Base de la API, SIN slash final (ej. `http://127.0.0.1:8000/api`).
  static String get baseUrl {
    if (_overrideFromDefine.isNotEmpty) {
      return _overrideFromDefine;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }

    // iOS simulator, macOS, Windows, Linux desktop.
    return 'http://127.0.0.1:8000/api';
  }

  /// `'movil'` o `'escritorio'` — lo que el backend espera en
  /// `POST /login` (ver `LoginRequest`) y sella en el token. Los bocetos
  /// de Figma no muestran un selector manual de plataforma en el login
  /// (esa pantalla asume que ya sabés en qué app estás), así que se
  /// resuelve solo, en base a dónde corre el build:
  ///
  /// - Android/iOS → `'movil'` (app de docentes/preceptores).
  /// - Windows/macOS/Linux/Web → `'escritorio'` (panel de administración).
  ///   Web cuenta como escritorio: hoy solo se usa para probar en Chrome
  ///   mientras no compila el build nativo de Windows, no es un target
  ///   real distinto.
  static String get plataforma {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return 'movil';
    }

    return 'escritorio';
  }
}

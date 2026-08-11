import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/usuario.dart';

/// Lo mínimo que hace falta guardar para no pedir login de nuevo en cada
/// reinicio de la app: el token Sanctum, la plataforma con la que se
/// selló (movil|escritorio — ver AuthController::login() del backend),
/// y una copia del usuario para poder mostrar algo antes de que
/// `GET /me` responda.
class SesionGuardada {
  const SesionGuardada({
    required this.token,
    required this.plataforma,
    required this.usuario,
  });

  final String token;
  final String plataforma;
  final Usuario usuario;
}

/// Persistencia del token/sesión entre reinicios de la app, vía
/// flutter_secure_storage (Keychain/Keystore/Credential Locker según la
/// plataforma — nunca `SharedPreferences` en texto plano, es un token de
/// acceso real).
///
/// A propósito NO se guarda la contraseña acá ni en ningún lado del
/// cliente — solo el token que devuelve el login.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyToken = 'auth_token';
  static const _keyPlataforma = 'auth_plataforma';
  static const _keyUsuario = 'auth_usuario';

  Future<void> guardar({
    required String token,
    required String plataforma,
    required Usuario usuario,
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyPlataforma, value: plataforma),
      _storage.write(key: _keyUsuario, value: jsonEncode(usuario.toJson())),
    ]);
  }

  Future<SesionGuardada?> leer() async {
    final valores = await Future.wait([
      _storage.read(key: _keyToken),
      _storage.read(key: _keyPlataforma),
      _storage.read(key: _keyUsuario),
    ]);

    final token = valores[0];
    final plataforma = valores[1];
    final usuarioJson = valores[2];

    if (token == null || plataforma == null || usuarioJson == null) {
      return null;
    }

    try {
      final usuario = Usuario.fromJson(
        jsonDecode(usuarioJson) as Map<String, dynamic>,
      );
      return SesionGuardada(token: token, plataforma: plataforma, usuario: usuario);
    } catch (_) {
      // Dato corrupto/de una versión vieja del modelo — mejor pedir
      // login de nuevo que reventar el arranque de la app.
      await limpiar();
      return null;
    }
  }

  Future<void> limpiar() async {
    await Future.wait([
      _storage.delete(key: _keyToken),
      _storage.delete(key: _keyPlataforma),
      _storage.delete(key: _keyUsuario),
    ]);
  }
}

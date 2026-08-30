import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show Uint8List;

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

/// Wrapper fino sobre `package:http` para hablar con `backend-laravel`.
///
/// Responsabilidades: arma la URL completa a partir de `ApiConfig.baseUrl`,
/// agrega los headers comunes (`Accept`/`Content-Type: application/json`
/// y `Authorization: Bearer <token>` cuando hay sesión), decodifica el
/// body JSON, y traduce cualquier respuesta no-2xx (o error de red) a un
/// `ApiException` — así el resto de la app nunca maneja `http.Response`
/// ni `jsonDecode` directamente, solo trabaja con Maps/Lists ya
/// decodificados o con `ApiException`.
///
/// El token vive acá en memoria (`setToken`), no en storage — quien
/// decide qué token corresponde y cuándo persistirlo es
/// `AuthRepository`/`AuthProvider` (ver lib/providers/auth_provider.dart).

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final normalizado = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('${ApiConfig.baseUrl}$normalizado');

    if (query == null || query.isEmpty) {
      return base;
    }

    return base.replace(
      queryParameters: query.map((key, value) => MapEntry(key, '$value')),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) {
    return _decode(
      _send(() => _httpClient.get(_uri(path, query), headers: _headers)),
    );
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) {
    return _decode(
      _send(() => _httpClient.post(
            _uri(path),
            headers: _headers,
            body: body == null ? null : jsonEncode(body),
          )),
    );
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) {
    return _decode(
      _send(() => _httpClient.put(
            _uri(path),
            headers: _headers,
            body: body == null ? null : jsonEncode(body),
          )),
    );
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) {
    return _decode(
      _send(() => _httpClient.patch(
            _uri(path),
            headers: _headers,
            body: body == null ? null : jsonEncode(body),
          )),
    );
  }

  Future<dynamic> delete(String path) {
    return _decode(
      _send(() => _httpClient.delete(_uri(path), headers: _headers)),
    );
  }

  /// `POST` con un archivo adjunto (`multipart/form-data`) — usado hoy
  /// solo por "Importar alumnos" (`POST /alumnos/importar`). Aparte de
  /// `get/post/put/patch/delete` porque un archivo no se puede mandar
  /// como body JSON: no hay `Content-Type` fijo acá, `http.MultipartRequest`
  /// arma el suyo propio (con el boundary) al enviarse — por eso NO usa
  /// `_headers` (que fuerza `application/json`), solo agrega `Accept` y
  /// `Authorization` a mano.
  Future<dynamic> postMultipart(
    String path, {
    required String campoArchivo,
    required Uint8List bytes,
    required String nombreArchivo,
  }) {
    return _decode(_enviarMultipart(path, campoArchivo, bytes, nombreArchivo));
  }

  Future<http.Response> _enviarMultipart(
    String path,
    String campoArchivo,
    Uint8List bytes,
    String nombreArchivo,
  ) async {
    try {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers['Accept'] = 'application/json';
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.files.add(
        http.MultipartFile.fromBytes(campoArchivo, bytes, filename: nombreArchivo),
      );

      final streamedResponse =
          await _httpClient.send(request).timeout(const Duration(seconds: 30));
      return await http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      throw ApiException.red('El servidor tardó demasiado en responder.');
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException.red();
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException.red('El servidor tardó demasiado en responder.');
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException.red();
    }
  }

  Future<dynamic> _decode(Future<http.Response> futuroResponse) async {
    final response = await futuroResponse;

    Map<String, dynamic>? decodedMap;
    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      try {
        decodedBody = jsonDecode(response.body);
        if (decodedBody is Map<String, dynamic>) {
          decodedMap = decodedBody;
        }
      } catch (_) {
        // Respuesta no-JSON (ej. un 500 de PHP sin APP_DEBUG, o un proxy
        // devolviendo HTML) — se maneja abajo con el mensaje genérico.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody ?? decodedMap ?? {};
    }

    throw _excepcionDesde(response.statusCode, decodedMap);
  }

  ApiException _excepcionDesde(int statusCode, Map<String, dynamic>? decoded) {
    final mensaje = decoded?['message'] as String? ??
        'Ocurrió un error inesperado ($statusCode).';

    Map<String, List<String>>? errors;
    final rawErrors = decoded?['errors'];
    if (rawErrors is Map) {
      errors = rawErrors.map(
        (key, value) => MapEntry(
          key as String,
          (value as List).map((mensaje) => mensaje.toString()).toList(),
        ),
      );
    }

    return ApiException(mensaje: mensaje, statusCode: statusCode, errors: errors);
  }
}

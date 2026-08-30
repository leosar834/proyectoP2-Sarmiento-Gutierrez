import 'dart:typed_data';

import '../models/resultado_importacion_alumnos.dart';
import 'api_client.dart';

/// `POST /alumnos/importar` (ver `ImportacionAlumnosController` en el
/// backend) — sube el Excel elegido en "Importar alumnos" y devuelve el
/// resumen fila por fila. La URL de la plantilla (`GET
/// /alumnos/plantilla-importacion`) no pasa por acá: es pública, sin
/// auth, así que la pantalla la abre directo con `url_launcher` en vez
/// de necesitar un método de repositorio.
class ImportacionAlumnosRepository {
  ImportacionAlumnosRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ResultadoImportacionAlumnos> importar({
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    final respuesta = await _apiClient.postMultipart(
      '/alumnos/importar',
      campoArchivo: 'archivo',
      bytes: bytes,
      nombreArchivo: nombreArchivo,
    ) as Map<String, dynamic>;

    return ResultadoImportacionAlumnos.fromJson(
        respuesta['data'] as Map<String, dynamic>);
  }
}

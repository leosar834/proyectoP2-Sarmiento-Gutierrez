import '../models/institucion.dart';
import 'api_client.dart';

/// Llamadas contra `GET`/`PUT /institucion` (ver `InstitucionController`
/// en el backend, detrás de `permiso:gestionar_sistema`). Igual que
/// `AuthRepository`, no sabe nada de estado ni de `ChangeNotifier` — eso
/// lo maneja cada pantalla que lo usa (acá no hace falta un provider
/// global: solo el panel de escritorio consume estos datos).
class InstitucionRepository {
  InstitucionRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Institucion> obtener() async {
    final respuesta =
        await _apiClient.get('/institucion') as Map<String, dynamic>;
    return Institucion.fromJson(respuesta['data'] as Map<String, dynamic>);
  }

  Future<Institucion> actualizar({
    required String nombre,
    required String domicilio,
    required String cue,
    required String localidad,
    required String provincia,
    required String modalidad,
  }) async {
    final respuesta = await _apiClient.put('/institucion', body: {
      'nombre': nombre,
      'domicilio': domicilio,
      'cue': cue,
      'localidad': localidad,
      'provincia': provincia,
      'modalidad': modalidad,
    }) as Map<String, dynamic>;

    return Institucion.fromJson(respuesta['data'] as Map<String, dynamic>);
  }
}

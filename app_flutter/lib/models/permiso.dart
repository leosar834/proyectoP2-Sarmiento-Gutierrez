/// Espejo de lo que devuelve `PermisosController` (backend-laravel) — un
/// permiso del catálogo FIJO del sistema (tabla `permisos`). No lo edita
/// la institución: solo se usa para armar el checklist de
/// `RolesScreen`. `plataforma` es el techo de lo que ese permiso puede
/// llegar a habilitar ('movil' o 'escritorio'), ver `App\Models\Permiso`
/// en el backend.
class Permiso {
  const Permiso({
    required this.id,
    required this.nombre,
    required this.plataforma,
    required this.descripcion,
  });

  factory Permiso.fromJson(Map<String, dynamic> json) {
    return Permiso(
      id: json['id_permiso'] as int,
      nombre: json['nombre'] as String,
      plataforma: json['plataforma'] as String,
      descripcion: json['descripcion'] as String?,
    );
  }

  final int id;
  final String nombre;

  /// 'movil' | 'escritorio'.
  final String plataforma;
  final String? descripcion;
}

import 'permiso.dart';

/// Espejo de lo que devuelve `RolesController` (backend-laravel) — un
/// rol libre, definido por la institución (ej. "preceptor",
/// "director"). Lo que puede hacer surge exclusivamente de `permisos`
/// (subconjunto del catálogo fijo, ver `App\Models\Rol`).
class Rol {
  const Rol({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activo,
    required this.cantidadUsuarios,
    required this.permisos,
  });

  factory Rol.fromJson(Map<String, dynamic> json) {
    final permisosJson = json['permisos'] as List<dynamic>? ?? const [];
    return Rol(
      id: json['id_rol'] as int,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      activo: json['activo'] as bool,
      cantidadUsuarios: json['cantidad_usuarios'] as int? ?? 0,
      permisos: permisosJson
          .map((item) => Permiso.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;
  final int cantidadUsuarios;
  final List<Permiso> permisos;
}

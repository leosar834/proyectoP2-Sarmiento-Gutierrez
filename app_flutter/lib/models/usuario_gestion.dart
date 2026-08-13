/// Espejo de lo que devuelve `UsuariosController` (backend-laravel) para
/// la pantalla de administración "Usuarios" — distinto de `Usuario`
/// (lib/models/usuario.dart), que es el usuario autenticado actual
/// (`/me`, con `roles` como lista de nombres). Acá `roles` viene como
/// objetos {id, nombre} porque hace falta el id para el checklist de
/// `UsuariosScreen`.
class UsuarioGestion {
  const UsuarioGestion({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.activo,
    required this.roles,
  });

  factory UsuarioGestion.fromJson(Map<String, dynamic> json) {
    final rolesJson = json['roles'] as List<dynamic>? ?? const [];
    return UsuarioGestion(
      id: json['id_usuario'] as int,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      email: json['email'] as String,
      activo: json['activo'] as bool,
      roles: rolesJson
          .map((item) => RolResumen.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final int id;
  final String nombre;
  final String apellido;
  final String email;
  final bool activo;
  final List<RolResumen> roles;

  String get nombreCompleto => '$nombre $apellido';
}

/// Versión resumida de un rol (solo id + nombre) tal como viene anidada
/// dentro de un `UsuarioGestion` — para el detalle completo (permisos,
/// cantidad de usuarios) ver `Rol` en lib/models/rol.dart.
class RolResumen {
  const RolResumen({required this.id, required this.nombre});

  factory RolResumen.fromJson(Map<String, dynamic> json) {
    return RolResumen(
      id: json['id_rol'] as int,
      nombre: json['nombre'] as String,
    );
  }

  final int id;
  final String nombre;
}

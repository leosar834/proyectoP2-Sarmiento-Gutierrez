/// Espejo de `UsuarioResource` (backend-laravel/app/Http/Resources/UsuarioResource.php).
///
/// `roles` es la lista de nombres de rol (`preceptor`, `administrador_sistema`,
/// etc.) — el backend nunca manda los permisos calculados del lado del
/// cliente, así que la UI decide qué mostrar en base al catálogo fijo de
/// 7 permisos + la `plataforma` sellada en el token (ver AuthSession), no
/// en base al nombre del rol.
class Usuario {
  const Usuario({
    required this.idUsuario,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.activo,
    required this.roles,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      idUsuario: json['id_usuario'] as int,
      nombre: json['nombre'] as String,
      apellido: json['apellido'] as String,
      email: json['email'] as String,
      activo: json['activo'] as bool,
      roles: (json['roles'] as List<dynamic>? ?? const [])
          .map((rol) => rol as String)
          .toList(growable: false),
    );
  }

  final int idUsuario;
  final String nombre;
  final String apellido;
  final String email;
  final bool activo;
  final List<String> roles;

  String get nombreCompleto => '$nombre $apellido';

  Map<String, dynamic> toJson() => {
        'id_usuario': idUsuario,
        'nombre': nombre,
        'apellido': apellido,
        'email': email,
        'activo': activo,
        'roles': roles,
      };
}

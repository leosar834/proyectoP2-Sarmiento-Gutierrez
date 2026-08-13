/// Espejo de lo que devuelve `DivisionesController` (backend-laravel) —
/// una división (ej. "1a", "2a"). Junto con `Nivel` y el ciclo lectivo
/// arma un curso (ver `App\Models\Division` en el backend).
class Division {
  const Division({required this.id, required this.nombre});

  factory Division.fromJson(Map<String, dynamic> json) {
    return Division(
      id: json['id_division'] as int,
      nombre: json['nombre'] as String,
    );
  }

  final int id;
  final String nombre;
}

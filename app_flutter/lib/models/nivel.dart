/// Espejo de lo que devuelve `NivelesController` (backend-laravel) — un
/// "año" del establecimiento (ej. "1er año"). `numeroOrden` es el dato
/// que de verdad usa el sistema para promocionar (N -> N+1) al cerrar
/// un ciclo lectivo; `nombre` es solo la etiqueta visible — ver
/// `App\Models\Nivel` en el backend. No confundir con "especialidad":
/// el nivel es el año en sí.
class Nivel {
  const Nivel({
    required this.id,
    required this.nombre,
    required this.numeroOrden,
  });

  factory Nivel.fromJson(Map<String, dynamic> json) {
    return Nivel(
      id: json['id_nivel'] as int,
      nombre: json['nombre'] as String,
      numeroOrden: json['numero_orden'] as int,
    );
  }

  final int id;
  final String nombre;
  final int numeroOrden;
}

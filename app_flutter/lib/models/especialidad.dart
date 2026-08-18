/// Espejo de lo que devuelve `EspecialidadesController` (backend-laravel)
/// — una especialidad/orientación del catálogo (ej. "Electromecánica").
/// Dato permanente, no depende de ningún ciclo lectivo — ver
/// `App\Models\Especialidad` en el backend. No confundir con `Nivel`
/// (el nivel es el año; la especialidad es la orientación).
class Especialidad {
  const Especialidad({required this.id, required this.nombre});

  factory Especialidad.fromJson(Map<String, dynamic> json) {
    return Especialidad(
      id: json['id_especialidad'] as int,
      nombre: json['nombre'] as String,
    );
  }

  final int id;
  final String nombre;
}

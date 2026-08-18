/// Espejo de lo que devuelve `MateriasTallerController` (backend-laravel)
/// — una materia/taller del catálogo de una especialidad (ej. "Dibujo
/// Técnico" en Electromecánica). Dato permanente, no depende de ningún
/// ciclo lectivo — los grupos de taller (`GrupoTaller`) sí son por
/// ciclo y se arman aparte, sobre estas materias ya existentes. Ver
/// `App\Models\MateriaTaller` en el backend.
///
/// `especialidadId`/`especialidadNombre` son nullable: una materia de
/// ciclo básico (1°/2° año) puede no tener especialidad todavía, ya que
/// en las escuelas técnico-profesionales la orientación recién se define
/// a partir de 3°/4° año.
class MateriaTaller {
  const MateriaTaller({
    required this.id,
    required this.especialidadId,
    required this.especialidadNombre,
    required this.nombre,
    required this.regimenCursada,
  });

  factory MateriaTaller.fromJson(Map<String, dynamic> json) {
    return MateriaTaller(
      id: json['id_materia_taller'] as int,
      especialidadId: json['especialidad_id'] as int?,
      especialidadNombre: json['especialidad_nombre'] as String?,
      nombre: json['nombre'] as String,
      regimenCursada: json['regimen_cursada'] as String,
    );
  }

  final int id;
  final int? especialidadId;
  final String? especialidadNombre;
  final String nombre;

  /// 'anual' | 'trimestral' | 'semestral' | 'personalizado'.
  final String regimenCursada;
}

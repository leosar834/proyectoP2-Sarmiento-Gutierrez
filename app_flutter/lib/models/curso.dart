/// Espejo de lo que devuelve `CursosController` (backend-laravel) — un
/// curso principal: nivel + división + ciclo lectivo + turno (ej. "3°
/// 1a", turno mañana, ciclo 2026). Ver `App\Models\Curso` en el backend.
class Curso {
  const Curso({
    required this.id,
    required this.nivelId,
    required this.nivelNombre,
    required this.divisionId,
    required this.divisionNombre,
    required this.cicloLectivoId,
    required this.turno,
  });

  factory Curso.fromJson(Map<String, dynamic> json) {
    return Curso(
      id: json['id_curso'] as int,
      nivelId: json['nivel_id'] as int,
      nivelNombre: json['nivel_nombre'] as String?,
      divisionId: json['division_id'] as int,
      divisionNombre: json['division_nombre'] as String?,
      cicloLectivoId: json['ciclo_lectivo_id'] as int,
      turno: json['turno'] as String,
    );
  }

  final int id;
  final int nivelId;
  final String? nivelNombre;
  final int divisionId;
  final String? divisionNombre;
  final int cicloLectivoId;

  /// 'mañana' | 'tarde' | 'noche'.
  final String turno;
}

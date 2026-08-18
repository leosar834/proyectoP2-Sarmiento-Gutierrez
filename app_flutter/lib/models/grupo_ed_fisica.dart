/// Espejo de lo que devuelve `GruposEdFisicaController` (backend-laravel)
/// — un grupo de educación física del ciclo lectivo abierto. A
/// diferencia de taller, no depende de un nivel ni de una materia (es
/// una sola bolsa por ciclo) y un alumno solo puede estar en un grupo
/// de ed. física a la vez. Ver `App\Models\GrupoEdFisica` en el
/// backend.
///
/// `profesorId` es obligatorio (columna NOT NULL) pero el backend no
/// manda el nombre del profesor — hay que cruzarlo del lado del
/// cliente contra la lista de usuarios (ver `UsuarioGestion`).
class GrupoEdFisica {
  const GrupoEdFisica({
    required this.id,
    required this.cicloLectivoId,
    required this.nombreGrupo,
    required this.regimenCursada,
    required this.profesorId,
    required this.alumnosAsignados,
  });

  factory GrupoEdFisica.fromJson(Map<String, dynamic> json) {
    return GrupoEdFisica(
      id: json['id_grupo_ed_fisica'] as int,
      cicloLectivoId: json['ciclo_lectivo_id'] as int,
      nombreGrupo: json['nombre_grupo'] as String,
      regimenCursada: json['regimen_cursada'] as String,
      profesorId: json['profesor_id'] as int,
      alumnosAsignados: json['alumnos_asignados'] as int? ?? 0,
    );
  }

  final int id;
  final int cicloLectivoId;
  final String nombreGrupo;

  /// 'anual' | 'trimestral' | 'semestral' | 'personalizado'.
  final String regimenCursada;
  final int profesorId;
  final int alumnosAsignados;
}

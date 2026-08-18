/// Espejo de `InstitucionResource`
/// (backend-laravel/app/Http/Resources/InstitucionResource.php) — la
/// ficha de identificación de la (única) institución que corre el
/// sistema. Ver `App\Models\Institucion` en el backend para el porqué
/// de que sea una fila única, siempre editable.
class Institucion {
  const Institucion({
    required this.nombre,
    required this.domicilio,
    required this.cue,
    required this.localidad,
    required this.provincia,
    required this.modalidad,
  });

  factory Institucion.fromJson(Map<String, dynamic> json) {
    return Institucion(
      nombre: json['nombre'] as String,
      domicilio: json['domicilio'] as String,
      cue: json['cue'] as String,
      localidad: json['localidad'] as String,
      provincia: json['provincia'] as String,
      modalidad: json['modalidad'] as String,
    );
  }

  final String nombre;
  final String domicilio;
  final String cue;
  final String localidad;
  final String provincia;

  /// 'tecnico_profesional_contraturno' | 'secundaria_comun_orientaciones'
  /// — ver el docblock de `App\Models\Institucion` en el backend. Es un
  /// parámetro de presentación (qué secciones mostrar en el menú), no
  /// una regla de negocio: el backend no bloquea nada según este valor.
  final String modalidad;

  /// Si la institución declaró tener talleres en contraturno — se usa
  /// para decidir si "Materias de Taller" y "Grupos de Taller" aparecen
  /// en el menú lateral (ver `PanelEscritorioScreen`).
  bool get tieneTalleres => modalidad == 'tecnico_profesional_contraturno';
}

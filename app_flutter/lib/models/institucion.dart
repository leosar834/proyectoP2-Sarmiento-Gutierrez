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
  });

  factory Institucion.fromJson(Map<String, dynamic> json) {
    return Institucion(
      nombre: json['nombre'] as String,
      domicilio: json['domicilio'] as String,
      cue: json['cue'] as String,
      localidad: json['localidad'] as String,
      provincia: json['provincia'] as String,
    );
  }

  final String nombre;
  final String domicilio;
  final String cue;
  final String localidad;
  final String provincia;
}

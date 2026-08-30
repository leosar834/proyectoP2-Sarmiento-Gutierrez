import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../models/resultado_importacion_alumnos.dart';
import '../services/api_exception.dart';
import '../services/importacion_alumnos_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Carga masiva de alumnos desde un Excel — la alternativa a
/// `InscripcionPorCursoScreen` para cuando la institución ya tiene su
/// matrícula completa en una planilla y no quiere tipearla de nuevo a
/// mano, fila por fila, en el sistema (ver `AlumnosImport` en el
/// backend para el formato exacto de columnas esperado).
///
/// Mismo criterio que `InscripcionPorCursoScreen`: panel embebido en el
/// `body` de `AlumnosScreen`, alternado con `setState`
/// (`_modoImportacion`), nunca con `Navigator.push` — ver el docblock de
/// esa pantalla para el bug de Flutter que esto evita.
///
/// Cada fila que llega en el Excel intenta crear legajo + inscripción
/// juntos, igual que "Inscribir por curso"; una fila con un dato
/// inválido (DNI repetido, curso inexistente, etc.) no aborta el
/// archivo entero — se saltea y queda listada en el resultado, con su
/// motivo, para que se pueda corregir esa fila puntual y listo.
class ImportarAlumnosScreen extends StatefulWidget {
  const ImportarAlumnosScreen({
    super.key,
    required this.repositorio,
    required this.onCerrar,
  });

  final ImportacionAlumnosRepository repositorio;

  /// `alumnosImportados`: si se creó al menos un alumno, para que
  /// `AlumnosScreen` sepa que tiene que refrescar su búsqueda al volver.
  final ValueChanged<bool> onCerrar;

  @override
  State<ImportarAlumnosScreen> createState() => _ImportarAlumnosScreenState();
}

class _ImportarAlumnosScreenState extends State<ImportarAlumnosScreen> {
  PlatformFile? _archivoElegido;

  bool _importando = false;
  ApiException? _error;
  ResultadoImportacionAlumnos? _resultado;

  bool get _huboAlgunaCreacion => (_resultado?.creados ?? 0) > 0;

  Future<void> _descargarPlantilla() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/alumnos/plantilla-importacion');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _mostrarFormato() {
    showDialog(
      context: context,
      builder: (_) => const _DialogoFormatoImportacion(),
    );
  }

  Future<void> _elegirArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true, // hace falta el contenido en memoria (bytes), no
      // solo la ruta — en web no hay filesystem al que apuntar con un
      // path, así que sin esto `bytes` llega `null` también en desktop.
    );

    if (resultado == null || resultado.files.isEmpty) return;

    setState(() {
      _archivoElegido = resultado.files.single;
      _resultado = null;
      _error = null;
    });
  }

  Future<void> _importar() async {
    final archivo = _archivoElegido;
    if (archivo == null || archivo.bytes == null) return;

    setState(() {
      _importando = true;
      _error = null;
    });

    try {
      final resultado = await widget.repositorio.importar(
        bytes: archivo.bytes!,
        nombreArchivo: archivo.name,
      );
      if (!mounted) return;
      setState(() {
        _resultado = resultado;
        _importando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _importando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => widget.onCerrar(_huboAlgunaCreacion),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Volver a Alumnos'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textoSecundario),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Importar alumnos desde Excel',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textoPrincipal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Cada fila crea el legajo del alumno y lo inscribe directo en '
            'el curso indicado, en el ciclo lectivo abierto. Una fila con '
            'un problema (DNI repetido, curso inexistente) no frena al '
            'resto — se saltea y queda detallada abajo con el motivo.',
            style: TextStyle(fontSize: 13, color: AppColors.textoSecundario, height: 1.4),
          ),
          const SizedBox(height: 20),
          BannerInfo(
            mensaje: '¿Primera vez? Descargá la plantilla, completala con '
                'los datos (una fila por alumno) y subila acá. Las '
                'columnas son: Nombre, Apellido, DNI, Fecha nacimiento, '
                'Fecha ingreso (AAAA-MM-DD), Nivel (número de año, 1 a 6) '
                'y Division.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _descargarPlantilla,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Descargar plantilla'),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: _mostrarFormato,
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('Ver formato detallado'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            BannerError(mensaje: _error!.mensaje),
            const SizedBox(height: 16),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.tarjeta,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _archivoElegido?.name ?? 'Ningún archivo elegido todavía.',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _archivoElegido == null ? FontWeight.normal : FontWeight.w600,
                          color: _archivoElegido == null
                              ? AppColors.textoSecundario
                              : AppColors.textoPrincipal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _importando ? null : _elegirArchivo,
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: const Text('Elegir archivo'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: (_archivoElegido == null || _importando) ? null : _importar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azulPrimario,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.azulPrimario.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _importando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_file_outlined, size: 20),
                    label: Text(
                      _importando ? 'Importando...' : 'Importar',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_resultado != null) ...[
            const SizedBox(height: 24),
            _ResumenResultado(resultado: _resultado!),
          ],
        ],
      ),
    );
  }
}

class _ResumenResultado extends StatelessWidget {
  const _ResumenResultado({required this.resultado});

  final ResultadoImportacionAlumnos resultado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Metrica(
              valor: resultado.creados,
              etiqueta: 'creados',
              color: AppColors.exito,
              icono: Icons.check_circle_outline,
            ),
            const SizedBox(width: 12),
            _Metrica(
              valor: resultado.salteados,
              etiqueta: 'salteados',
              color: resultado.salteados > 0 ? AppColors.advertencia : AppColors.textoSecundario,
              icono: Icons.info_outline,
            ),
          ],
        ),
        if (resultado.detalle.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Detalle por fila',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textoPrincipal),
          ),
          const SizedBox(height: 8),
          ...resultado.detalle.map((fila) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _FilaResultado(fila: fila),
              )),
        ],
      ],
    );
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica({
    required this.valor,
    required this.etiqueta,
    required this.color,
    required this.icono,
  });

  final int valor;
  final String etiqueta;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$valor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
                Text(etiqueta, style: TextStyle(fontSize: 11.5, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaResultado extends StatelessWidget {
  const _FilaResultado({required this.fila});

  final FilaImportacion fila;

  @override
  Widget build(BuildContext context) {
    final color = fila.creado ? AppColors.exito : AppColors.advertencia;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text('Fila ${fila.fila}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fila.creado ? fila.alumno ?? '' : fila.motivo ?? 'Salteada.',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textoPrincipal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Descripción de una columna esperada — la lista `_columnas` de abajo
/// es la única fuente de verdad que debería consultarse acá; si
/// `AlumnosImport` (backend) cambia una columna, esta lista se
/// actualiza en el mismo cambio para no quedar desincronizada.
class _ColumnaFormato {
  const _ColumnaFormato({
    required this.nombre,
    required this.obligatoria,
    required this.formato,
    required this.ejemplo,
  });

  final String nombre;
  final bool obligatoria;
  final String formato;
  final String ejemplo;
}

const _columnas = [
  _ColumnaFormato(
    nombre: 'Nombre',
    obligatoria: true,
    formato: 'Texto libre.',
    ejemplo: 'Juan',
  ),
  _ColumnaFormato(
    nombre: 'Apellido',
    obligatoria: true,
    formato: 'Texto libre.',
    ejemplo: 'Pérez',
  ),
  _ColumnaFormato(
    nombre: 'DNI',
    obligatoria: true,
    formato: 'Solo números, sin puntos ni espacios. Tiene que ser '
        'distinto al de cualquier alumno ya cargado — si coincide con '
        'uno existente, esa fila se saltea.',
    ejemplo: '30111222',
  ),
  _ColumnaFormato(
    nombre: 'Fecha nacimiento',
    obligatoria: false,
    formato: 'AAAA-MM-DD. Se puede dejar vacía.',
    ejemplo: '2010-03-15',
  ),
  _ColumnaFormato(
    nombre: 'Fecha ingreso',
    obligatoria: true,
    formato: 'AAAA-MM-DD.',
    ejemplo: '2022-03-01',
  ),
  _ColumnaFormato(
    nombre: 'Nivel',
    obligatoria: true,
    formato: 'El NÚMERO del año (1 a 6), no el nombre — tiene que existir '
        'un nivel con ese número en "Niveles". Ej: poner 1 para "1er año", '
        'no "1er año" ni "1°".',
    ejemplo: '1',
  ),
  _ColumnaFormato(
    nombre: 'Division',
    obligatoria: true,
    formato: 'El nombre de la división tal cual figura en "Divisiones" '
        '(no importan mayúsculas/minúsculas). Tiene que existir un curso '
        'con esa combinación de Nivel + Division en el ciclo lectivo '
        'abierto — si no existe, la fila se saltea explicando cuál falta.',
    ejemplo: 'A',
  ),
];

class _DialogoFormatoImportacion extends StatelessWidget {
  const _DialogoFormatoImportacion();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Formato de la planilla'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Una fila por alumno. La primera fila tiene que ser el '
                'encabezado, con estos nombres de columna exactos (en '
                'cualquier orden) — lo más seguro es partir de "Descargar '
                'plantilla" en vez de escribirlos a mano.',
                style: TextStyle(fontSize: 13, color: AppColors.textoSecundario, height: 1.4),
              ),
              const SizedBox(height: 16),
              ..._columnas.map((columna) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FilaColumna(columna: columna),
                  )),
              const Divider(height: 24),
              const Text(
                'Si una fila no se puede cargar (DNI repetido, nivel o '
                'división que no existen, faltan datos obligatorios), esa '
                'fila se saltea y queda detallada con el motivo — el '
                'resto del archivo se importa igual.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textoSecundario, height: 1.4),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _FilaColumna extends StatelessWidget {
  const _FilaColumna({required this.columna});

  final _ColumnaFormato columna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                columna.nombre,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textoPrincipal,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (columna.obligatoria ? AppColors.error : AppColors.textoSecundario)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  columna.obligatoria ? 'Obligatoria' : 'Opcional',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: columna.obligatoria ? AppColors.error : AppColors.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            columna.formato,
            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario, height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            'Ejemplo: ${columna.ejemplo}',
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: AppColors.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

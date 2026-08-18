import 'package:flutter/material.dart';

import '../models/alumno.dart';
import '../models/curso.dart';
import '../models/nivel.dart';
import '../services/alumno_repository.dart';
import '../services/api_exception.dart';
import '../services/traslado_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Carga masiva de alumnos ya existentes, agrupada por curso — pensada
/// para el caso de una institución que recién empieza a usar el sistema
/// y tiene que cargar de una su matrícula completa (cientos de
/// alumnos), no para el alta puntual de uno o dos alumnos sueltos (eso
/// sigue siendo el diálogo "Agregar" de `AlumnosScreen`).
///
/// A propósito esto NO es una pantalla con ruta propia — es un panel
/// que `AlumnosScreen` muestra "ahí mismo" en su propio `body` cuando
/// `_modoInscripcionPorCurso` está prendido (ver ese archivo), sin
/// pasar nunca por `Navigator.push`/`pop`. Una versión anterior sí
/// encadenaba pantallas nuevas (`Navigator.push` desde el botón
/// "Inscribir por curso" y de nuevo por cada tarjeta de curso) y eso
/// disparaba, de forma reproducible, un bug del framework de Flutter en
/// web/desktop (`Assertion failed... mouse_tracker.dart:199`): al sacar
/// del árbol el botón/tarjeta que dispara la navegación justo cuando
/// arranca una ruta nueva, el estado interno que rastrea el mouse queda
/// inconsistente. Acá adentro hay dos "vistas" (la lista de cursos y el
/// detalle de uno), pero las dos viven en el mismo widget/árbol — se
/// alternan con `setState` (`_cursoSeleccionado`), nunca con una ruta
/// nueva, así que no vuelve a aparecer esa ventana de tiempo.
///
/// 1. Lista de cursos (`_listaCursos`): uno por curso del ciclo
///    abierto, ordenados por año y división, cada uno con la cantidad
///    de alumnos ya cargados y un botón "Inscribir alumno".
/// 2. Detalle del curso elegido (`_panelCurso`): el listado de alumnos
///    YA inscriptos primero (con un aviso si todavía no hay ninguno), y
///    "Agregar alumno" como acción secundaria para seguir sumando gente
///    a ESE curso sin volver a elegirlo — un link arriba vuelve a la
///    lista de cursos.
///
/// Por abajo, cada alta encadena `AlumnoRepository.crear()` (el legajo)
/// + `TrasladoRepository.trasladar()` (lo inscribe en el curso) — lo
/// mismo que ya hace `IngresantesController` para 1er año, pero para
/// CUALQUIER curso, porque no existe un endpoint de alta+inscripción
/// combinado salvo para ingresantes de 1er año (ver el docblock de
/// `IngresantesController`). El usuario nunca percibe que son dos
/// pasos. Si el segundo paso llegara a fallar justo después de que el
/// primero ya tuvo éxito (por ejemplo se corta la conexión en el
/// medio), el legajo queda creado pero sin curso — no se pierde nada,
/// se completa después desde "Alumnos" con "Trasladar".
class InscripcionPorCursoScreen extends StatefulWidget {
  const InscripcionPorCursoScreen({
    super.key,
    required this.repositorioAlumnos,
    required this.repositorioTraslados,
    required this.cicloLectivoId,
    required this.cursosDelCiclo,
    required this.niveles,
    required this.alumnos,
    required this.onCerrar,
  });

  final AlumnoRepository repositorioAlumnos;
  final TrasladoRepository repositorioTraslados;
  final int cicloLectivoId;
  final List<Curso> cursosDelCiclo;
  final List<Nivel> niveles;

  /// Matrícula completa ya cargada por `AlumnosScreen` — se usa solo
  /// para calcular la cantidad inicial de alumnos por curso en la
  /// lista, sin pedirle nada nuevo al backend acá.
  final List<Alumno> alumnos;

  /// `AlumnosScreen` lo usa para apagar `_modoInscripcionPorCurso` y,
  /// si `alumnosAgregados` es true, refrescar su propio listado.
  final void Function({required bool alumnosAgregados}) onCerrar;

  @override
  State<InscripcionPorCursoScreen> createState() => _InscripcionPorCursoScreenState();
}

class _InscripcionPorCursoScreenState extends State<InscripcionPorCursoScreen> {
  late final Map<int, int> _conteoPorCurso;

  Curso? _cursoSeleccionado;
  bool _cargando = false;
  ApiException? _errorCarga;
  List<Alumno> _alumnosDelCurso = const [];

  /// Total agregado en toda la sesión de este panel (sumando todos los
  /// cursos por los que se pasó) — determina si al cerrar hay que
  /// refrescar el listado de `AlumnosScreen`.
  int _totalCargados = 0;

  /// Si se editó algún alumno (legajo o condición) en esta sesión del
  /// panel — también amerita refrescar `AlumnosScreen` al cerrar, igual
  /// que agregar alumnos nuevos.
  bool _huboEdiciones = false;

  @override
  void initState() {
    super.initState();
    _conteoPorCurso = {for (final curso in widget.cursosDelCiclo) curso.id: 0};
    for (final alumno in widget.alumnos) {
      final cursoId = alumno.inscripcionActual?.cursoId;
      if (cursoId != null && _conteoPorCurso.containsKey(cursoId)) {
        _conteoPorCurso[cursoId] = _conteoPorCurso[cursoId]! + 1;
      }
    }
  }

  /// Por año (`numero_orden` real de `Nivel`, no el nombre) y dentro de
  /// cada año por división (por `id` — no hay un orden explícito de
  /// división en el modelo, y se crean en el orden natural).
  List<Curso> get _cursosOrdenados {
    final ordenPorNivel = {for (final nivel in widget.niveles) nivel.id: nivel.numeroOrden};
    final lista = [...widget.cursosDelCiclo];
    lista.sort((a, b) {
      final ordenA = ordenPorNivel[a.nivelId] ?? 0;
      final ordenB = ordenPorNivel[b.nivelId] ?? 0;
      if (ordenA != ordenB) return ordenA.compareTo(ordenB);
      return a.divisionId.compareTo(b.divisionId);
    });
    return lista;
  }

  Future<void> _seleccionarCurso(Curso curso) async {
    setState(() {
      _cursoSeleccionado = curso;
      _alumnosDelCurso = const [];
      _errorCarga = null;
    });
    await _cargar();
  }

  void _volverALista() {
    setState(() => _cursoSeleccionado = null);
  }

  Future<void> _cargar() async {
    final curso = _cursoSeleccionado;
    if (curso == null) return;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final alumnos = await widget.repositorioAlumnos.obtenerTodos(cursoId: curso.id);
      if (!mounted || _cursoSeleccionado?.id != curso.id) return;
      setState(() {
        _alumnosDelCurso = alumnos;
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted || _cursoSeleccionado?.id != curso.id) return;
      setState(() {
        _cargando = false;
        _errorCarga = error;
      });
    }
  }

  Future<void> _abrirAgregarAlumno() async {
    final curso = _cursoSeleccionado;
    if (curso == null) return;
    final alumno = await showDialog<Alumno>(
      context: context,
      builder: (_) => _DialogoAltaRapida(
        repositorioAlumnos: widget.repositorioAlumnos,
        repositorioTraslados: widget.repositorioTraslados,
        cicloLectivoId: widget.cicloLectivoId,
        curso: curso,
      ),
    );
    if (alumno == null) return;
    setState(() {
      _alumnosDelCurso = [alumno, ..._alumnosDelCurso];
      _conteoPorCurso[curso.id] = (_conteoPorCurso[curso.id] ?? 0) + 1;
      _totalCargados++;
    });
  }

  Future<void> _abrirEditarAlumno(Alumno alumno) async {
    final curso = _cursoSeleccionado;
    if (curso == null) return;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoEditarAlumno(
        repositorioAlumnos: widget.repositorioAlumnos,
        repositorioTraslados: widget.repositorioTraslados,
        cicloLectivoId: widget.cicloLectivoId,
        curso: curso,
        alumno: alumno,
      ),
    );
    if (resultado != true) return;
    _huboEdiciones = true;
    // Se vuelve a pedir el listado del curso en vez de parchear el
    // alumno editado a mano: `AlumnoRepository.actualizar()` devuelve el
    // legajo SIN `inscripcion_actual` (ver el docblock del modelo), así
    // que no alcanza para reconstruir la condición actualizada — más
    // simple y confiable pedirle de nuevo la verdad al backend.
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final curso = _cursoSeleccionado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver a Alumnos',
              onPressed: () => widget.onCerrar(
                alumnosAgregados: _totalCargados > 0 || _huboEdiciones,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'Inscripción por curso',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textoPrincipal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const BannerInfo(
          mensaje: 'Elegí un curso para ver a sus alumnos y agregar '
              'nuevos ahí mismo, sin volver a elegir el curso en cada '
              'uno. Para mover a un alumno puntual entre cursos, usá '
              '"Trasladar" desde la lista de Alumnos.',
        ),
        const SizedBox(height: 20),
        Expanded(
          child: curso == null ? _listaCursos() : _panelCurso(curso),
        ),
      ],
    );
  }

  Widget _listaCursos() {
    if (widget.cursosDelCiclo.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No hay ningún curso cargado en el ciclo lectivo actual '
          'todavía — creá al menos uno desde "Cursos" antes de usar '
          'esta pantalla.',
          style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
        ),
      );
    }
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _cursosOrdenados.map(_filaCurso).toList(growable: false),
        ),
      ),
    );
  }

  Widget _filaCurso(Curso curso) {
    final cantidad = _conteoPorCurso[curso.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borde),
      ),
      // `IntrinsicHeight` es necesario acá: esta fila vive en un `Column`
      // adentro de un `SingleChildScrollView` (alto no acotado), y el
      // `Row` de abajo usa `crossAxisAlignment: stretch` para que la
      // franja de color ocupe toda la altura de la fila. `stretch`
      // necesita una altura FINITA a la cual estirarse — sin
      // `IntrinsicHeight`, el `Row` recibe `maxHeight: Infinity` y el
      // layout revienta (`RenderFlex` sin tamaño, después cascadea en
      // errores de hit-test y hasta en el mismo assert de
      // `mouse_tracker.dart` al procesar el puntero sobre una caja sin
      // tamaño). `IntrinsicHeight` calcula primero la altura natural del
      // contenido y se la pasa al `Row` como una altura acotada.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: AppColors.azulPrimario,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${curso.nivelNombre ?? ''} ${curso.divisionNombre ?? ''}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Turno ${curso.turno} · $cantidad ${cantidad == 1 ? 'alumno inscripto' : 'alumnos inscriptos'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _seleccionarCurso(curso),
                      icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: const Text('Inscribir alumno'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelCurso(Curso curso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _volverALista,
          borderRadius: BorderRadius.circular(6),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 16, color: AppColors.azulPrimario),
                SizedBox(width: 6),
                Text(
                  'Volver a la lista de cursos',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.azulPrimario,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${curso.nivelNombre ?? ''} ${curso.divisionNombre ?? ''} · Turno ${curso.turno}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textoPrincipal,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(child: _contenidoPanelCurso()),
      ],
    );
  }

  Widget _contenidoPanelCurso() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorCarga != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BannerError(mensaje: _errorCarga!.mensaje),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Alumnos inscriptos (${_alumnosDelCurso.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textoPrincipal,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _abrirAgregarAlumno,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulPrimario,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar alumno'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_alumnosDelCurso.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No hay alumnos inscriptos en este curso todavía — usá '
                  '"Agregar alumno" para empezar.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._alumnosDelCurso.map(_filaAlumno),
          ],
        ),
      ),
    );
  }

  Widget _filaAlumno(Alumno alumno) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(alumno.nombreCompleto, style: const TextStyle(fontSize: 13.5)),
          ),
          Text(
            'DNI ${alumno.dni}',
            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
          ),
          if (alumno.inscripcionActual?.condicion != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.azulPrimario.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                alumno.inscripcionActual!.condicion,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.azulPrimario,
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _abrirEditarAlumno(alumno),
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Modificar datos',
            visualDensity: VisualDensity.compact,
            color: AppColors.textoSecundario,
          ),
        ],
      ),
    );
  }
}

/// Alta rápida de UN alumno para el curso elegido en el desplegable de
/// arriba (no hay selector de curso acá — es el que ya está fijo).
/// Encadena `AlumnoRepository.crear()` + `TrasladoRepository.
/// trasladar()`, ver el docblock del archivo. Esto sí sigue siendo un
/// diálogo (`showDialog`) — a diferencia de una pantalla nueva vía
/// `Navigator.push`, un diálogo no saca del árbol al widget de fondo
/// (solo lo tapa visualmente), así que no le pega al mismo bug de
/// `mouse_tracker.dart` que motivó sacar la navegación por pantallas.
class _DialogoAltaRapida extends StatefulWidget {
  const _DialogoAltaRapida({
    required this.repositorioAlumnos,
    required this.repositorioTraslados,
    required this.cicloLectivoId,
    required this.curso,
  });

  final AlumnoRepository repositorioAlumnos;
  final TrasladoRepository repositorioTraslados;
  final int cicloLectivoId;
  final Curso curso;

  @override
  State<_DialogoAltaRapida> createState() => _DialogoAltaRapidaState();
}

class _DialogoAltaRapidaState extends State<_DialogoAltaRapida> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _dniController = TextEditingController();

  String _condicion = 'regular';
  DateTime? _fechaNacimiento;
  DateTime? _fechaIngreso;

  bool _guardando = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _fechaIngreso = DateTime.now();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _elegirFechaNacimiento() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(DateTime.now().year - 15),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Fecha de nacimiento',
    );
    if (fecha == null) return;
    setState(() => _fechaNacimiento = fecha);
  }

  Future<void> _elegirFechaIngreso() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaIngreso ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: 'Fecha de ingreso',
    );
    if (fecha == null) return;
    setState(() => _fechaIngreso = fecha);
  }

  Future<void> _guardar() async {
    if (_error != null) {
      setState(() => _error = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_fechaIngreso == null) {
      setState(() => _error = ApiException(mensaje: 'Ingrese la fecha de ingreso.'));
      return;
    }

    setState(() => _guardando = true);

    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();
    final dni = _dniController.text.trim();
    final fechaNacimientoIso = _fechaNacimiento == null ? null : _fechaIso(_fechaNacimiento!);
    final fechaIngresoIso = _fechaIso(_fechaIngreso!);

    Alumno alumno;
    try {
      alumno = await widget.repositorioAlumnos.crear(
        nombre: nombre,
        apellido: apellido,
        dni: dni,
        fechaNacimiento: fechaNacimientoIso,
        fechaIngresoInstitucion: fechaIngresoIso,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error;
      });
      return;
    }

    try {
      await widget.repositorioTraslados.trasladar(
        cicloLectivoId: widget.cicloLectivoId,
        alumnoId: alumno.id,
        cursoId: widget.curso.id,
        condicion: _condicion,
      );
    } on ApiException catch (error) {
      // El legajo ya se creó — no se pierde, solo falta anotarlo en el
      // curso. Se cierra igual el diálogo (para que se vea en la lista
      // de "Alumnos" de fondo) pero con un aviso bien explícito.
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se creó el legajo de "${alumno.nombreCompleto}" pero no se pudo '
            'inscribir en el curso (${error.mensaje}). Completalo desde '
            '"Alumnos" con "Trasladar".',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(alumno);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Agregar alumno — ${widget.curso.nivelNombre ?? ''} ${widget.curso.divisionNombre ?? ''}',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  BannerError(mensaje: _error!.mensaje),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre.' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidoController,
                        decoration: const InputDecoration(labelText: 'Apellido'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el apellido.' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dniController,
                        decoration: const InputDecoration(labelText: 'DNI'),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el DNI.' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _condicion,
                        decoration: const InputDecoration(labelText: 'Condición'),
                        items: const [
                          DropdownMenuItem(value: 'regular', child: Text('Regular')),
                          DropdownMenuItem(value: 'recursante', child: Text('Recursante')),
                        ],
                        onChanged: (valor) => setState(() => _condicion = valor ?? 'regular'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _elegirFechaNacimiento,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha de nacimiento (opcional)'),
                    child: Text(
                      _fechaNacimiento == null ? 'Sin especificar' : _fechaLegible(_fechaNacimiento!),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _elegirFechaIngreso,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha de ingreso'),
                    child: Text(
                      _fechaIngreso == null ? 'Elegir fecha' : _fechaLegible(_fechaIngreso!),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Modifica el legajo de UN alumno YA inscripto en `curso` (nombre,
/// apellido, DNI, fechas) y, a la vez, su condición en ESTE curso
/// (regular/recursante) — a diferencia de `_FormularioEditarAlumno` de
/// `AlumnosScreen`, que solo toca el legajo. Encadena
/// `AlumnoRepository.actualizar()` (legajo) + `TrasladoRepository.
/// trasladar()` con el MISMO curso que ya tenía (solo cambia la
/// condición si el usuario la tocó) — `TrasladosController::trasladar()`
/// en el backend hace un upsert sobre la inscripción existente del
/// alumno en este ciclo lectivo, así que llamarlo con el mismo curso es
/// seguro y no lo mueve de división.
///
/// La condición arranca precargada con
/// `alumno.inscripcionActual?.condicion`, y si viniera sin valor (por
/// ejemplo una inscripción que quedó "pendiente_asignacion" durante la
/// apertura de ciclo — ver el docblock de `Inscripcion` en el backend —
/// y por eso no se ve en la lista) arranca en 'regular' en vez de
/// quedar vacía, y guardar la corrige.
class _DialogoEditarAlumno extends StatefulWidget {
  const _DialogoEditarAlumno({
    required this.repositorioAlumnos,
    required this.repositorioTraslados,
    required this.cicloLectivoId,
    required this.curso,
    required this.alumno,
  });

  final AlumnoRepository repositorioAlumnos;
  final TrasladoRepository repositorioTraslados;
  final int cicloLectivoId;
  final Curso curso;
  final Alumno alumno;

  @override
  State<_DialogoEditarAlumno> createState() => _DialogoEditarAlumnoState();
}

class _DialogoEditarAlumnoState extends State<_DialogoEditarAlumno> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _dniController;

  late String _condicion;
  DateTime? _fechaNacimiento;
  DateTime? _fechaIngreso;

  bool _guardando = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.alumno.nombre);
    _apellidoController = TextEditingController(text: widget.alumno.apellido);
    _dniController = TextEditingController(text: widget.alumno.dni);
    _fechaNacimiento = _parseIso(widget.alumno.fechaNacimiento);
    _fechaIngreso = _parseIso(widget.alumno.fechaIngresoInstitucion);
    _condicion = widget.alumno.inscripcionActual?.condicion ?? 'regular';
  }

  DateTime? _parseIso(String? iso) => iso == null ? null : DateTime.tryParse(iso);

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _elegirFechaNacimiento() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(DateTime.now().year - 15),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Fecha de nacimiento',
    );
    if (fecha == null) return;
    setState(() => _fechaNacimiento = fecha);
  }

  Future<void> _elegirFechaIngreso() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaIngreso ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: 'Fecha de ingreso',
    );
    if (fecha == null) return;
    setState(() => _fechaIngreso = fecha);
  }

  Future<void> _guardar() async {
    if (_error != null) {
      setState(() => _error = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_fechaIngreso == null) {
      setState(() => _error = ApiException(mensaje: 'Ingrese la fecha de ingreso.'));
      return;
    }

    setState(() => _guardando = true);

    try {
      await widget.repositorioAlumnos.actualizar(
        widget.alumno.id,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        dni: _dniController.text.trim(),
        fechaNacimiento: _fechaNacimiento == null ? null : _fechaIso(_fechaNacimiento!),
        fechaIngresoInstitucion: _fechaIso(_fechaIngreso!),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error;
      });
      return;
    }

    try {
      await widget.repositorioTraslados.trasladar(
        cicloLectivoId: widget.cicloLectivoId,
        alumnoId: widget.alumno.id,
        cursoId: widget.curso.id,
        condicion: _condicion,
      );
    } on ApiException catch (error) {
      // El legajo ya se guardó — no se pierde, solo falta actualizar la
      // condición. Se cierra igual el diálogo (para que se vea el
      // nombre/DNI ya corregidos en la lista de fondo) pero con un
      // aviso bien explícito.
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Se guardaron los datos del legajo pero no se pudo actualizar '
            'la condición (${error.mensaje}). Volvé a intentarlo desde '
            '"Modificar datos".',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Modificar datos — ${widget.curso.nivelNombre ?? ''} ${widget.curso.divisionNombre ?? ''}',
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) ...[
                  BannerError(mensaje: _error!.mensaje),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre.' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidoController,
                        decoration: const InputDecoration(labelText: 'Apellido'),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el apellido.' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dniController,
                        decoration: const InputDecoration(labelText: 'DNI'),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el DNI.' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _condicion,
                        decoration: const InputDecoration(labelText: 'Condición'),
                        items: const [
                          DropdownMenuItem(value: 'regular', child: Text('Regular')),
                          DropdownMenuItem(value: 'recursante', child: Text('Recursante')),
                        ],
                        onChanged: (valor) => setState(() => _condicion = valor ?? 'regular'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _elegirFechaNacimiento,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha de nacimiento (opcional)'),
                    child: Text(
                      _fechaNacimiento == null ? 'Sin especificar' : _fechaLegible(_fechaNacimiento!),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _elegirFechaIngreso,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha de ingreso'),
                    child: Text(
                      _fechaIngreso == null ? 'Elegir fecha' : _fechaLegible(_fechaIngreso!),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

String _fechaIso(DateTime fecha) {
  final mes = fecha.month.toString().padLeft(2, '0');
  final dia = fecha.day.toString().padLeft(2, '0');
  return '${fecha.year}-$mes-$dia';
}

String _fechaLegible(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

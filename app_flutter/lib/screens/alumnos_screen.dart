import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumno.dart';
import '../models/ciclo_lectivo.dart';
import '../models/curso.dart';
import '../models/nivel.dart';
import '../providers/auth_provider.dart';
import '../services/alumno_repository.dart';
import '../services/api_exception.dart';
import '../services/ciclo_lectivo_repository.dart';
import '../services/curso_repository.dart';
import '../services/ingresante_repository.dart';
import '../services/nivel_repository.dart';
import '../services/traslado_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';
import 'inscripcion_por_curso_screen.dart';

/// Sección "Alumnos" del panel de escritorio — el último paso del plan
/// original (Ciclo lectivo → Cursos → Roles y permisos → Usuarios →
/// Alumnos). Junta tres controllers del backend, cada uno con un
/// alcance bien separado (ver sus docblocks):
///
/// - `AlumnosController`: el legajo (nombre, apellido, DNI, fechas) —
///   permanente, no depende de ningún ciclo lectivo.
/// - `IngresantesController`: alta de un alumno GENUINAMENTE nuevo,
///   crea legajo + inscripción en un curso de 1er año en un solo paso
///   — el caso más común.
/// - `TrasladosController`: asignar/mover a un alumno YA existente a un
///   curso del ciclo abierto (recursantes, cambios de división, pases),
///   y dar de baja una inscripción puntual a mitad de año.
///
/// Deliberadamente afuera de esta pantalla: la asignación de
/// especialidad en el traslado (la pantalla "Especialidades" todavía no
/// existe) y el historial completo de inscripciones de ciclos
/// anteriores (existe en el backend vía `AlumnosController::mostrar()`
/// pero no tiene UI propia todavía — se puede sumar más adelante).
///
/// El botón "Agregar" de acá abre el alta de UN alumno suelto (diálogo
/// `_FormularioAlta`). Para cargar la matrícula completa de una
/// institución que recién arranca con el sistema (varios cientos de
/// alumnos, repartidos en pocos cursos), eso es engorroso — hay que
/// volver a elegir el curso en cada alumno, y para 2°-5° año ni
/// siquiera existe un alta con curso incluido (`IngresantesController`
/// es solo para 1er año). "Inscribir por curso" (`InscripcionPorCursoScreen`)
/// resuelve ese caso: se elige el curso una sola vez y se cargan todos
/// sus alumnos seguidos, sin repetir el paso del curso en cada uno.

class AlumnosScreen extends StatefulWidget {
  const AlumnosScreen({super.key});

  @override
  State<AlumnosScreen> createState() => _AlumnosScreenState();
}

class _AlumnosScreenState extends State<AlumnosScreen> {
  late final AlumnoRepository _repositorio;
  late final IngresanteRepository _repositorioIngresantes;
  late final TrasladoRepository _repositorioTraslados;
  late final CicloLectivoRepository _repositorioCiclos;
  late final CursoRepository _repositorioCursos;
  late final NivelRepository _repositorioNiveles;

  final _busquedaController = TextEditingController();
  Timer? _debounceBusqueda;

  /// Solo la carga inicial (ciclo/niveles/cursos, antes de que la
  /// pantalla sea siquiera usable) — separado de `_cargando` (una
  /// búsqueda en curso) para que buscar no reemplace toda la pantalla
  /// por un spinner y esconda el buscador.
  bool _cargandoInicial = true;
  bool _cargando = false;
  ApiException? _errorCarga;

  /// A propósito arranca vacío y NUNCA se llena con "todos los alumnos"
  /// — con una institución de ~700 alumnos, traer el legajo completo de
  /// una sola vez (y encima en cada tecla que se tipea) es justo lo que
  /// hay que evitar. Solo se pide al backend cuando hay una búsqueda de
  /// 2+ caracteres o un curso elegido en el desplegable — ver
  /// `_buscar()` y `_onCambioBusqueda()`.
  List<Alumno> _alumnos = const [];

  CicloLectivo? _cicloActual;
  List<Curso> _cursosDelCiclo = const [];
  List<Nivel> _niveles = const [];
  int? _filtroCursoId;

  /// Prende/apaga el panel de "Inscripción por curso" — a propósito NO
  /// es una pantalla con `Navigator.push` propia, ver el docblock de
  /// `InscripcionPorCursoScreen`.
  bool _modoInscripcionPorCurso = false;

  /// La matrícula completa que necesita `InscripcionPorCursoScreen` para
  /// calcular cuántos alumnos tiene cargados cada curso — a diferencia
  /// de `_alumnos` (la búsqueda de la pantalla principal, que arranca
  /// vacía a propósito), esta SÍ se pide completa, pero solo en el
  /// momento en que se abre ese panel — no en la carga inicial de
  /// Alumnos. Es una sola pasada (no 700 peticiones, una lista de 700
  /// filas), y solo la paga quien realmente entra a cargar matrícula
  /// masiva, no cualquiera que abre "Alumnos" a buscar un DNI.
  List<Alumno> _alumnosParaInscripcionPorCurso = const [];
  bool _cargandoInscripcionPorCurso = false;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthProvider>().apiClient;
    _repositorio = AlumnoRepository(apiClient);
    _repositorioIngresantes = IngresanteRepository(apiClient);
    _repositorioTraslados = TrasladoRepository(apiClient);
    _repositorioCiclos = CicloLectivoRepository(apiClient);
    _repositorioCursos = CursoRepository(apiClient);
    _repositorioNiveles = NivelRepository(apiClient);
    _cargarInicial();
  }

  @override
  void dispose() {
    _debounceBusqueda?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  /// `_cursosDelCiclo` llega del backend en el orden en que se crearon
  /// los cursos, no por año — acá se reordena por `numero_orden` real
  /// de `Nivel` (no el nombre) y, dentro de cada año, por división (por
  /// `id`, ya que no hay un orden explícito de división en el modelo).
  /// Mismo criterio que `InscripcionPorCursoScreen._cursosOrdenados`.
  List<Curso> get _cursosOrdenados {
    final ordenPorNivel = {for (final nivel in _niveles) nivel.id: nivel.numeroOrden};
    final lista = [..._cursosDelCiclo];
    lista.sort((a, b) {
      final ordenA = ordenPorNivel[a.nivelId] ?? 0;
      final ordenB = ordenPorNivel[b.nivelId] ?? 0;
      if (ordenA != ordenB) return ordenA.compareTo(ordenB);
      return a.divisionId.compareTo(b.divisionId);
    });
    return lista;
  }

  List<Curso> get _cursosDeNivelUno {
    Nivel? nivelUno;
    for (final nivel in _niveles) {
      if (nivel.numeroOrden == 1) {
        nivelUno = nivel;
        break;
      }
    }
    if (nivelUno == null) return const [];
    final cursos = _cursosDelCiclo.where((c) => c.nivelId == nivelUno!.id).toList();
    cursos.sort((a, b) => a.divisionId.compareTo(b.divisionId));
    return cursos;
  }

  Future<void> _cargarInicial() async {
    setState(() {
      _cargandoInicial = true;
      _errorCarga = null;
    });

    try {
      final ciclos = await _repositorioCiclos.obtenerTodos();
      CicloLectivo? abierto;
      for (final ciclo in ciclos) {
        if (ciclo.abierto) {
          abierto = ciclo;
          break;
        }
      }

      final resultados = await Future.wait([
        _repositorioNiveles.obtenerTodos(),
        abierto == null ? Future.value(<Curso>[]) : _repositorioCursos.obtenerDeCiclo(abierto.id),
      ]);

      if (!mounted) return;
      setState(() {
        _cicloActual = abierto;
        _niveles = resultados[0] as List<Nivel>;
        _cursosDelCiclo = resultados[1] as List<Curso>;
        _cargandoInicial = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargandoInicial = false;
        _errorCarga = error;
      });
    }
  }

  /// Se dispara con cada tecla del campo de búsqueda, pero con un
  /// debounce de 400ms y un mínimo de 2 caracteres — así no se manda
  /// una petición por cada letra tipeada, ni se buscan coincidencias
  /// tan cortas que devuelvan medio padrón. Vaciar el campo del todo
  /// también dispara (sin esperar el mínimo) para limpiar los
  /// resultados enseguida.
  void _onCambioBusqueda(String texto) {
    _debounceBusqueda?.cancel();
    final trimmed = texto.trim();
    if (trimmed.isEmpty) {
      _buscar();
      return;
    }
    if (trimmed.length < 2) return;
    _debounceBusqueda = Timer(const Duration(milliseconds: 400), _buscar);
  }

  /// A propósito NO le pide nada al backend si no hay ningún filtro
  /// activo (ni texto de búsqueda ni curso elegido) — con ~700 alumnos
  /// en una institución grande, ese es justo el pedido que hay que
  /// evitar. El botón "Buscar" y el campo de texto (con su propio
  /// mínimo de caracteres, ver `_onCambioBusqueda`) son las únicas
  /// puertas de entrada.
  Future<void> _buscar() async {
    final busqueda = _busquedaController.text.trim();
    if (busqueda.isEmpty && _filtroCursoId == null) {
      setState(() {
        _alumnos = const [];
        _cargando = false;
      });
      return;
    }

    setState(() => _cargando = true);
    try {
      final alumnos = await _repositorio.obtenerTodos(
        busqueda: busqueda,
        cursoId: _filtroCursoId,
      );
      if (!mounted) return;
      setState(() {
        _alumnos = alumnos;
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _abrirAlta() async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioAlta(
        repositorio: _repositorio,
        repositorioIngresantes: _repositorioIngresantes,
        cicloActual: _cicloActual,
        cursosDeNivelUno: _cursosDeNivelUno,
      ),
    );
    if (resultado == true) _buscar();
  }

  /// A diferencia de `_buscar()` (que a propósito no trae nada sin un
  /// filtro), acá SÍ hace falta la matrícula completa — es la única
  /// forma de calcular cuántos alumnos tiene cada curso en la grilla de
  /// `InscripcionPorCursoScreen`. Se pide en el momento en que se entra
  /// a este panel (no en la carga inicial de Alumnos), así que solo la
  /// paga quien realmente lo usa.
  Future<void> _abrirInscripcionPorCurso() async {
    if (_cicloActual == null) return;
    setState(() => _cargandoInscripcionPorCurso = true);
    try {
      final todos = await _repositorio.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _alumnosParaInscripcionPorCurso = todos;
        _modoInscripcionPorCurso = true;
        _cargandoInscripcionPorCurso = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _cargandoInscripcionPorCurso = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje), backgroundColor: AppColors.error),
      );
    }
  }

  void _cerrarInscripcionPorCurso({required bool alumnosAgregados}) {
    setState(() => _modoInscripcionPorCurso = false);
    if (alumnosAgregados) _buscar();
  }

  Future<void> _abrirEditar(Alumno alumno) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioEditarAlumno(repositorio: _repositorio, alumno: alumno),
    );
    if (resultado == true) _buscar();
  }

  Future<void> _abrirTraslado(Alumno alumno) async {
    if (_cicloActual == null) return;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioTraslado(
        repositorio: _repositorioTraslados,
        cicloLectivoId: _cicloActual!.id,
        cursosDelCiclo: _cursosOrdenados,
        alumno: alumno,
      ),
    );
    if (resultado == true) _buscar();
  }

  Future<void> _abrirBaja(Alumno alumno) async {
    final inscripcion = alumno.inscripcionActual;
    if (inscripcion == null) return;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioBajaInscripcion(
        repositorio: _repositorioTraslados,
        inscripcionId: inscripcion.id,
        alumno: alumno,
      ),
    );
    if (resultado == true) _buscar();
  }

  Future<void> _verEliminados() async {
    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAlumnosEliminados(repositorio: _repositorio),
    );
    if (huboRestauracion == true) _buscar();
  }

  Future<void> _confirmarEliminar(Alumno alumno) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar legajo'),
        content: Text(
          '¿Eliminar el legajo de "${alumno.nombreCompleto}"? Se puede '
          'restaurar más adelante si hace falta. Si tiene una '
          'inscripción activa en el ciclo actual, primero hay que darla '
          'de baja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      await _repositorio.eliminar(alumno.id);
      _buscar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoInicial && _errorCarga == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BannerError(mensaje: _errorCarga!.mensaje),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _cargarInicial,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_modoInscripcionPorCurso) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: InscripcionPorCursoScreen(
              repositorioAlumnos: _repositorio,
              repositorioTraslados: _repositorioTraslados,
              cicloLectivoId: _cicloActual!.id,
              cursosDelCiclo: _cursosDelCiclo,
              niveles: _niveles,
              alumnos: _alumnosParaInscripcionPorCurso,
              onCerrar: _cerrarInscripcionPorCurso,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alumnos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'El legajo de cada alumno y en qué curso está en el '
                        'ciclo lectivo actual.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textoSecundario,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _verEliminados,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Ver eliminados'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: (_cicloActual == null ||
                          _cursosDelCiclo.isEmpty ||
                          _cargandoInscripcionPorCurso)
                      ? null
                      : _abrirInscripcionPorCurso,
                  icon: _cargandoInscripcionPorCurso
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('Inscribir por curso'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _abrirAlta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulPrimario,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_cicloActual == null)
              const BannerInfo(
                mensaje: 'No hay un ciclo lectivo abierto. Podés seguir '
                    'cargando legajos, pero no vas a poder anotarlos en '
                    'ningún curso (ni como ingresantes ni con "Trasladar") '
                    'hasta que haya uno.',
              )
            else
              const BannerInfo(
                mensaje: 'El legajo es el dato permanente del alumno. '
                    'Asignarlo a un curso es un paso aparte: al cargarlo '
                    'como ingresante ya queda en 1er año, o después podés '
                    'anotarlo o moverlo con "Trasladar" (recursantes, '
                    'cambios de división, pases).',
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _busquedaController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, apellido o DNI',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: _onCambioBusqueda,
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                if (_cursosDelCiclo.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _filtroCursoId,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      hint: const Text('Todos los cursos', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Todos los cursos')),
                        ..._cursosOrdenados.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text('${c.nivelNombre ?? ''} ${c.divisionNombre ?? ''}'),
                          ),
                        ),
                      ],
                      onChanged: (valor) {
                        setState(() => _filtroCursoId = valor);
                        _buscar();
                      },
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _buscar,
                  child: const Text('Buscar'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_alumnos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  _busquedaController.text.trim().isEmpty && _filtroCursoId == null
                      ? 'Buscá por nombre, apellido o DNI, o elegí un curso para '
                          'ver su listado — con la matrícula completa de la '
                          'institución no tiene sentido mostrarlos a todos '
                          'de entrada.'
                      : 'No se encontró ningún alumno con estos filtros.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._alumnos.map(
                (alumno) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaAlumno(
                    alumno: alumno,
                    hayCicloAbierto: _cicloActual != null,
                    onEditar: () => _abrirEditar(alumno),
                    onEliminar: () => _confirmarEliminar(alumno),
                    onTrasladar: () => _abrirTraslado(alumno),
                    onDarDeBaja: () => _abrirBaja(alumno),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaAlumno extends StatelessWidget {
  const _FilaAlumno({
    required this.alumno,
    required this.hayCicloAbierto,
    required this.onEditar,
    required this.onEliminar,
    required this.onTrasladar,
    required this.onDarDeBaja,
  });

  final Alumno alumno;
  final bool hayCicloAbierto;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onTrasladar;
  final VoidCallback onDarDeBaja;

  @override
  Widget build(BuildContext context) {
    final inscripcion = alumno.inscripcionActual;
    final tieneInscripcionActiva = inscripcion != null && inscripcion.estado == 'activo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alumno.nombreCompleto,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'DNI ${alumno.dni}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 8),
                if (inscripcion == null)
                  const Text(
                    'Sin curso asignado en el ciclo actual.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textoSecundario,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Chip(texto: inscripcion.curso ?? 'Curso #${inscripcion.cursoId}'),
                      _Chip(texto: inscripcion.condicion),
                      _Chip(
                        texto: inscripcion.estado,
                        color: inscripcion.estado == 'activo' ? AppColors.azulPrimario : AppColors.error,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.textoSecundario),
                    tooltip: 'Editar legajo',
                    onPressed: onEditar,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.error),
                    tooltip: 'Eliminar legajo',
                    onPressed: onEliminar,
                  ),
                ],
              ),
              if (hayCicloAbierto)
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton.icon(
                      onPressed: onTrasladar,
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: Text(inscripcion == null ? 'Asignar curso' : 'Trasladar'),
                    ),
                    if (tieneInscripcionActiva)
                      TextButton.icon(
                        onPressed: onDarDeBaja,
                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Dar de baja'),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colorFinal = color ?? AppColors.azulPrimario;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorFinal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(texto, style: TextStyle(fontSize: 10.5, color: colorFinal)),
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

/// Alta de un alumno nuevo — con un selector arriba de todo para elegir
/// entre los dos casos que cubre el backend (ver el docblock de
/// `AlumnosScreen`): ingresante nuevo de 1er año, o legajo sin curso
/// (pase a un año superior).
class _FormularioAlta extends StatefulWidget {
  const _FormularioAlta({
    required this.repositorio,
    required this.repositorioIngresantes,
    required this.cicloActual,
    required this.cursosDeNivelUno,
  });

  final AlumnoRepository repositorio;
  final IngresanteRepository repositorioIngresantes;
  final CicloLectivo? cicloActual;
  final List<Curso> cursosDeNivelUno;

  @override
  State<_FormularioAlta> createState() => _FormularioAltaState();
}

class _FormularioAltaState extends State<_FormularioAlta> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _dniController = TextEditingController();

  late bool _esIngresante;
  DateTime? _fechaNacimiento;
  DateTime? _fechaIngreso;
  int? _cursoId;

  bool _guardando = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _esIngresante = widget.cicloActual != null && widget.cursosDeNivelUno.isNotEmpty;
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
    if (_esIngresante && _cursoId == null) {
      setState(() => _error = ApiException(mensaje: 'Elija un curso de 1er año.'));
      return;
    }

    setState(() => _guardando = true);

    try {
      final nombre = _nombreController.text.trim();
      final apellido = _apellidoController.text.trim();
      final dni = _dniController.text.trim();
      final fechaNacimientoIso = _fechaNacimiento == null ? null : _fechaIso(_fechaNacimiento!);
      final fechaIngresoIso = _fechaIso(_fechaIngreso!);

      if (_esIngresante) {
        await widget.repositorioIngresantes.crear(
          cicloLectivoId: widget.cicloActual!.id,
          nombre: nombre,
          apellido: apellido,
          dni: dni,
          fechaNacimiento: fechaNacimientoIso,
          fechaIngresoInstitucion: fechaIngresoIso,
          cursoId: _cursoId!,
        );
      } else {
        await widget.repositorio.crear(
          nombre: nombre,
          apellido: apellido,
          dni: dni,
          fechaNacimiento: fechaNacimientoIso,
          fechaIngresoInstitucion: fechaIngresoIso,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar alumno'),
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
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Ingresante nuevo (1er año)', style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    'Crea el legajo y lo anota directo en un curso de 1er año.',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: true,
                  groupValue: _esIngresante,
                  onChanged: widget.cicloActual == null || widget.cursosDeNivelUno.isEmpty
                      ? null
                      : (valor) => setState(() => _esIngresante = valor ?? true),
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Legajo sin curso (pase a año superior)', style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    'Solo crea el legajo — después se lo asigna a un curso con "Trasladar".',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: false,
                  groupValue: _esIngresante,
                  onChanged: (valor) => setState(() => _esIngresante = valor ?? false),
                ),
                if (widget.cicloActual == null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'No hay ciclo lectivo abierto — solo se puede cargar el legajo.',
                      style: TextStyle(fontSize: 11, color: AppColors.textoSecundario),
                    ),
                  )
                else if (widget.cursosDeNivelUno.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Todavía no hay ningún curso de 1er año cargado en '
                      '"Cursos" — solo se puede cargar el legajo.',
                      style: TextStyle(fontSize: 11, color: AppColors.textoSecundario),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreController,
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
                TextFormField(
                  controller: _dniController,
                  decoration: const InputDecoration(labelText: 'DNI'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el DNI.' : null,
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
                    decoration: const InputDecoration(labelText: 'Fecha de ingreso a la institución'),
                    child: Text(
                      _fechaIngreso == null ? 'Elegir fecha' : _fechaLegible(_fechaIngreso!),
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ),
                if (_esIngresante && widget.cursosDeNivelUno.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: _cursoId,
                    decoration: const InputDecoration(labelText: 'Curso de 1er año'),
                    items: widget.cursosDeNivelUno
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.nivelNombre ?? ''} ${c.divisionNombre ?? ''}'),
                            ))
                        .toList(growable: false),
                    onChanged: (valor) => setState(() => _cursoId = valor),
                  ),
                ],
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

/// Edición del legajo de un alumno ya existente — mismos campos que el
/// alta de "legajo sin curso", sin el selector de modo.
class _FormularioEditarAlumno extends StatefulWidget {
  const _FormularioEditarAlumno({required this.repositorio, required this.alumno});

  final AlumnoRepository repositorio;
  final Alumno alumno;

  @override
  State<_FormularioEditarAlumno> createState() => _FormularioEditarAlumnoState();
}

class _FormularioEditarAlumnoState extends State<_FormularioEditarAlumno> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _dniController;
  DateTime? _fechaNacimiento;
  DateTime? _fechaIngreso;

  bool _guardando = false;
  ApiException? _error;

  static final _regexIdEnMensaje = RegExp(r'\(id (\d+)\)');

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.alumno.nombre);
    _apellidoController = TextEditingController(text: widget.alumno.apellido);
    _dniController = TextEditingController(text: widget.alumno.dni);
    _fechaNacimiento = _parseIso(widget.alumno.fechaNacimiento);
    _fechaIngreso = _parseIso(widget.alumno.fechaIngresoInstitucion);
  }

  DateTime? _parseIso(String? iso) => iso == null ? null : DateTime.tryParse(iso);

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  int? get _idParaRestaurar {
    final mensaje = _error?.mensaje ?? '';
    if (!mensaje.contains('dado de baja') && !mensaje.contains('dada de baja')) {
      return null;
    }
    final match = _regexIdEnMensaje.firstMatch(mensaje);
    return match == null ? null : int.tryParse(match.group(1)!);
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
      await widget.repositorio.actualizar(
        widget.alumno.id,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        dni: _dniController.text.trim(),
        fechaNacimiento: _fechaNacimiento == null ? null : _fechaIso(_fechaNacimiento!),
        fechaIngresoInstitucion: _fechaIso(_fechaIngreso!),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  Future<void> _restaurar(int id) async {
    setState(() => _guardando = true);
    try {
      await widget.repositorio.restaurar(id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final idParaRestaurar = _idParaRestaurar;

    return AlertDialog(
      title: const Text('Editar legajo'),
      content: SizedBox(
        width: 400,
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
                  if (idParaRestaurar != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _guardando ? null : () => _restaurar(idParaRestaurar),
                        icon: const Icon(Icons.restore_outlined, size: 18),
                        label: const Text('Restaurar en vez de usar este DNI de nuevo'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreController,
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
                TextFormField(
                  controller: _dniController,
                  decoration: const InputDecoration(labelText: 'DNI'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el DNI.' : null,
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
                    decoration: const InputDecoration(labelText: 'Fecha de ingreso a la institución'),
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

/// Asignar/mover a un alumno de curso dentro del ciclo abierto — ver
/// `TrasladoRepository`.
class _FormularioTraslado extends StatefulWidget {
  const _FormularioTraslado({
    required this.repositorio,
    required this.cicloLectivoId,
    required this.cursosDelCiclo,
    required this.alumno,
  });

  final TrasladoRepository repositorio;
  final int cicloLectivoId;
  final List<Curso> cursosDelCiclo;
  final Alumno alumno;

  @override
  State<_FormularioTraslado> createState() => _FormularioTrasladoState();
}

class _FormularioTrasladoState extends State<_FormularioTraslado> {
  int? _cursoId;
  String? _condicion;
  bool _guardando = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _cursoId = widget.alumno.inscripcionActual?.cursoId;
    _condicion = widget.alumno.inscripcionActual?.condicion ?? 'regular';
  }

  Future<void> _guardar() async {
    if (_cursoId == null) {
      setState(() => _error = ApiException(mensaje: 'Elija un curso.'));
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.repositorio.trasladar(
        cicloLectivoId: widget.cicloLectivoId,
        alumnoId: widget.alumno.id,
        cursoId: _cursoId!,
        condicion: _condicion!,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Trasladar a ${widget.alumno.nombreCompleto}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              BannerError(mensaje: _error!.mensaje),
              const SizedBox(height: 12),
            ],
            const Text('Curso', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _cursoId,
              items: widget.cursosDelCiclo
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.nivelNombre ?? ''} ${c.divisionNombre ?? ''}'),
                      ))
                  .toList(growable: false),
              onChanged: (valor) => setState(() => _cursoId = valor),
            ),
            const SizedBox(height: 14),
            const Text('Condición', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _condicion,
              items: const [
                DropdownMenuItem(value: 'regular', child: Text('Regular')),
                DropdownMenuItem(value: 'recursante', child: Text('Recursante')),
              ],
              onChanged: (valor) => setState(() => _condicion = valor),
            ),
          ],
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

/// Baja de la inscripción actual de un alumno (abandono a mitad de
/// año) — no toca el legajo, ver `TrasladoRepository.darDeBaja()`.
class _FormularioBajaInscripcion extends StatefulWidget {
  const _FormularioBajaInscripcion({
    required this.repositorio,
    required this.inscripcionId,
    required this.alumno,
  });

  final TrasladoRepository repositorio;
  final int inscripcionId;
  final Alumno alumno;

  @override
  State<_FormularioBajaInscripcion> createState() => _FormularioBajaInscripcionState();
}

class _FormularioBajaInscripcionState extends State<_FormularioBajaInscripcion> {
  final _motivoController = TextEditingController();
  DateTime? _fechaBaja;
  bool _guardando = false;
  ApiException? _error;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaBaja ?? ahora,
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 1),
      helpText: 'Fecha de baja',
    );
    if (fecha == null) return;
    setState(() => _fechaBaja = fecha);
  }

  Future<void> _guardar() async {
    final motivo = _motivoController.text.trim();
    if (motivo.isEmpty) {
      setState(() => _error = ApiException(mensaje: 'Ingrese el motivo de la baja.'));
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.repositorio.darDeBaja(
        widget.inscripcionId,
        motivoBaja: motivo,
        fechaBaja: _fechaBaja == null ? null : _fechaIso(_fechaBaja!),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Dar de baja a ${widget.alumno.nombreCompleto}'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              BannerError(mensaje: _error!.mensaje),
              const SizedBox(height: 12),
            ],
            const Text(
              'Da de baja la inscripción de este alumno en el ciclo actual '
              '(abandono, cambio de institución). El legajo no se toca.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _motivoController,
              decoration: const InputDecoration(labelText: 'Motivo'),
              maxLines: 2,
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Fecha de baja (opcional)'),
                child: Text(
                  _fechaBaja == null ? 'Hoy' : _fechaLegible(_fechaBaja!),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
          child: _guardando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Dar de baja'),
        ),
      ],
    );
  }
}

/// Lista de legajos dados de baja, con botón de restaurar por fila —
/// ver `_AlumnosScreenState._verEliminados()`.
class _DialogoAlumnosEliminados extends StatefulWidget {
  const _DialogoAlumnosEliminados({required this.repositorio});

  final AlumnoRepository repositorio;

  @override
  State<_DialogoAlumnosEliminados> createState() => _DialogoAlumnosEliminadosState();
}

class _DialogoAlumnosEliminadosState extends State<_DialogoAlumnosEliminados> {
  bool _cargando = true;
  ApiException? _error;
  List<Alumno> _eliminados = const [];

  bool _huboRestauracion = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final eliminados = await widget.repositorio.obtenerEliminados();
      if (!mounted) return;
      setState(() {
        _eliminados = eliminados;
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = error;
      });
    }
  }

  Future<void> _restaurar(Alumno alumno) async {
    try {
      await widget.repositorio.restaurar(alumno.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(() => _eliminados = _eliminados.where((a) => a.id != alumno.id).toList());
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Legajos eliminados'),
      content: SizedBox(
        width: 420,
        child: _cargando
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? BannerError(mensaje: _error!.mensaje)
                : _eliminados.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No hay ningún legajo eliminado.',
                          style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _eliminados.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final alumno = _eliminados[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(alumno.nombreCompleto),
                              subtitle: Text('DNI ${alumno.dni}'),
                              trailing: TextButton.icon(
                                onPressed: () => _restaurar(alumno),
                                icon: const Icon(Icons.restore_outlined, size: 18),
                                label: const Text('Restaurar'),
                              ),
                            );
                          },
                        ),
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_huboRestauracion),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}


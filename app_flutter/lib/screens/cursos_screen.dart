import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ciclo_lectivo.dart';
import '../models/curso.dart';
import '../models/division.dart';
import '../models/nivel.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/ciclo_lectivo_repository.dart';
import '../services/curso_repository.dart';
import '../services/division_repository.dart';
import '../services/nivel_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

const _turnos = ['mañana', 'tarde', 'noche'];

/// Sección "Cursos" del panel de escritorio — CRUD contra
/// `/ciclos-lectivos/{ciclo}/cursos` y `/cursos/{curso}` (ver
/// `CursosController` en el backend).
///
/// Un curso es nivel + división + el ciclo lectivo actual + turno —
/// ver la conversación del 12/08/2026 sobre por qué Niveles y
/// Divisiones son catálogos independientes que recién se combinan acá.
/// Por eso la pantalla se organiza por nivel: una tarjeta por nivel, y
/// adentro los cursos (división + turno) que YA se armaron para ese
/// nivel en el ciclo lectivo actual, con su propio botón de alta — así
/// nunca hace falta elegir el nivel a mano, ya está implícito en la
/// tarjeta donde se toca "Agregar".

class CursosScreen extends StatefulWidget {
  const CursosScreen({super.key});

  @override
  State<CursosScreen> createState() => _CursosScreenState();
}

class _CursosScreenState extends State<CursosScreen> {
  late final NivelRepository _repositorioNiveles;
  late final DivisionRepository _repositorioDivisiones;
  late final CicloLectivoRepository _repositorioCiclos;
  late final CursoRepository _repositorioCursos;

  bool _cargando = true;
  ApiException? _errorCarga;

  List<Nivel> _niveles = const [];
  List<Division> _divisiones = const [];
  CicloLectivo? _cicloActual;
  List<Curso> _cursos = const [];

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthProvider>().apiClient;
    _repositorioNiveles = NivelRepository(apiClient);
    _repositorioDivisiones = DivisionRepository(apiClient);
    _repositorioCiclos = CicloLectivoRepository(apiClient);
    _repositorioCursos = CursoRepository(apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final niveles = await _repositorioNiveles.obtenerTodos();
      final divisiones = await _repositorioDivisiones.obtenerTodos();
      final ciclos = await _repositorioCiclos.obtenerTodos();

      CicloLectivo? cicloActual;
      if (ciclos.isNotEmpty) {
        cicloActual = ciclos.firstWhere(
          (c) => c.abierto,
          orElse: () => ciclos.first,
        );
      }

      final cursos = cicloActual == null
          ? <Curso>[]
          : await _repositorioCursos.obtenerDeCiclo(cicloActual.id);

      if (!mounted) return;
      setState(() {
        _niveles = niveles;
        _divisiones = divisiones;
        _cicloActual = cicloActual;
        _cursos = cursos;
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorCarga = error;
      });
    }
  }

  List<Curso> _cursosDeNivel(int nivelId) =>
      _cursos.where((c) => c.nivelId == nivelId).toList(growable: false);

  Future<void> _abrirFormularioCurso(Nivel nivel) async {
    final cicloActual = _cicloActual;
    if (cicloActual == null) return;

    final divisionesDisponibles = _divisiones
        .where((d) => !_cursosDeNivel(nivel.id).any((c) => c.divisionId == d.id))
        .toList(growable: false);

    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioCurso(
        repositorio: _repositorioCursos,
        cicloLectivoId: cicloActual.id,
        nivel: nivel,
        divisionesDisponibles: divisionesDisponibles,
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  Future<void> _editarTurno(Curso curso) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioTurno(repositorio: _repositorioCursos, curso: curso),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(Curso curso) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar curso'),
        content: Text(
          '¿Eliminar "${curso.nivelNombre} ${curso.divisionNombre}"? Se '
          'puede restaurar más adelante si hace falta. Si ya tiene '
          'alumnos inscriptos, el sistema no va a dejar eliminarlo.',
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
      await _repositorioCursos.eliminar(curso.id);
      _cargar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _verEliminados() async {
    final cicloActual = _cicloActual;
    if (cicloActual == null) return;

    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoCursosEliminados(
        repositorio: _repositorioCursos,
        cicloLectivoId: cicloActual.id,
      ),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
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
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cursos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _cicloActual == null
                            ? 'Todavía no hay un ciclo lectivo abierto.'
                            : 'Cursos del ciclo lectivo ${_cicloActual!.anio}.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textoSecundario,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cicloActual != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _verEliminados,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Ver eliminados'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const BannerInfo(
              mensaje: 'Cada tarjeta de abajo es un año (nivel). Tocá '
                  '"Agregar división" dentro de la tarjeta del año que '
                  'corresponda — no hace falta elegir el nivel a mano, ya '
                  'está fijo en la tarjeta donde estás parado.',
            ),
            const SizedBox(height: 24),
            if (_cicloActual == null)
              _AvisoPrerrequisito(
                icono: Icons.event_repeat_outlined,
                mensaje: 'Primero hay que crear el ciclo lectivo, en la '
                    'sección "Ciclo lectivo" del menú.',
              )
            else if (_niveles.isEmpty)
              _AvisoPrerrequisito(
                icono: Icons.stairs_outlined,
                mensaje: 'Todavía no hay ningún nivel cargado. Cargá al '
                    'menos uno en la sección "Niveles" del menú.',
              )
            else if (_divisiones.isEmpty)
              _AvisoPrerrequisito(
                icono: Icons.view_column_outlined,
                mensaje: 'Todavía no hay ninguna división cargada. Cargá '
                    'al menos una en la sección "Divisiones" del menú.',
              )
            else
              ..._niveles.map(
                (nivel) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _TarjetaNivel(
                    nivel: nivel,
                    cursos: _cursosDeNivel(nivel.id),
                    hayDivisionesDisponibles:
                        _divisiones.length > _cursosDeNivel(nivel.id).length,
                    onAgregar: () => _abrirFormularioCurso(nivel),
                    onEditarTurno: _editarTurno,
                    onEliminar: _confirmarEliminar,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvisoPrerrequisito extends StatelessWidget {
  const _AvisoPrerrequisito({required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        children: [
          Icon(icono, size: 32, color: AppColors.textoSecundario),
          const SizedBox(height: 12),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _TarjetaNivel extends StatelessWidget {
  const _TarjetaNivel({
    required this.nivel,
    required this.cursos,
    required this.hayDivisionesDisponibles,
    required this.onAgregar,
    required this.onEditarTurno,
    required this.onEliminar,
  });

  final Nivel nivel;
  final List<Curso> cursos;
  final bool hayDivisionesDisponibles;
  final VoidCallback onAgregar;
  final ValueChanged<Curso> onEditarTurno;
  final ValueChanged<Curso> onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
                  nivel.nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textoPrincipal,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: hayDivisionesDisponibles ? onAgregar : null,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar división'),
              ),
            ],
          ),
          if (cursos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Este nivel todavía no tiene ningún curso.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            ...cursos.map(
              (curso) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.azulPrimario.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${nivel.nombre} ${curso.divisionNombre}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.azulPrimario,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Turno ${curso.turno}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textoSecundario),
                      tooltip: 'Editar turno',
                      onPressed: () => onEditarTurno(curso),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      tooltip: 'Eliminar',
                      onPressed: () => onEliminar(curso),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!hayDivisionesDisponibles) ...[
            const SizedBox(height: 6),
            const Text(
              'Ya se usaron todas las divisiones del catálogo en este '
              'nivel. Cargá una división nueva en "Divisiones" si hace '
              'falta otra.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textoSecundario),
            ),
          ],
        ],
      ),
    );
  }
}

/// Alta de un curso — el nivel viene fijo (`nivel`, no seleccionable),
/// porque el usuario ya lo eligió al tocar "Agregar división" en la
/// tarjeta correspondiente.
class _FormularioCurso extends StatefulWidget {
  const _FormularioCurso({
    required this.repositorio,
    required this.cicloLectivoId,
    required this.nivel,
    required this.divisionesDisponibles,
  });

  final CursoRepository repositorio;
  final int cicloLectivoId;
  final Nivel nivel;
  final List<Division> divisionesDisponibles;

  @override
  State<_FormularioCurso> createState() => _FormularioCursoState();
}

class _FormularioCursoState extends State<_FormularioCurso> {
  int? _divisionId;
  String? _turno;
  bool _guardando = false;
  ApiException? _error;
  bool _intentoDeGuardado = false;

  Future<void> _guardar() async {
    setState(() => _intentoDeGuardado = true);

    if (_divisionId == null || _turno == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.repositorio.crear(
        cicloLectivoId: widget.cicloLectivoId,
        nivelId: widget.nivel.id,
        divisionId: _divisionId!,
        turno: _turno!,
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
      title: Text('Agregar división a ${widget.nivel.nombre}'),
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
            // El label de un DropdownButtonFormField solo "flota" arriba
            // del campo cuando ya hay un valor elegido — mientras está
            // vacío vive DENTRO del recuadro, y el menú desplegable se
            // dibuja encima tapándolo por completo (por eso "Turno"
            // desaparecía al abrir la lista). Un Text fijo arriba de
            // cada campo no depende de ese estado y nunca se tapa.
            const Text(
              'División',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _divisionId,
              decoration: InputDecoration(
                errorText: _intentoDeGuardado && _divisionId == null
                    ? 'Elija una división.'
                    : null,
              ),
              items: widget.divisionesDisponibles
                  .map((d) => DropdownMenuItem(value: d.id, child: Text(d.nombre)))
                  .toList(growable: false),
              onChanged: (valor) => setState(() => _divisionId = valor),
            ),
            const SizedBox(height: 14),
            const Text(
              'Turno',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _turno,
              decoration: InputDecoration(
                errorText: _intentoDeGuardado && _turno == null
                    ? 'Elija un turno.'
                    : null,
              ),
              items: _turnos
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(growable: false),
              onChanged: (valor) => setState(() => _turno = valor),
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

/// Edición del turno de un curso ya creado — es el único campo
/// editable (ver `ActualizarCursoRequest` en el backend).
class _FormularioTurno extends StatefulWidget {
  const _FormularioTurno({required this.repositorio, required this.curso});

  final CursoRepository repositorio;
  final Curso curso;

  @override
  State<_FormularioTurno> createState() => _FormularioTurnoState();
}

class _FormularioTurnoState extends State<_FormularioTurno> {
  late String _turno = widget.curso.turno;
  bool _guardando = false;
  ApiException? _error;

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.repositorio.actualizarTurno(widget.curso.id, turno: _turno);
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
      title: Text('Editar turno — ${widget.curso.nivelNombre} ${widget.curso.divisionNombre}'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              BannerError(mensaje: _error!.mensaje),
              const SizedBox(height: 12),
            ],
            const Text(
              'Turno',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _turno,
              decoration: const InputDecoration(),
              items: _turnos
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(growable: false),
              onChanged: (valor) {
                if (valor != null) setState(() => _turno = valor);
              },
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

/// Lista de cursos dados de baja del ciclo actual, con restaurar por
/// fila — mismo patrón que `NivelesScreen`/`DivisionesScreen`.
class _DialogoCursosEliminados extends StatefulWidget {
  const _DialogoCursosEliminados({
    required this.repositorio,
    required this.cicloLectivoId,
  });

  final CursoRepository repositorio;
  final int cicloLectivoId;

  @override
  State<_DialogoCursosEliminados> createState() => _DialogoCursosEliminadosState();
}

class _DialogoCursosEliminadosState extends State<_DialogoCursosEliminados> {
  bool _cargando = true;
  ApiException? _error;
  List<Curso> _eliminados = const [];
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
      final eliminados =
          await widget.repositorio.obtenerEliminadosDeCiclo(widget.cicloLectivoId);
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

  Future<void> _restaurar(Curso curso) async {
    try {
      await widget.repositorio.restaurar(curso.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(() => _eliminados = _eliminados.where((c) => c.id != curso.id).toList());
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
      title: const Text('Cursos eliminados'),
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
                          'No hay ningún curso eliminado en este ciclo.',
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
                            final curso = _eliminados[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${curso.nivelNombre} ${curso.divisionNombre}'),
                              subtitle: Text('Turno ${curso.turno}'),
                              trailing: TextButton.icon(
                                onPressed: () => _restaurar(curso),
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

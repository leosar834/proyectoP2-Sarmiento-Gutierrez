import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumno.dart';
import '../models/ciclo_lectivo.dart';
import '../models/curso.dart';
import '../models/division.dart';
import '../models/especialidad.dart';
import '../models/grupo_ed_fisica.dart';
import '../models/usuario_gestion.dart';
import '../providers/auth_provider.dart';
import '../services/alumno_repository.dart';
import '../services/api_exception.dart';
import '../services/ciclo_lectivo_repository.dart';
import '../services/curso_repository.dart';
import '../services/division_repository.dart';
import '../services/especialidad_repository.dart';
import '../services/grupo_ed_fisica_repository.dart';
import '../services/usuario_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

const _regimenes = ['anual', 'trimestral', 'semestral', 'personalizado'];

/// Sección "Grupos de Educación Física" del panel de escritorio — Fase
/// 4 contra `/ciclos-lectivos/{ciclo}/grupos-ed-fisica` y afines (ver
/// `GruposEdFisicaController` en el backend).
///
/// A diferencia de taller, un grupo de ed. física no depende de un
/// nivel ni de una materia (es una sola bolsa por ciclo) y cada alumno
/// solo puede estar en UN grupo de ed. física a la vez — reasignarlo
/// mueve, no acumula. El profesor es obligatorio desde el alta (la
/// columna no admite NULL).
///
/// Tiene "Ver eliminados" (scopeado al ciclo actual) — mismo
/// razonamiento que `GruposTallerScreen`: la unicidad de
/// `nombre_grupo` usa un `Rule::unique` genérico, sin el mensaje
/// "(id X)" que habilitaría el atajo, así que este listado es la única
/// forma de restaurar un grupo borrado.
class GruposEdFisicaScreen extends StatefulWidget {
  const GruposEdFisicaScreen({super.key});

  @override
  State<GruposEdFisicaScreen> createState() => _GruposEdFisicaScreenState();
}

class _GruposEdFisicaScreenState extends State<GruposEdFisicaScreen> {
  late final DivisionRepository _repositorioDivisiones;
  late final EspecialidadRepository _repositorioEspecialidades;
  late final CicloLectivoRepository _repositorioCiclos;
  late final CursoRepository _repositorioCursos;
  late final GrupoEdFisicaRepository _repositorioGrupos;
  late final UsuarioRepository _repositorioUsuarios;
  late final AlumnoRepository _repositorioAlumnos;

  bool _cargando = true;
  ApiException? _errorCarga;

  List<Division> _divisiones = const [];
  List<Especialidad> _especialidades = const [];
  List<Curso> _cursosDelCiclo = const [];
  List<UsuarioGestion> _usuarios = const [];
  CicloLectivo? _cicloActual;
  List<GrupoEdFisica> _grupos = const [];

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthProvider>().apiClient;
    _repositorioDivisiones = DivisionRepository(apiClient);
    _repositorioEspecialidades = EspecialidadRepository(apiClient);
    _repositorioCiclos = CicloLectivoRepository(apiClient);
    _repositorioCursos = CursoRepository(apiClient);
    _repositorioGrupos = GrupoEdFisicaRepository(apiClient);
    _repositorioUsuarios = UsuarioRepository(apiClient);
    _repositorioAlumnos = AlumnoRepository(apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final divisiones = await _repositorioDivisiones.obtenerTodos();
      final especialidades = await _repositorioEspecialidades.obtenerTodos();
      final ciclos = await _repositorioCiclos.obtenerTodos();
      final usuarios = await _repositorioUsuarios.obtenerTodos();

      CicloLectivo? cicloActual;
      if (ciclos.isNotEmpty) {
        cicloActual = ciclos.firstWhere((c) => c.abierto, orElse: () => ciclos.first);
      }

      final cursos = cicloActual == null
          ? <Curso>[]
          : await _repositorioCursos.obtenerDeCiclo(cicloActual.id);
      final grupos = cicloActual == null
          ? <GrupoEdFisica>[]
          : await _repositorioGrupos.obtenerDeCiclo(cicloActual.id);

      if (!mounted) return;
      setState(() {
        _divisiones = divisiones;
        _especialidades = especialidades;
        _usuarios = usuarios;
        _cicloActual = cicloActual;
        _cursosDelCiclo = cursos;
        _grupos = grupos;
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

  String _nombreUsuario(int usuarioId) {
    for (final usuario in _usuarios) {
      if (usuario.id == usuarioId) return usuario.nombreCompleto;
    }
    return 'Usuario #$usuarioId';
  }

  Future<void> _abrirFormulario({GrupoEdFisica? grupo}) async {
    final cicloActual = _cicloActual;
    if (cicloActual == null) return;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioGrupoEdFisica(
        repositorio: _repositorioGrupos,
        cicloLectivoId: cicloActual.id,
        usuarios: _usuarios,
        grupo: grupo,
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(GrupoEdFisica grupo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo de ed. física'),
        content: Text(
          '¿Eliminar "${grupo.nombreGrupo}"? Si ya tiene alumnos '
          'asignados, el sistema no va a dejar eliminarlo.',
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
      await _repositorioGrupos.eliminar(grupo.id);
      _cargar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _abrirReasignarProfesor(GrupoEdFisica grupo) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoReasignarProfesor(
        repositorio: _repositorioGrupos,
        usuarios: _usuarios,
        grupo: grupo,
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  /// Ver el razonamiento en `EspecialidadesScreen._verEliminados()` —
  /// acá es la única vía de restauración (no hay atajo "(id X)").
  Future<void> _verEliminados() async {
    final cicloActual = _cicloActual;
    if (cicloActual == null) return;

    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoGruposEdFisicaEliminados(
        repositorio: _repositorioGrupos,
        cicloLectivoId: cicloActual.id,
        nombreUsuario: _nombreUsuario,
      ),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  Future<void> _abrirAsignarAlumnos(GrupoEdFisica grupo) async {
    final huboAsignacion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAsignarAlumnosEdFisica(
        repositorioGrupos: _repositorioGrupos,
        repositorioAlumnos: _repositorioAlumnos,
        grupo: grupo,
        cursosDelCiclo: _cursosDelCiclo,
        divisiones: _divisiones,
        especialidades: _especialidades,
      ),
    );
    if (huboAsignacion == true) {
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
        constraints: const BoxConstraints(maxWidth: 820),
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
                        'Grupos de Educación Física',
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
                            : 'Grupos de ed. física del ciclo lectivo ${_cicloActual!.anio}.',
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
                if (_cicloActual != null && _usuarios.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _abrirFormulario(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.azulPrimario,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Agregar'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const BannerInfo(
              mensaje: 'Un alumno solo puede estar en un grupo de ed. '
                  'física a la vez — volver a asignarlo a otro grupo lo '
                  'mueve, no lo duplica.',
            ),
            const SizedBox(height: 24),
            if (_cicloActual == null)
              const _Aviso(
                icono: Icons.event_repeat_outlined,
                mensaje: 'Primero hay que abrir un ciclo lectivo, en la '
                    'sección "Ciclo lectivo" del menú.',
              )
            else if (_usuarios.isEmpty)
              const _Aviso(
                icono: Icons.people_outline,
                mensaje: 'Todavía no hay ningún usuario cargado para poder '
                    'asignarlo como profesor. Cargá al menos uno en '
                    '"Usuarios".',
              )
            else if (_grupos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no hay ningún grupo de ed. física cargado.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._grupos.map(
                (grupo) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaGrupoEdFisica(
                    grupo: grupo,
                    profesorNombre: _nombreUsuario(grupo.profesorId),
                    onEditar: () => _abrirFormulario(grupo: grupo),
                    onEliminar: () => _confirmarEliminar(grupo),
                    onReasignarProfesor: () => _abrirReasignarProfesor(grupo),
                    onAsignarAlumnos: () => _abrirAsignarAlumnos(grupo),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.mensaje});

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

class _FilaGrupoEdFisica extends StatelessWidget {
  const _FilaGrupoEdFisica({
    required this.grupo,
    required this.profesorNombre,
    required this.onEditar,
    required this.onEliminar,
    required this.onReasignarProfesor,
    required this.onAsignarAlumnos,
  });

  final GrupoEdFisica grupo;
  final String profesorNombre;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onReasignarProfesor;
  final VoidCallback onAsignarAlumnos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      grupo.nombreGrupo,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Régimen ${grupo.regimenCursada} · ${grupo.alumnosAsignados} '
                      'alumno${grupo.alumnosAsignados == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.textoSecundario),
                tooltip: 'Editar',
                onPressed: onEditar,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 19, color: AppColors.error),
                tooltip: 'Eliminar',
                onPressed: onEliminar,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.azulPrimario.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Profesor: $profesorNombre',
                style: const TextStyle(fontSize: 11.5, color: AppColors.azulPrimario),
              ),
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onReasignarProfesor,
                icon: const Icon(Icons.badge_outlined, size: 16),
                label: const Text('Cambiar profesor'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onAsignarAlumnos,
                icon: const Icon(Icons.group_add_outlined, size: 16),
                label: const Text('Asignar alumnos'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Alta/edición de un grupo de ed. física. En alta, el profesor es
/// obligatorio (columna NOT NULL); en edición queda afuera a propósito
/// (ver `ActualizarGrupoEdFisicaRequest`) — para cambiarlo después está
/// `_DialogoReasignarProfesor`.
class _FormularioGrupoEdFisica extends StatefulWidget {
  const _FormularioGrupoEdFisica({
    required this.repositorio,
    required this.cicloLectivoId,
    required this.usuarios,
    this.grupo,
  });

  final GrupoEdFisicaRepository repositorio;
  final int cicloLectivoId;
  final List<UsuarioGestion> usuarios;
  final GrupoEdFisica? grupo;

  @override
  State<_FormularioGrupoEdFisica> createState() => _FormularioGrupoEdFisicaState();
}

class _FormularioGrupoEdFisicaState extends State<_FormularioGrupoEdFisica> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  String? _regimenCursada;
  int? _profesorId;

  bool _guardando = false;
  bool _intentoDeGuardado = false;
  ApiException? _error;

  bool get _esEdicion => widget.grupo != null;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.grupo?.nombreGrupo ?? '');
    _regimenCursada = widget.grupo?.regimenCursada;
    _profesorId = widget.grupo?.profesorId;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _intentoDeGuardado = true);

    if (!_formKey.currentState!.validate() || _regimenCursada == null) return;
    if (!_esEdicion && _profesorId == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final nombre = _nombreController.text.trim();

      if (widget.grupo == null) {
        await widget.repositorio.crear(
          cicloLectivoId: widget.cicloLectivoId,
          nombreGrupo: nombre,
          regimenCursada: _regimenCursada!,
          profesorId: _profesorId!,
        );
      } else {
        await widget.repositorio.actualizar(
          widget.grupo!.id,
          nombreGrupo: nombre,
          regimenCursada: _regimenCursada!,
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
      title: Text(_esEdicion ? 'Editar grupo de ed. física' : 'Agregar grupo de ed. física'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                BannerError(mensaje: _error!.mensaje),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre del grupo (ej: Grupo A)'),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre.' : null,
              ),
              const SizedBox(height: 14),
              const Text('Régimen de cursada', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _regimenCursada,
                decoration: InputDecoration(
                  errorText: _intentoDeGuardado && _regimenCursada == null ? 'Elija un régimen.' : null,
                ),
                items: _regimenes
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(growable: false),
                onChanged: (valor) => setState(() => _regimenCursada = valor),
              ),
              if (!_esEdicion) ...[
                const SizedBox(height: 14),
                const Text('Profesor', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: _profesorId,
                  decoration: InputDecoration(
                    errorText: _intentoDeGuardado && _profesorId == null ? 'Elija un profesor.' : null,
                  ),
                  items: widget.usuarios
                      .map((u) => DropdownMenuItem(value: u.id, child: Text(u.nombreCompleto)))
                      .toList(growable: false),
                  onChanged: (valor) => setState(() => _profesorId = valor),
                ),
              ],
            ],
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Reasignación del profesor de un grupo ya existente —
/// `PUT /grupos-ed-fisica/{grupo}/profesor`. A diferencia del personal
/// de taller, acá no hace falta precargar nada: el grupo siempre tiene
/// exactamente un profesor conocido (`grupo.profesorId` viene en
/// `index()`), así que el selector arranca en el valor actual.
class _DialogoReasignarProfesor extends StatefulWidget {
  const _DialogoReasignarProfesor({
    required this.repositorio,
    required this.usuarios,
    required this.grupo,
  });

  final GrupoEdFisicaRepository repositorio;
  final List<UsuarioGestion> usuarios;
  final GrupoEdFisica grupo;

  @override
  State<_DialogoReasignarProfesor> createState() => _DialogoReasignarProfesorState();
}

class _DialogoReasignarProfesorState extends State<_DialogoReasignarProfesor> {
  late int? _profesorId = widget.grupo.profesorId;
  bool _guardando = false;
  ApiException? _error;

  Future<void> _guardar() async {
    if (_profesorId == null) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      await widget.repositorio.asignarProfesor(widget.grupo.id, profesorId: _profesorId!);
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
      title: Text('Cambiar profesor — ${widget.grupo.nombreGrupo}'),
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
            const Text('Profesor', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<int>(
              initialValue: _profesorId,
              items: widget.usuarios
                  .map((u) => DropdownMenuItem(value: u.id, child: Text(u.nombreCompleto)))
                  .toList(growable: false),
              onChanged: (valor) => setState(() => _profesorId = valor),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Asignación de alumnos por lote a un grupo de ed. física —
/// `POST /grupos-ed-fisica/{grupo}/asignar-lote`. A diferencia de
/// taller, no hay restricción de nivel (cualquier curso del ciclo es
/// válido) y REEMPLAZA la membresía de ed. física existente de cada
/// inscripción (un alumno solo puede estar en un grupo a la vez) — ver
/// el docblock de `GrupoEdFisicaRepository.asignarLote()`.
class _DialogoAsignarAlumnosEdFisica extends StatefulWidget {
  const _DialogoAsignarAlumnosEdFisica({
    required this.repositorioGrupos,
    required this.repositorioAlumnos,
    required this.grupo,
    required this.cursosDelCiclo,
    required this.divisiones,
    required this.especialidades,
  });

  final GrupoEdFisicaRepository repositorioGrupos;
  final AlumnoRepository repositorioAlumnos;
  final GrupoEdFisica grupo;
  final List<Curso> cursosDelCiclo;
  final List<Division> divisiones;
  final List<Especialidad> especialidades;

  @override
  State<_DialogoAsignarAlumnosEdFisica> createState() => _DialogoAsignarAlumnosEdFisicaState();
}

class _DialogoAsignarAlumnosEdFisicaState extends State<_DialogoAsignarAlumnosEdFisica> {
  bool _modoManual = false;

  int? _cursoFiltroId;
  int? _divisionFiltroId;
  int? _especialidadFiltroId;

  int? _cursoManualId;
  bool _cargandoAlumnos = false;
  List<Alumno> _alumnosDelCurso = const [];
  final Set<int> _inscripcionesSeleccionadas = {};

  bool _guardando = false;
  bool _intentoDeGuardado = false;
  ApiException? _error;

  Future<void> _cargarAlumnosDelCurso(int cursoId) async {
    setState(() {
      _cargandoAlumnos = true;
      _alumnosDelCurso = const [];
      _inscripcionesSeleccionadas.clear();
    });
    try {
      final alumnos = await widget.repositorioAlumnos.obtenerTodos(cursoId: cursoId);
      if (!mounted) return;
      setState(() {
        _alumnosDelCurso = alumnos.where((a) => a.inscripcionActual?.estado == 'activo').toList();
        _cargandoAlumnos = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargandoAlumnos = false;
        _error = error;
      });
    }
  }

  bool get _hayAlgunFiltro =>
      _cursoFiltroId != null || _divisionFiltroId != null || _especialidadFiltroId != null;

  Future<void> _guardar() async {
    setState(() => _intentoDeGuardado = true);

    if (_modoManual) {
      if (_inscripcionesSeleccionadas.isEmpty) return;
    } else {
      if (!_hayAlgunFiltro) return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final asignados = await widget.repositorioGrupos.asignarLote(
        widget.grupo.id,
        inscripcionIds: _modoManual ? _inscripcionesSeleccionadas.toList() : null,
        cursoId: _modoManual ? null : _cursoFiltroId,
        divisionId: _modoManual ? null : _divisionFiltroId,
        especialidadId: _modoManual ? null : _especialidadFiltroId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$asignados alumno${asignados == 1 ? '' : 's'} asignado${asignados == 1 ? '' : 's'}.')),
      );
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
      title: Text('Asignar alumnos — ${widget.grupo.nombreGrupo}'),
      content: SizedBox(
        width: 460,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              BannerError(mensaje: _error!.mensaje),
              const SizedBox(height: 10),
            ],
            const Text(
              'Si un alumno ya estaba en otro grupo de ed. física de este '
              'ciclo, esta asignación lo mueve a este grupo.',
              style: TextStyle(fontSize: 12, color: AppColors.textoSecundario, height: 1.3),
            ),
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Por filtro'), icon: Icon(Icons.filter_alt_outlined, size: 16)),
                ButtonSegment(value: true, label: Text('Manual'), icon: Icon(Icons.checklist_outlined, size: 16)),
              ],
              selected: {_modoManual},
              onSelectionChanged: (seleccion) => setState(() => _modoManual = seleccion.first),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _modoManual ? _contenidoManual() : _contenidoFiltro(),
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Asignar'),
        ),
      ],
    );
  }

  Widget _contenidoFiltro() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_intentoDeGuardado && !_hayAlgunFiltro)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Elegí al menos un filtro (curso, división o especialidad).',
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          const Text('Curso (opcional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<int?>(
            initialValue: _cursoFiltroId,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('— Cualquiera —')),
              ...widget.cursosDelCiclo.map(
                (c) => DropdownMenuItem<int?>(value: c.id, child: Text('${c.nivelNombre} ${c.divisionNombre}')),
              ),
            ],
            onChanged: (valor) => setState(() => _cursoFiltroId = valor),
          ),
          const SizedBox(height: 14),
          const Text('División (opcional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<int?>(
            initialValue: _divisionFiltroId,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('— Cualquiera —')),
              ...widget.divisiones.map(
                (d) => DropdownMenuItem<int?>(value: d.id, child: Text(d.nombre)),
              ),
            ],
            onChanged: (valor) => setState(() => _divisionFiltroId = valor),
          ),
          const SizedBox(height: 14),
          const Text('Especialidad (opcional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<int?>(
            initialValue: _especialidadFiltroId,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('— Cualquiera —')),
              ...widget.especialidades.map(
                (e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.nombre)),
              ),
            ],
            onChanged: (valor) => setState(() => _especialidadFiltroId = valor),
          ),
          const SizedBox(height: 10),
          const Text(
            'Se asigna a todos los alumnos activos del ciclo que cumplan '
            'los filtros elegidos.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textoSecundario, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _contenidoManual() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Curso', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          initialValue: _cursoManualId,
          decoration: InputDecoration(
            errorText: _intentoDeGuardado && _cursoManualId == null ? 'Elija un curso.' : null,
          ),
          items: widget.cursosDelCiclo
              .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.nivelNombre} ${c.divisionNombre}')))
              .toList(growable: false),
          onChanged: (valor) {
            setState(() => _cursoManualId = valor);
            if (valor != null) _cargarAlumnosDelCurso(valor);
          },
        ),
        const SizedBox(height: 10),
        if (_intentoDeGuardado && _cursoManualId != null && _inscripcionesSeleccionadas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Seleccioná al menos un alumno.',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        Expanded(
          child: _cargandoAlumnos
              ? const Center(child: CircularProgressIndicator())
              : _cursoManualId == null
                  ? const Center(
                      child: Text(
                        'Elegí un curso para ver sus alumnos.',
                        style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                      ),
                    )
                  : _alumnosDelCurso.isEmpty
                      ? const Center(
                          child: Text(
                            'Este curso no tiene alumnos activos.',
                            style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _alumnosDelCurso.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final alumno = _alumnosDelCurso[index];
                            final inscripcionId = alumno.inscripcionActual!.id;
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: _inscripcionesSeleccionadas.contains(inscripcionId),
                              title: Text(alumno.nombreCompleto, style: const TextStyle(fontSize: 13)),
                              subtitle: Text('DNI ${alumno.dni}', style: const TextStyle(fontSize: 11.5)),
                              onChanged: (marcado) {
                                setState(() {
                                  if (marcado ?? false) {
                                    _inscripcionesSeleccionadas.add(inscripcionId);
                                  } else {
                                    _inscripcionesSeleccionadas.remove(inscripcionId);
                                  }
                                });
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

/// Lista de grupos de ed. física dados de baja del ciclo actual, con
/// restaurar por fila — ver
/// `_GruposEdFisicaScreenState._verEliminados()`. Mismo patrón que
/// `_DialogoGruposTallerEliminados` (grupos_taller_screen.dart).
class _DialogoGruposEdFisicaEliminados extends StatefulWidget {
  const _DialogoGruposEdFisicaEliminados({
    required this.repositorio,
    required this.cicloLectivoId,
    required this.nombreUsuario,
  });

  final GrupoEdFisicaRepository repositorio;
  final int cicloLectivoId;
  final String Function(int usuarioId) nombreUsuario;

  @override
  State<_DialogoGruposEdFisicaEliminados> createState() =>
      _DialogoGruposEdFisicaEliminadosState();
}

class _DialogoGruposEdFisicaEliminadosState extends State<_DialogoGruposEdFisicaEliminados> {
  bool _cargando = true;
  ApiException? _error;
  List<GrupoEdFisica> _eliminados = const [];
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

  Future<void> _restaurar(GrupoEdFisica grupo) async {
    try {
      await widget.repositorio.restaurar(grupo.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(() => _eliminados = _eliminados.where((g) => g.id != grupo.id).toList());
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
      title: const Text('Grupos de ed. física eliminados'),
      content: SizedBox(
        width: 440,
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
                          'No hay ningún grupo de ed. física eliminado en este ciclo.',
                          style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _eliminados.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final grupo = _eliminados[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(grupo.nombreGrupo),
                              subtitle: Text(
                                'Régimen ${grupo.regimenCursada} · Profesor '
                                '${widget.nombreUsuario(grupo.profesorId)}',
                              ),
                              trailing: TextButton.icon(
                                onPressed: () => _restaurar(grupo),
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

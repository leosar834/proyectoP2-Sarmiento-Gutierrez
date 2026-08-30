import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumno.dart';
import '../models/ciclo_lectivo.dart';
import '../models/curso.dart';
import '../models/division.dart';
import '../models/especialidad.dart';
import '../models/grupo_taller.dart';
import '../models/materia_taller.dart';
import '../models/nivel.dart';
import '../models/usuario_gestion.dart';
import '../providers/auth_provider.dart';
import '../services/alumno_repository.dart';
import '../services/api_exception.dart';
import '../services/ciclo_lectivo_repository.dart';
import '../services/curso_repository.dart';
import '../services/division_repository.dart';
import '../services/especialidad_repository.dart';
import '../services/grupo_taller_repository.dart';
import '../services/materia_taller_repository.dart';
import '../services/nivel_repository.dart';
import '../services/usuario_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Sección "Grupos de Taller" del panel de escritorio — Fase 4
/// ("redistribución en grupos") contra `/ciclos-lectivos/{ciclo}/grupos-taller`
/// y afines (ver `GruposTallerController` en el backend).
///
/// Un grupo de taller es específico de una MATERIA y un NIVEL dentro
/// del ciclo lectivo abierto — un alumno puede estar simultáneamente en
/// varios grupos de taller (uno por cada materia que cursa). Requiere
/// materias de taller ya cargadas (sección "Materias de Taller").
///
/// Tiene "Ver eliminados" (scopeado al ciclo actual, mismo patrón que
/// `CursosScreen`) — es la única forma de restaurar un grupo borrado,
/// porque la unicidad de `nombre_grupo` se valida con un `Rule::unique`
/// genérico de Laravel, sin el mensaje "(id X)" que habilita el atajo
/// de restauración en otras pantallas.
class GruposTallerScreen extends StatefulWidget {
  const GruposTallerScreen({super.key});

  @override
  State<GruposTallerScreen> createState() => _GruposTallerScreenState();
}

class _GruposTallerScreenState extends State<GruposTallerScreen> {
  late final NivelRepository _repositorioNiveles;
  late final DivisionRepository _repositorioDivisiones;
  late final EspecialidadRepository _repositorioEspecialidades;
  late final MateriaTallerRepository _repositorioMaterias;
  late final CicloLectivoRepository _repositorioCiclos;
  late final CursoRepository _repositorioCursos;
  late final GrupoTallerRepository _repositorioGrupos;
  late final UsuarioRepository _repositorioUsuarios;
  late final AlumnoRepository _repositorioAlumnos;

  bool _cargando = true;
  ApiException? _errorCarga;

  List<Nivel> _niveles = const [];
  List<Division> _divisiones = const [];
  List<Especialidad> _especialidades = const [];
  List<MateriaTaller> _materias = const [];
  List<Curso> _cursosDelCiclo = const [];
  List<UsuarioGestion> _usuarios = const [];
  CicloLectivo? _cicloActual;
  List<GrupoTaller> _grupos = const [];

  int? _filtroMateriaId;
  int? _filtroNivelId;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthProvider>().apiClient;
    _repositorioNiveles = NivelRepository(apiClient);
    _repositorioDivisiones = DivisionRepository(apiClient);
    _repositorioEspecialidades = EspecialidadRepository(apiClient);
    _repositorioMaterias = MateriaTallerRepository(apiClient);
    _repositorioCiclos = CicloLectivoRepository(apiClient);
    _repositorioCursos = CursoRepository(apiClient);
    _repositorioGrupos = GrupoTallerRepository(apiClient);
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
      final niveles = await _repositorioNiveles.obtenerTodos();
      final divisiones = await _repositorioDivisiones.obtenerTodos();
      final especialidades = await _repositorioEspecialidades.obtenerTodos();
      final materias = await _repositorioMaterias.obtenerTodos();
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
          ? <GrupoTaller>[]
          : await _repositorioGrupos.obtenerDeCiclo(cicloActual.id);

      if (!mounted) return;
      setState(() {
        _niveles = niveles;
        _divisiones = divisiones;
        _especialidades = especialidades;
        _materias = materias;
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

  String _nombreNivel(int nivelId) =>
      _niveles.where((n) => n.id == nivelId).map((n) => n.nombre).firstOrNull ?? '—';

  String _nombreMateria(int materiaId) =>
      _materias.where((m) => m.id == materiaId).map((m) => m.nombre).firstOrNull ?? '—';

  List<GrupoTaller> get _gruposFiltrados => _grupos
      .where((g) => _filtroMateriaId == null || g.materiaTallerId == _filtroMateriaId)
      .where((g) => _filtroNivelId == null || g.nivelId == _filtroNivelId)
      .toList();

  Future<void> _abrirFormulario({GrupoTaller? grupo}) async {
    final cicloActual = _cicloActual;
    if (cicloActual == null) return;

    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioGrupoTaller(
        repositorio: _repositorioGrupos,
        cicloLectivoId: cicloActual.id,
        materias: _materias,
        niveles: _niveles,
        grupo: grupo,
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(GrupoTaller grupo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar grupo de taller'),
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

  /// Ver el razonamiento en `EspecialidadesScreen._verEliminados()` —
  /// acá es la única vía de restauración (no hay atajo "(id X)").
  Future<void> _verEliminados() async {
    final cicloActual = _cicloActual;
    if (cicloActual == null) return;

    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoGruposTallerEliminados(
        repositorio: _repositorioGrupos,
        cicloLectivoId: cicloActual.id,
        nombreMateria: _nombreMateria,
        nombreNivel: _nombreNivel,
      ),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  Future<void> _abrirPersonal(GrupoTaller grupo) async {
    final actualizado = await showDialog<GrupoTaller>(
      context: context,
      builder: (_) => _DialogoPersonalGrupoTaller(
        repositorio: _repositorioGrupos,
        usuarios: _usuarios,
        grupo: grupo,
      ),
    );
    if (actualizado != null) {
      setState(() {
        _grupos = _grupos.map((g) => g.id == actualizado.id ? actualizado : g).toList();
      });
    }
  }

  Future<void> _abrirAsignarAlumnos(GrupoTaller grupo) async {
    final cicloActual = _cicloActual;
    if (cicloActual == null) return;

    final huboAsignacion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoAsignarAlumnosTaller(
        repositorioGrupos: _repositorioGrupos,
        repositorioAlumnos: _repositorioAlumnos,
        grupo: grupo,
        nivelNombre: _nombreNivel(grupo.nivelId),
        cursosDelNivel: _cursosDelCiclo.where((c) => c.nivelId == grupo.nivelId).toList(),
        divisiones: _divisiones,
        especialidades: _especialidades,
      ),
    );
    if (huboAsignacion == true) {
      _cargar();
    }
  }

  /// A diferencia de `_abrirAsignarAlumnos`, este diálogo es
  /// mayormente de consulta, pero admite desasignar alumnos puntuales
  /// (para corregir errores de carga) — si hubo alguna desasignación,
  /// el diálogo devuelve `true` y acá se refresca el conteo
  /// `alumnos_asignados` de la tarjeta.
  Future<void> _abrirVerAlumnos(GrupoTaller grupo) async {
    // `barrierDismissible: false`: las desasignaciones pegan a la API al
    // toque (no hay un "Guardar" final), así que forzamos a cerrar con
    // el botón "Cerrar" para no perder el aviso de refrescar el conteo
    // si alguien cierra tocando afuera del diálogo en vez de con el botón.
    final huboCambios = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoAlumnosDeGrupoTaller(
        repositorio: _repositorioGrupos,
        grupo: grupo,
      ),
    );
    if (huboCambios == true) {
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
                        'Grupos de Taller',
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
                            : 'Grupos de taller del ciclo lectivo ${_cicloActual!.anio}.',
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
                if (_cicloActual != null && _materias.isNotEmpty) ...[
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
              mensaje: 'Cada grupo es de una materia y un nivel puntuales. '
                  'Desde cada fila podés asignar el personal (profesor / '
                  'preceptor de taller) y los alumnos que lo cursan.',
            ),
            const SizedBox(height: 24),
            if (_cicloActual == null)
              const _Aviso(
                icono: Icons.event_repeat_outlined,
                mensaje: 'Primero hay que abrir un ciclo lectivo, en la '
                    'sección "Ciclo lectivo" del menú.',
              )
            else if (_materias.isEmpty)
              const _Aviso(
                icono: Icons.construction_outlined,
                mensaje: 'Todavía no hay ninguna materia de taller cargada. '
                    'Cargá al menos una en "Materias de Taller".',
              )
            else ...[
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _filtroMateriaId,
                      decoration: const InputDecoration(labelText: 'Filtrar por materia'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                        ..._materias.map(
                          (m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.nombre)),
                        ),
                      ],
                      onChanged: (valor) => setState(() => _filtroMateriaId = valor),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _filtroNivelId,
                      decoration: const InputDecoration(labelText: 'Filtrar por año'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                        ...(List<Nivel>.from(_niveles)
                              ..sort((a, b) => a.numeroOrden.compareTo(b.numeroOrden)))
                            .map(
                          (n) => DropdownMenuItem<int?>(value: n.id, child: Text(n.nombre)),
                        ),
                      ],
                      onChanged: (valor) => setState(() => _filtroNivelId = valor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_gruposFiltrados.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Todavía no hay ningún grupo de taller cargado.',
                    style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                  ),
                )
              else
                ..._gruposFiltrados.map(
                  (grupo) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FilaGrupoTaller(
                      grupo: grupo,
                      materiaNombre: _nombreMateria(grupo.materiaTallerId),
                      nivelNombre: _nombreNivel(grupo.nivelId),
                      onEditar: () => _abrirFormulario(grupo: grupo),
                      onEliminar: () => _confirmarEliminar(grupo),
                      onPersonal: () => _abrirPersonal(grupo),
                      onAsignarAlumnos: () => _abrirAsignarAlumnos(grupo),
                      onVerAlumnos: () => _abrirVerAlumnos(grupo),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
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

class _FilaGrupoTaller extends StatelessWidget {
  const _FilaGrupoTaller({
    required this.grupo,
    required this.materiaNombre,
    required this.nivelNombre,
    required this.onEditar,
    required this.onEliminar,
    required this.onPersonal,
    required this.onAsignarAlumnos,
    required this.onVerAlumnos,
  });

  final GrupoTaller grupo;
  final String materiaNombre;
  final String nivelNombre;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onPersonal;
  final VoidCallback onAsignarAlumnos;
  final VoidCallback onVerAlumnos;

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
                      '$materiaNombre · $nivelNombre · ${grupo.alumnosAsignados} '
                      'alumno${grupo.alumnosAsignados == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.textoSecundario),
                tooltip: 'Editar nombre',
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
          if (grupo.personal != null && grupo.personal!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: grupo.personal!
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.azulPrimario.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${p.nombreCompleto} (${p.rolEnGrupo == 'profesor' ? 'profesor' : 'preceptor'})',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.azulPrimario),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onPersonal,
                icon: const Icon(Icons.badge_outlined, size: 16),
                label: const Text('Personal'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onAsignarAlumnos,
                icon: const Icon(Icons.group_add_outlined, size: 16),
                label: const Text('Asignar alumnos'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onVerAlumnos,
                icon: const Icon(Icons.list_alt_outlined, size: 16),
                label: const Text('Ver alumnos'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Alta/edición de un grupo de taller. En alta, materia y nivel son
/// elegibles; en edición, solo el nombre (ver `ActualizarGrupoTallerRequest`
/// en el backend).
class _FormularioGrupoTaller extends StatefulWidget {
  const _FormularioGrupoTaller({
    required this.repositorio,
    required this.cicloLectivoId,
    required this.materias,
    required this.niveles,
    this.grupo,
  });

  final GrupoTallerRepository repositorio;
  final int cicloLectivoId;
  final List<MateriaTaller> materias;
  final List<Nivel> niveles;
  final GrupoTaller? grupo;

  @override
  State<_FormularioGrupoTaller> createState() => _FormularioGrupoTallerState();
}

class _FormularioGrupoTallerState extends State<_FormularioGrupoTaller> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  int? _materiaId;
  int? _nivelId;

  bool _guardando = false;
  bool _intentoDeGuardado = false;
  ApiException? _error;

  bool get _esEdicion => widget.grupo != null;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.grupo?.nombreGrupo ?? '');
    _materiaId = widget.grupo?.materiaTallerId;
    _nivelId = widget.grupo?.nivelId;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _intentoDeGuardado = true);

    if (!_formKey.currentState!.validate()) return;
    if (!_esEdicion && (_materiaId == null || _nivelId == null)) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final nombre = _nombreController.text.trim();

      if (widget.grupo == null) {
        await widget.repositorio.crear(
          cicloLectivoId: widget.cicloLectivoId,
          materiaTallerId: _materiaId!,
          nivelId: _nivelId!,
          nombreGrupo: nombre,
        );
      } else {
        await widget.repositorio.actualizar(widget.grupo!.id, nombreGrupo: nombre);
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
      title: Text(_esEdicion ? 'Editar grupo de taller' : 'Agregar grupo de taller'),
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
              if (!_esEdicion) ...[
                const Text('Materia', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: _materiaId,
                  decoration: InputDecoration(
                    errorText:
                        _intentoDeGuardado && _materiaId == null ? 'Elija una materia.' : null,
                  ),
                  items: widget.materias
                      .map((m) => DropdownMenuItem(value: m.id, child: Text(m.nombre)))
                      .toList(growable: false),
                  onChanged: (valor) => setState(() => _materiaId = valor),
                ),
                const SizedBox(height: 14),
                const Text('Nivel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: _nivelId,
                  decoration: InputDecoration(
                    errorText: _intentoDeGuardado && _nivelId == null ? 'Elija un nivel.' : null,
                  ),
                  items: widget.niveles
                      .map((n) => DropdownMenuItem(value: n.id, child: Text(n.nombre)))
                      .toList(growable: false),
                  onChanged: (valor) => setState(() => _nivelId = valor),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre del grupo (ej: Grupo 1)'),
                textInputAction: TextInputAction.done,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre.' : null,
              ),
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

/// Asignación de personal (profesores / preceptores de taller) de un
/// grupo — `PUT /grupos-taller/{grupo}/usuarios`, un sync completo (ver
/// el docblock de `GrupoTallerRepository.asignarUsuarios()`).
///
/// Arranca con la selección precargada desde `grupo.personal` SI el
/// valor ya se conoce en esta sesión (por ejemplo, se abrió esta misma
/// pantalla antes) — si no (`personal == null`, recién se cargó la
/// lista de grupos desde el backend), arranca vacío y lo avisa: el
/// backend no expone un GET de personal actual, solo la respuesta de
/// este mismo endpoint tras guardar.
class _DialogoPersonalGrupoTaller extends StatefulWidget {
  const _DialogoPersonalGrupoTaller({
    required this.repositorio,
    required this.usuarios,
    required this.grupo,
  });

  final GrupoTallerRepository repositorio;
  final List<UsuarioGestion> usuarios;
  final GrupoTaller grupo;

  @override
  State<_DialogoPersonalGrupoTaller> createState() => _DialogoPersonalGrupoTallerState();
}

class _DialogoPersonalGrupoTallerState extends State<_DialogoPersonalGrupoTaller> {
  late final Map<int, String?> _rolPorUsuario;
  String _busqueda = '';
  bool _guardando = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _rolPorUsuario = {
      for (final p in widget.grupo.personal ?? const <PersonalGrupo>[]) p.usuarioId: p.rolEnGrupo,
    };
  }

  List<UsuarioGestion> get _usuariosFiltrados {
    if (_busqueda.trim().isEmpty) return widget.usuarios;
    final termino = _busqueda.trim().toLowerCase();
    return widget.usuarios
        .where((u) => u.nombreCompleto.toLowerCase().contains(termino))
        .toList(growable: false);
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    final asignaciones = _rolPorUsuario.entries
        .where((e) => e.value != null)
        .map((e) => AsignacionPersonalGrupoTaller(usuarioId: e.key, rolEnGrupo: e.value!))
        .toList();

    try {
      final actualizado =
          await widget.repositorio.asignarUsuarios(widget.grupo.id, asignaciones: asignaciones);
      if (!mounted) return;
      Navigator.of(context).pop(actualizado);
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
    final seleccionados = _rolPorUsuario.values.where((v) => v != null).length;

    return AlertDialog(
      title: Text('Personal — ${widget.grupo.nombreGrupo}'),
      content: SizedBox(
        width: 440,
        height: 480,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              BannerError(mensaje: _error!.mensaje),
              const SizedBox(height: 10),
            ],
            if (widget.grupo.personal == null) ...[
              const BannerInfo(
                mensaje: 'Este formulario reemplaza el personal completo del '
                    'grupo. Si ya habías asignado personal antes y esta es '
                    'la primera vez que lo abrís en esta sesión, revisá la '
                    'selección antes de guardar — no se puede recuperar '
                    'automáticamente.',
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar usuario',
                prefixIcon: Icon(Icons.search, size: 20),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            const SizedBox(height: 6),
            Text(
              '$seleccionados seleccionado${seleccionados == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _usuariosFiltrados.isEmpty
                  ? const Center(
                      child: Text(
                        'No se encontró ningún usuario.',
                        style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _usuariosFiltrados.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final usuario = _usuariosFiltrados[index];
                        final rolActual = _rolPorUsuario[usuario.id];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: rolActual != null,
                                onChanged: (marcado) {
                                  setState(() {
                                    _rolPorUsuario[usuario.id] =
                                        (marcado ?? false) ? 'profesor' : null;
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  usuario.nombreCompleto,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (rolActual != null)
                                DropdownButton<String>(
                                  value: rolActual,
                                  underline: const SizedBox.shrink(),
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textoPrincipal),
                                  items: const [
                                    DropdownMenuItem(value: 'profesor', child: Text('Profesor')),
                                    DropdownMenuItem(
                                        value: 'preceptor_taller', child: Text('Preceptor')),
                                  ],
                                  onChanged: (valor) =>
                                      setState(() => _rolPorUsuario[usuario.id] = valor),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Listado de los alumnos asignados a un grupo de taller —
/// `GET /grupos-taller/{grupo}/alumnos`. Mayormente de consulta, pero
/// cada fila admite "Desasignar" para sacar a un alumno puntual (ver
/// `GruposTallerController::desasignarAlumno()`) — pensado para
/// corregir un error de carga puntual, no para reemplazar el lote
/// completo (para eso sigue estando "Asignar alumnos",
/// `_DialogoAsignarAlumnosTaller`).
class _DialogoAlumnosDeGrupoTaller extends StatefulWidget {
  const _DialogoAlumnosDeGrupoTaller({
    required this.repositorio,
    required this.grupo,
  });

  final GrupoTallerRepository repositorio;
  final GrupoTaller grupo;

  @override
  State<_DialogoAlumnosDeGrupoTaller> createState() => _DialogoAlumnosDeGrupoTallerState();
}

class _DialogoAlumnosDeGrupoTallerState extends State<_DialogoAlumnosDeGrupoTaller> {
  bool _cargando = true;
  ApiException? _error;
  List<AlumnoDeGrupoTaller> _alumnos = const [];

  /// Si se desasignó a alguien en esta sesión del diálogo — la pantalla
  /// que lo abrió usa esto para saber si tiene que refrescar el conteo
  /// `alumnos_asignados` de la tarjeta.
  bool _huboCambios = false;

  /// `inscripcionId`s con una desasignación en curso — deshabilita el
  /// botón de esa fila puntual mientras se resuelve, sin bloquear el
  /// resto de la lista.
  final Set<int> _desasignando = {};

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
      final alumnos = await widget.repositorio.obtenerAlumnos(widget.grupo.id);
      if (!mounted) return;
      setState(() {
        _alumnos = alumnos;
        _cargando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _cargando = false;
      });
    }
  }

  Future<void> _confirmarDesasignar(AlumnoDeGrupoTaller alumno) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desasignar alumno'),
        content: Text(
          '¿Sacar a "${alumno.nombreCompleto}" de este grupo? Solo se '
          'desasigna de este grupo puntual — sus demás inscripciones y '
          'grupos de otras materias no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Desasignar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() => _desasignando.add(alumno.inscripcionId));
    try {
      await widget.repositorio.desasignarAlumno(widget.grupo.id, alumno.inscripcionId);
      if (!mounted) return;
      setState(() {
        _alumnos = _alumnos.where((a) => a.inscripcionId != alumno.inscripcionId).toList();
        _desasignando.remove(alumno.inscripcionId);
        _huboCambios = true;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _desasignando.remove(alumno.inscripcionId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Alumnos — ${widget.grupo.nombreGrupo}'),
      content: SizedBox(
        width: 420,
        height: 480,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BannerError(mensaje: _error!.mensaje),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : _alumnos.isEmpty
                    ? const Center(
                        child: Text(
                          'Todavía no hay ningún alumno asignado a este grupo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_alumnos.length} alumno${_alumnos.length == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _alumnos.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final alumno = _alumnos[index];
                                final desasignando = _desasignando.contains(alumno.inscripcionId);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              alumno.nombreCompleto,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                color: AppColors.textoPrincipal,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'DNI ${alumno.dni}'
                                              '${alumno.cursoDivision != null ? ' · ${alumno.cursoDivision}' : ''}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textoSecundario,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      desasignando
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : IconButton(
                                              icon: const Icon(
                                                Icons.person_remove_outlined,
                                                size: 19,
                                                color: AppColors.error,
                                              ),
                                              tooltip: 'Desasignar de este grupo',
                                              onPressed: () => _confirmarDesasignar(alumno),
                                            ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_huboCambios),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Asignación de alumnos por lote a un grupo de taller —
/// `POST /grupos-taller/{grupo}/asignar-lote`. Dos modos mutuamente
/// excluyentes: filtro amplio (curso/división/especialidad) o
/// selección manual de alumnos de un curso puntual — ver el docblock
/// de `GrupoTallerRepository.asignarLote()`.
class _DialogoAsignarAlumnosTaller extends StatefulWidget {
  const _DialogoAsignarAlumnosTaller({
    required this.repositorioGrupos,
    required this.repositorioAlumnos,
    required this.grupo,
    required this.nivelNombre,
    required this.cursosDelNivel,
    required this.divisiones,
    required this.especialidades,
  });

  final GrupoTallerRepository repositorioGrupos;
  final AlumnoRepository repositorioAlumnos;
  final GrupoTaller grupo;
  final String nivelNombre;
  final List<Curso> cursosDelNivel;
  final List<Division> divisiones;
  final List<Especialidad> especialidades;

  @override
  State<_DialogoAsignarAlumnosTaller> createState() => _DialogoAsignarAlumnosTallerState();
}

class _DialogoAsignarAlumnosTallerState extends State<_DialogoAsignarAlumnosTaller> {
  bool _modoManual = false;

  // Modo filtro.
  int? _cursoFiltroId;
  int? _divisionFiltroId;
  int? _especialidadFiltroId;

  // Modo manual.
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
            Text(
              'Nivel del grupo: ${widget.nivelNombre}. La asignación por '
              'filtro siempre se restringe a este nivel.',
              style: const TextStyle(fontSize: 12, color: AppColors.textoSecundario, height: 1.3),
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
              ...widget.cursosDelNivel.map(
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
            'los filtros elegidos (y sean del nivel de este grupo).',
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
          items: widget.cursosDelNivel
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

/// Lista de grupos de taller dados de baja del ciclo actual, con
/// restaurar por fila — ver `_GruposTallerScreenState._verEliminados()`.
/// Mismo patrón que `_DialogoCursosEliminados` (cursos_screen.dart).
class _DialogoGruposTallerEliminados extends StatefulWidget {
  const _DialogoGruposTallerEliminados({
    required this.repositorio,
    required this.cicloLectivoId,
    required this.nombreMateria,
    required this.nombreNivel,
  });

  final GrupoTallerRepository repositorio;
  final int cicloLectivoId;
  final String Function(int materiaId) nombreMateria;
  final String Function(int nivelId) nombreNivel;

  @override
  State<_DialogoGruposTallerEliminados> createState() => _DialogoGruposTallerEliminadosState();
}

class _DialogoGruposTallerEliminadosState extends State<_DialogoGruposTallerEliminados> {
  bool _cargando = true;
  ApiException? _error;
  List<GrupoTaller> _eliminados = const [];
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

  Future<void> _restaurar(GrupoTaller grupo) async {
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
      title: const Text('Grupos de taller eliminados'),
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
                          'No hay ningún grupo de taller eliminado en este ciclo.',
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
                                '${widget.nombreMateria(grupo.materiaTallerId)} · '
                                '${widget.nombreNivel(grupo.nivelId)}',
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/division.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/division_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Sección "Divisiones" del panel de escritorio — CRUD completo contra
/// `/divisiones` (ver `DivisionesController` en el backend).
///
/// Catálogo permanente de la institución, hermano de `NivelesScreen`:
/// las divisiones (1a, 2a...) que, junto con el nivel y el ciclo
/// lectivo, arman un curso.
///

class DivisionesScreen extends StatefulWidget {
  const DivisionesScreen({super.key});

  @override
  State<DivisionesScreen> createState() => _DivisionesScreenState();
}

class _DivisionesScreenState extends State<DivisionesScreen> {
  late final DivisionRepository _repositorio;

  bool _cargando = true;
  ApiException? _errorCarga;
  List<Division> _divisiones = const [];

  @override
  void initState() {
    super.initState();
    _repositorio = DivisionRepository(context.read<AuthProvider>().apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final divisiones = await _repositorio.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _divisiones = divisiones;
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

  Future<void> _abrirFormulario({Division? division}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioDivision(repositorio: _repositorio, division: division),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  /// Mismo mecanismo que `NivelesScreen._verEliminados()` — ver su
  /// docblock.
  Future<void> _verEliminados() async {
    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoDivisionesEliminadas(repositorio: _repositorio),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(Division division) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar división'),
        content: Text(
          '¿Eliminar "${division.nombre}"? Se puede restaurar más adelante '
          'si hace falta.',
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
      await _repositorio.eliminar(division.id);
      _cargar();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.mensaje), backgroundColor: AppColors.error),
      );
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
        constraints: const BoxConstraints(maxWidth: 640),
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
                        'Divisiones',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Las divisiones del establecimiento (1a, 2a...). Se '
                        'usan junto con los niveles para armar los cursos.',
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
                ElevatedButton.icon(
                  onPressed: () => _abrirFormulario(),
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
            const BannerInfo(
              mensaje: 'Segundo paso para la creacion de cursos: Este catálogo es compartido por toda la '
                  'institución. '
                  'Cargue aquí el máximo de divisiones que necesite '
                  'cualquier año (por ejemplo, si el año con más '
                  'matrícula usa 4, cargue 1ra, 2da, 3ra y 4ta una sola vez). Qué '
                  'divisiones le corresponden a cada año se elige '
                  'después, en "Cursos" — no todos los años van a usar '
                  'todas las divisiones de esta lista.',
            ),
            const SizedBox(height: 24),
            if (_divisiones.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no hay ninguna división cargada.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._divisiones.map(
                (division) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaDivision(
                    division: division,
                    onEditar: () => _abrirFormulario(division: division),
                    onEliminar: () => _confirmarEliminar(division),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaDivision extends StatelessWidget {
  const _FilaDivision({
    required this.division,
    required this.onEditar,
    required this.onEliminar,
  });

  final Division division;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.azulPrimario.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.view_column_outlined, size: 16, color: AppColors.azulPrimario),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              division.nombre,
              style: const TextStyle(fontSize: 14, color: AppColors.textoPrincipal),
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
    );
  }
}

/// Alta/edición de una división. Si `division` es `null`, es un alta;
/// si no, edita esa división.
class _FormularioDivision extends StatefulWidget {
  const _FormularioDivision({required this.repositorio, this.division});

  final DivisionRepository repositorio;
  final Division? division;

  @override
  State<_FormularioDivision> createState() => _FormularioDivisionState();
}

class _FormularioDivisionState extends State<_FormularioDivision> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;

  bool _guardando = false;
  ApiException? _error;

  // Mismo mecanismo que `NivelesScreen` — ver su docblock.
  static final _regexIdEnMensaje = RegExp(r'\(id (\d+)\)');

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.division?.nombre ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
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

  Future<void> _guardar() async {
    if (_error != null) {
      setState(() => _error = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final nombre = _nombreController.text.trim();

      if (widget.division == null) {
        await widget.repositorio.crear(nombre: nombre);
      } else {
        await widget.repositorio.actualizar(widget.division!.id, nombre: nombre);
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
      title: Text(widget.division == null ? 'Agregar división' : 'Editar división'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      label: const Text('Restaurar en vez de crear una nueva'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre (ej: 1a)'),
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

/// Lista de divisiones dadas de baja, con botón de restaurar por fila —
/// ver `_DivisionesScreenState._verEliminados()`.
class _DialogoDivisionesEliminadas extends StatefulWidget {
  const _DialogoDivisionesEliminadas({required this.repositorio});

  final DivisionRepository repositorio;

  @override
  State<_DialogoDivisionesEliminadas> createState() =>
      _DialogoDivisionesEliminadasState();
}

class _DialogoDivisionesEliminadasState extends State<_DialogoDivisionesEliminadas> {
  bool _cargando = true;
  ApiException? _error;
  List<Division> _eliminadas = const [];
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
      final eliminadas = await widget.repositorio.obtenerEliminados();
      if (!mounted) return;
      setState(() {
        _eliminadas = eliminadas;
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

  Future<void> _restaurar(Division division) async {
    try {
      await widget.repositorio.restaurar(division.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(
        () => _eliminadas = _eliminadas.where((d) => d.id != division.id).toList(),
      );
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
      title: const Text('Divisiones eliminadas'),
      content: SizedBox(
        width: 400,
        child: _cargando
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? BannerError(mensaje: _error!.mensaje)
                : _eliminadas.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No hay ninguna división eliminada.',
                          style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _eliminadas.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final division = _eliminadas[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(division.nombre),
                              trailing: TextButton.icon(
                                onPressed: () => _restaurar(division),
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

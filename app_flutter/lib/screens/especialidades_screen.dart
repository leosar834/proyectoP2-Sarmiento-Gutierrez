import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/especialidad.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/especialidad_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Sección "Especialidades" del panel de escritorio — CRUD contra
/// `/especialidades` (ver `EspecialidadesController` en el backend).
///
/// Catálogo permanente de la institución (orientaciones como
/// "Electromecánica", "Construcción"), no depende de ningún ciclo
/// lectivo. Es el primer prerrequisito de "Materias de Taller": cada
/// materia cuelga de una especialidad ya cargada acá.
///
/// Tiene "Ver eliminados" (mismo patrón que Niveles/Divisiones) Y el
/// atajo "(id X)" dentro del propio formulario cuando el nombre choca
/// con una dada de baja — dos caminos al mismo lugar, no hace falta
/// elegir uno.
class EspecialidadesScreen extends StatefulWidget {
  const EspecialidadesScreen({super.key});

  @override
  State<EspecialidadesScreen> createState() => _EspecialidadesScreenState();
}

class _EspecialidadesScreenState extends State<EspecialidadesScreen> {
  late final EspecialidadRepository _repositorio;

  bool _cargando = true;
  ApiException? _errorCarga;
  List<Especialidad> _especialidades = const [];

  @override
  void initState() {
    super.initState();
    _repositorio = EspecialidadRepository(context.read<AuthProvider>().apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final especialidades = await _repositorio.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _especialidades = especialidades;
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

  Future<void> _abrirFormulario({Especialidad? especialidad}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioEspecialidad(
        repositorio: _repositorio,
        especialidad: especialidad,
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  /// Pedido explícito de la cátedra: la baja lógica tiene que poder
  /// revertirse desde acá, viendo todas las especialidades eliminadas y
  /// eligiendo cuál restaurar — no solo como sugerencia dentro de un
  /// error al chocar con un nombre repetido (`_FormularioEspecialidad`
  /// sigue ofreciendo ese atajo, pero ya no es la única vía).
  Future<void> _verEliminados() async {
    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoEspecialidadesEliminadas(repositorio: _repositorio),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(Especialidad especialidad) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar especialidad'),
        content: Text(
          '¿Eliminar "${especialidad.nombre}"? Se puede restaurar más '
          'adelante creando una nueva con el mismo nombre.',
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
      await _repositorio.eliminar(especialidad.id);
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
                        'Especialidades',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Las orientaciones propias de la institución (ej. '
                        '"Electromecánica", "Construcción"). Se usan para '
                        'agrupar las materias de taller y para distribuir '
                        'alumnos.',
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
              mensaje: 'Cargá acá el catálogo de especialidades antes de '
                  'pasar a "Materias de Taller" — cada materia va a '
                  'colgar de una de estas.',
            ),
            const SizedBox(height: 24),
            if (_especialidades.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no hay ninguna especialidad cargada.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._especialidades.map(
                (especialidad) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaEspecialidad(
                    especialidad: especialidad,
                    onEditar: () => _abrirFormulario(especialidad: especialidad),
                    onEliminar: () => _confirmarEliminar(especialidad),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaEspecialidad extends StatelessWidget {
  const _FilaEspecialidad({
    required this.especialidad,
    required this.onEditar,
    required this.onEliminar,
  });

  final Especialidad especialidad;
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
            child: const Icon(Icons.workspace_premium_outlined,
                size: 17, color: AppColors.azulPrimario),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              especialidad.nombre,
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

/// Alta/edición de una especialidad. Si `especialidad` es `null`, es un
/// alta; si no, edita esa especialidad.
class _FormularioEspecialidad extends StatefulWidget {
  const _FormularioEspecialidad({required this.repositorio, this.especialidad});

  final EspecialidadRepository repositorio;
  final Especialidad? especialidad;

  @override
  State<_FormularioEspecialidad> createState() => _FormularioEspecialidadState();
}

class _FormularioEspecialidadState extends State<_FormularioEspecialidad> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;

  bool _guardando = false;
  ApiException? _error;

  // Ver la nota en `_FormularioNivel` (niveles_screen.dart) — mismo
  // patrón exacto, el backend arma el mensaje como "...(id 123)...".
  static final _regexIdEnMensaje = RegExp(r'\(id (\d+)\)');

  @override
  void initState() {
    super.initState();
    _nombreController =
        TextEditingController(text: widget.especialidad?.nombre ?? '');
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

      if (widget.especialidad == null) {
        await widget.repositorio.crear(nombre: nombre);
      } else {
        await widget.repositorio.actualizar(widget.especialidad!.id, nombre: nombre);
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
      title: Text(widget.especialidad == null ? 'Agregar especialidad' : 'Editar especialidad'),
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
                decoration: const InputDecoration(labelText: 'Nombre (ej: Electromecánica)'),
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

/// Lista de especialidades dadas de baja, con botón de restaurar por
/// fila — ver `_EspecialidadesScreenState._verEliminados()`. Mismo
/// patrón que `_DialogoNivelesEliminados` (niveles_screen.dart).
class _DialogoEspecialidadesEliminadas extends StatefulWidget {
  const _DialogoEspecialidadesEliminadas({required this.repositorio});

  final EspecialidadRepository repositorio;

  @override
  State<_DialogoEspecialidadesEliminadas> createState() =>
      _DialogoEspecialidadesEliminadasState();
}

class _DialogoEspecialidadesEliminadasState extends State<_DialogoEspecialidadesEliminadas> {
  bool _cargando = true;
  ApiException? _error;
  List<Especialidad> _eliminadas = const [];

  // Se devuelve al cerrar para que la pantalla de atrás sepa si tiene
  // que refrescar su lista de especialidades activas.
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

  Future<void> _restaurar(Especialidad especialidad) async {
    try {
      await widget.repositorio.restaurar(especialidad.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(() =>
          _eliminadas = _eliminadas.where((e) => e.id != especialidad.id).toList());
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
      title: const Text('Especialidades eliminadas'),
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
                          'No hay ninguna especialidad eliminada.',
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
                            final especialidad = _eliminadas[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(especialidad.nombre),
                              trailing: TextButton.icon(
                                onPressed: () => _restaurar(especialidad),
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

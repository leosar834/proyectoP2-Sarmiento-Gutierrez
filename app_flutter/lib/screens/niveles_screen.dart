import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nivel.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/nivel_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Sección "Niveles" del panel de escritorio — CRUD completo contra
/// `/niveles` (ver `NivelesController` en el backend).
///
/// Catálogo permanente de la institución (no cuelga de ningún ciclo
/// lectivo): los "años" del establecimiento (1er año, 2do año...).
/// Junto con `DivisionesScreen`, es un prerrequisito de la pantalla de
/// Cursos (un curso = nivel + división + ciclo lectivo) — por eso se
/// construye antes.

class NivelesScreen extends StatefulWidget {
  const NivelesScreen({super.key});

  @override
  State<NivelesScreen> createState() => _NivelesScreenState();
}

class _NivelesScreenState extends State<NivelesScreen> {
  late final NivelRepository _repositorio;

  bool _cargando = true;
  ApiException? _errorCarga;
  List<Nivel> _niveles = const [];

  @override
  void initState() {
    super.initState();
    _repositorio = NivelRepository(context.read<AuthProvider>().apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final niveles = await _repositorio.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _niveles = niveles;
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

  Future<void> _abrirFormulario({Nivel? nivel}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioNivel(repositorio: _repositorio, nivel: nivel),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  /// Pedido explícito de la cátedra: la baja lógica tiene que poder
  /// revertirse desde acá, viendo todos los niveles eliminados y
  /// eligiendo cuál restaurar — no solo como sugerencia dentro de un
  /// error al chocar con un número de orden repetido (`_FormularioNivel`
  /// sigue ofreciendo ese atajo, pero ya no es la única vía).
  Future<void> _verEliminados() async {
    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoNivelesEliminados(repositorio: _repositorio),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(Nivel nivel) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar nivel'),
        content: Text(
          '¿Eliminar "${nivel.nombre}"? Se puede restaurar más adelante '
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
      await _repositorio.eliminar(nivel.id);
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
                        'Niveles',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Los años del establecimiento (1er año, 2do año...). '
                        'Se usan junto con las divisiones para armar los '
                        'cursos.',
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
              mensaje: 'Este es el primer paso: cargue aquí los años que '
                  'tiene la institución, sin preocuparte todavía por '
                  'cuántas divisiones tiene cada uno. Después vas a cargar '
                  'el catálogo de divisiones en "Divisiones", y recién en '
                  '"Cursos" vas a combinar cada año con las divisiones que '
                  'le correspondan para el ciclo lectivo actual.',
            ),
            const SizedBox(height: 24),
            if (_niveles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no hay ningún nivel cargado.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._niveles.map(
                (nivel) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaNivel(
                    nivel: nivel,
                    onEditar: () => _abrirFormulario(nivel: nivel),
                    onEliminar: () => _confirmarEliminar(nivel),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaNivel extends StatelessWidget {
  const _FilaNivel({
    required this.nivel,
    required this.onEditar,
    required this.onEliminar,
  });

  final Nivel nivel;
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
            child: Text(
              '${nivel.numeroOrden}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.azulPrimario,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              nivel.nombre,
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

/// Alta/edición de un nivel. Si `nivel` es `null`, es un alta; si no,
/// edita ese nivel.
class _FormularioNivel extends StatefulWidget {
  const _FormularioNivel({required this.repositorio, this.nivel});

  final NivelRepository repositorio;
  final Nivel? nivel;

  @override
  State<_FormularioNivel> createState() => _FormularioNivelState();
}

class _FormularioNivelState extends State<_FormularioNivel> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _ordenController;

  bool _guardando = false;
  ApiException? _error;

  // Backend siempre arma el mensaje como "...(id 123)..." — ver
  // `NivelesController::verificarOrdenDisponible()`. Extraerlo acá
  // habilita el botón "Restaurar" sin tener que listar dados de baja
  // (el índice no los devuelve, a propósito).
  static final _regexIdEnMensaje = RegExp(r'\(id (\d+)\)');

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.nivel?.nombre ?? '');
    _ordenController =
        TextEditingController(text: widget.nivel?.numeroOrden.toString() ?? '');
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _ordenController.dispose();
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
      final orden = int.parse(_ordenController.text.trim());

      if (widget.nivel == null) {
        await widget.repositorio.crear(nombre: nombre, numeroOrden: orden);
      } else {
        await widget.repositorio.actualizar(widget.nivel!.id, nombre: nombre, numeroOrden: orden);
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
      title: Text(widget.nivel == null ? 'Agregar nivel' : 'Editar nivel'),
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
                      label: const Text('Restaurar en vez de crear uno nuevo'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre (ej: 1er año)'),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ordenController,
                decoration: const InputDecoration(
                  labelText: 'Número de orden',
                  hintText: 'Ej: 1 si este nivel es 1er año, 2 si es 2do, 3 si es 3ro...',
                  helperText: 'La posición real de este año entre los demás '
                      '(no repetir entre niveles): el sistema lo usa para '
                      'promocionar automáticamente a los alumnos al año '
                      'siguiente cuando cierra el ciclo lectivo.',
                  helperMaxLines: 4,
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: (v) {
                  final numero = int.tryParse(v?.trim() ?? '');
                  if (numero == null || numero < 1) return 'Ingrese un número válido.';
                  return null;
                },
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

/// Lista de niveles dados de baja, con botón de restaurar por fila —
/// ver `_NivelesScreenState._verEliminados()`.
class _DialogoNivelesEliminados extends StatefulWidget {
  const _DialogoNivelesEliminados({required this.repositorio});

  final NivelRepository repositorio;

  @override
  State<_DialogoNivelesEliminados> createState() => _DialogoNivelesEliminadosState();
}

class _DialogoNivelesEliminadosState extends State<_DialogoNivelesEliminados> {
  bool _cargando = true;
  ApiException? _error;
  List<Nivel> _eliminados = const [];

  // Se devuelve al cerrar para que la pantalla de atrás sepa si tiene
  // que refrescar su lista de niveles activos.
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

  Future<void> _restaurar(Nivel nivel) async {
    try {
      await widget.repositorio.restaurar(nivel.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(() => _eliminados = _eliminados.where((n) => n.id != nivel.id).toList());
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
      title: const Text('Niveles eliminados'),
      content: SizedBox(
        width: 400,
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
                          'No hay ningún nivel eliminado.',
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
                            final nivel = _eliminados[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(nivel.nombre),
                              subtitle: Text('Orden: ${nivel.numeroOrden}'),
                              trailing: TextButton.icon(
                                onPressed: () => _restaurar(nivel),
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

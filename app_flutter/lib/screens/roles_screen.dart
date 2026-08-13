import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/permiso.dart';
import '../models/rol.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/permiso_repository.dart';
import '../services/rol_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Sección "Roles y permisos" del panel de escritorio — CRUD contra
/// `/roles` más la asignación de permisos de cada rol (ver
/// `RolesController` en el backend), y el catálogo fijo de `/permisos`
/// (`PermisosController`) que arma el checklist.
///
/// A diferencia de Niveles/Divisiones/Cursos, acá NO hay ningún
/// prerrequisito de otra pantalla — los 7 permisos del sistema son
/// fijos y ya están cargados desde que se instaló el sistema.

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late final RolRepository _repositorio;
  late final PermisoRepository _repositorioPermisos;

  bool _cargando = true;
  ApiException? _errorCarga;
  List<Rol> _roles = const [];
  List<Permiso> _catalogoPermisos = const [];

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthProvider>().apiClient;
    _repositorio = RolRepository(apiClient);
    _repositorioPermisos = PermisoRepository(apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final resultados = await Future.wait([
        _repositorio.obtenerTodos(),
        _repositorioPermisos.obtenerTodos(),
      ]);
      if (!mounted) return;
      setState(() {
        _roles = resultados[0] as List<Rol>;
        _catalogoPermisos = resultados[1] as List<Permiso>;
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

  Future<void> _abrirFormulario({Rol? rol}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioRol(
        repositorio: _repositorio,
        catalogoPermisos: _catalogoPermisos,
        rol: rol,
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  Future<void> _verEliminados() async {
    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRolesEliminados(repositorio: _repositorio),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(Rol rol) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar rol'),
        content: Text(
          rol.cantidadUsuarios > 0
              ? '¿Eliminar "${rol.nombre}"? Tiene ${rol.cantidadUsuarios} '
                  'usuario(s) asignados, que se quedarían sin este rol. Se '
                  'puede restaurar más adelante si hace falta.'
              : '¿Eliminar "${rol.nombre}"? Se puede restaurar más adelante '
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
      await _repositorio.eliminar(rol.id);
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
        constraints: const BoxConstraints(maxWidth: 720),
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
                        'Roles y permisos',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Los roles que puede tener un usuario (preceptor, '
                        'director...) y qué puede hacer cada uno.',
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
              mensaje: 'El nombre y la cantidad de roles los elige la '
                  'institución (por ejemplo "preceptor" o "director"). Lo '
                  'que ese rol puede hacer en el sistema surge únicamente '
                  'de los permisos que le tildes acá abajo — la lista de '
                  'permisos es fija, no se crea ni se edita.',
            ),
            const SizedBox(height: 24),
            if (_roles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no hay ningún rol cargado.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._roles.map(
                (rol) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaRol(
                    rol: rol,
                    onEditar: () => _abrirFormulario(rol: rol),
                    onEliminar: () => _confirmarEliminar(rol),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaRol extends StatelessWidget {
  const _FilaRol({
    required this.rol,
    required this.onEditar,
    required this.onEliminar,
  });

  final Rol rol;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
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
                    Row(
                      children: [
                        Text(
                          rol.nombre,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textoPrincipal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!rol.activo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.textoSecundario.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Inactivo',
                              style: TextStyle(fontSize: 10.5, color: AppColors.textoSecundario),
                            ),
                          ),
                      ],
                    ),
                    if (rol.descripcion != null && rol.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        rol.descripcion!,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      rol.cantidadUsuarios == 1
                          ? '1 usuario con este rol'
                          : '${rol.cantidadUsuarios} usuarios con este rol',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textoSecundario),
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
          const SizedBox(height: 10),
          if (rol.permisos.isEmpty)
            const Text(
              'Sin permisos asignados.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textoSecundario, fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: rol.permisos
                  .map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.azulPrimario.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          p.nombre,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.azulPrimario),
                        ),
                      ))
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

/// Alta/edición de un rol, con el checklist de permisos incluido en el
/// mismo formulario (en vez de una acción aparte) — así el
/// administrador ve de un vistazo qué hace el rol mientras lo nombra.
class _FormularioRol extends StatefulWidget {
  const _FormularioRol({
    required this.repositorio,
    required this.catalogoPermisos,
    this.rol,
  });

  final RolRepository repositorio;
  final List<Permiso> catalogoPermisos;
  final Rol? rol;

  @override
  State<_FormularioRol> createState() => _FormularioRolState();
}

class _FormularioRolState extends State<_FormularioRol> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late bool _activo;
  late Set<int> _permisoIdsSeleccionados;

  bool _guardando = false;
  ApiException? _error;

  static final _regexIdEnMensaje = RegExp(r'\(id (\d+)\)');

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.rol?.nombre ?? '');
    _descripcionController =
        TextEditingController(text: widget.rol?.descripcion ?? '');
    _activo = widget.rol?.activo ?? true;
    _permisoIdsSeleccionados =
        widget.rol?.permisos.map((p) => p.id).toSet() ?? <int>{};
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
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
      final descripcion = _descripcionController.text.trim();

      if (widget.rol == null) {
        final nuevo = await widget.repositorio.crear(
          nombre: nombre,
          descripcion: descripcion.isEmpty ? null : descripcion,
        );
        if (_permisoIdsSeleccionados.isNotEmpty) {
          await widget.repositorio.asignarPermisos(
            nuevo.id,
            _permisoIdsSeleccionados.toList(),
          );
        }
      } else {
        await widget.repositorio.actualizar(
          widget.rol!.id,
          nombre: nombre,
          descripcion: descripcion.isEmpty ? null : descripcion,
          activo: _activo,
        );
        await widget.repositorio.asignarPermisos(
          widget.rol!.id,
          _permisoIdsSeleccionados.toList(),
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
    final permisosEscritorio =
        widget.catalogoPermisos.where((p) => p.plataforma == 'escritorio').toList(growable: false);
    final permisosMovil =
        widget.catalogoPermisos.where((p) => p.plataforma == 'movil').toList(growable: false);

    return AlertDialog(
      title: Text(widget.rol == null ? 'Agregar rol' : 'Editar rol'),
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
                  decoration: const InputDecoration(labelText: 'Nombre (ej: preceptor)'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Qué hace este rol dentro de la institución',
                  ),
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                ),
                if (widget.rol != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Rol activo', style: TextStyle(fontSize: 13.5)),
                    value: _activo,
                    onChanged: (valor) => setState(() => _activo = valor),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Permisos',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tildá lo que este rol puede hacer en el sistema.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 6),
                if (permisosEscritorio.isNotEmpty)
                  _GrupoPermisos(
                    titulo: 'Escritorio',
                    permisos: permisosEscritorio,
                    seleccionados: _permisoIdsSeleccionados,
                    onCambiar: (permiso, marcado) => setState(() {
                      if (marcado) {
                        _permisoIdsSeleccionados.add(permiso.id);
                      } else {
                        _permisoIdsSeleccionados.remove(permiso.id);
                      }
                    }),
                  ),
                if (permisosMovil.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _GrupoPermisos(
                    titulo: 'Móvil',
                    permisos: permisosMovil,
                    seleccionados: _permisoIdsSeleccionados,
                    onCambiar: (permiso, marcado) => setState(() {
                      if (marcado) {
                        _permisoIdsSeleccionados.add(permiso.id);
                      } else {
                        _permisoIdsSeleccionados.remove(permiso.id);
                      }
                    }),
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

class _GrupoPermisos extends StatelessWidget {
  const _GrupoPermisos({
    required this.titulo,
    required this.permisos,
    required this.seleccionados,
    required this.onCambiar,
  });

  final String titulo;
  final List<Permiso> permisos;
  final Set<int> seleccionados;
  final void Function(Permiso permiso, bool marcado) onCambiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            titulo,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textoSecundario,
            ),
          ),
        ),
        ...permisos.map(
          (permiso) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: seleccionados.contains(permiso.id),
            onChanged: (marcado) => onCambiar(permiso, marcado ?? false),
            title: Text(permiso.nombre, style: const TextStyle(fontSize: 13)),
            subtitle: permiso.descripcion == null
                ? null
                : Text(
                    permiso.descripcion!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textoSecundario),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Lista de roles dados de baja, con botón de restaurar por fila — ver
/// `_RolesScreenState._verEliminados()`.
class _DialogoRolesEliminados extends StatefulWidget {
  const _DialogoRolesEliminados({required this.repositorio});

  final RolRepository repositorio;

  @override
  State<_DialogoRolesEliminados> createState() => _DialogoRolesEliminadosState();
}

class _DialogoRolesEliminadosState extends State<_DialogoRolesEliminados> {
  bool _cargando = true;
  ApiException? _error;
  List<Rol> _eliminados = const [];

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

  Future<void> _restaurar(Rol rol) async {
    try {
      await widget.repositorio.restaurar(rol.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(() => _eliminados = _eliminados.where((r) => r.id != rol.id).toList());
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
      title: const Text('Roles eliminados'),
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
                          'No hay ningún rol eliminado.',
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
                            final rol = _eliminados[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(rol.nombre),
                              subtitle: Text(
                                rol.descripcion?.isNotEmpty == true
                                    ? rol.descripcion!
                                    : '${rol.permisos.length} permiso(s)',
                              ),
                              trailing: TextButton.icon(
                                onPressed: () => _restaurar(rol),
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

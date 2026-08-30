import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rol.dart';
import '../models/usuario_gestion.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/rol_repository.dart';
import '../services/usuario_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Sección "Usuarios" del panel de escritorio — CRUD contra `/usuarios`
/// más la asignación de roles de cada usuario (ver `UsuariosController`
/// en el backend). No confundir con `Alumnos` (RF1, todavía por armar):
/// acá van quienes operan el sistema (preceptores, profesores,
/// administradores...), nunca alumnos.

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  late final UsuarioRepository _repositorio;
  late final RolRepository _repositorioRoles;

  bool _cargando = true;
  ApiException? _errorCarga;
  List<UsuarioGestion> _usuarios = const [];
  List<Rol> _catalogoRoles = const [];

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthProvider>().apiClient;
    _repositorio = UsuarioRepository(apiClient);
    _repositorioRoles = RolRepository(apiClient);
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
        _repositorioRoles.obtenerTodos(),
      ]);
      if (!mounted) return;
      setState(() {
        _usuarios = resultados[0] as List<UsuarioGestion>;
        _catalogoRoles = resultados[1] as List<Rol>;
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

  Future<void> _abrirFormulario({UsuarioGestion? usuario}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioUsuario(
        repositorio: _repositorio,
        catalogoRoles: _catalogoRoles,
        usuario: usuario,
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  Future<void> _verEliminados() async {
    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoUsuariosEliminados(repositorio: _repositorio),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(UsuarioGestion usuario) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
          '¿Eliminar a "${usuario.nombreCompleto}"? Se puede restaurar '
          'más adelante si hace falta.',
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
      await _repositorio.eliminar(usuario.id);
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

    final miIdUsuario = context.watch<AuthProvider>().usuario?.idUsuario;

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
                        'Usuarios',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Quienes operan el sistema (preceptores, profesores, '
                        'administradores...) — nunca alumnos.',
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
                  onPressed: _catalogoRoles.isEmpty ? null : () => _abrirFormulario(),
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
            if (_catalogoRoles.isEmpty)
              const BannerInfo(
                mensaje: 'Todavía no hay ningún rol cargado en "Roles y '
                    'permisos" — cargá al menos uno ahí antes de crear '
                    'usuarios, para poder asignarle un rol a cada uno.',
              )
            else
              const BannerInfo(
                mensaje: 'Cada usuario puede tener uno o más roles de los ya '
                    'cargados en "Roles y permisos". Lo que puede hacer en '
                    'el sistema surge de esos roles, no se configura acá.',
              ),
            const SizedBox(height: 24),
            if (_usuarios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no hay ningún usuario cargado.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._usuarios.map(
                (usuario) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaUsuario(
                    usuario: usuario,
                    esUnoMismo: usuario.id == miIdUsuario,
                    onEditar: () => _abrirFormulario(usuario: usuario),
                    onEliminar: () => _confirmarEliminar(usuario),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilaUsuario extends StatelessWidget {
  const _FilaUsuario({
    required this.usuario,
    required this.esUnoMismo,
    required this.onEditar,
    required this.onEliminar,
  });

  final UsuarioGestion usuario;
  final bool esUnoMismo;
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.azulPrimario.withValues(alpha: 0.1),
            child: Text(
              usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.azulPrimario,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      usuario.nombreCompleto,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textoPrincipal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (esUnoMismo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.azulPrimario.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Vos',
                          style: TextStyle(fontSize: 10.5, color: AppColors.azulPrimario),
                        ),
                      ),
                    if (!usuario.activo) ...[
                      const SizedBox(width: 6),
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
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  usuario.email,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 8),
                if (usuario.roles.isEmpty)
                  const Text(
                    'Sin roles asignados.',
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
                    children: usuario.roles
                        .map((r) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.azulPrimario.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r.nombre,
                                style: const TextStyle(fontSize: 10.5, color: AppColors.azulPrimario),
                              ),
                            ))
                        .toList(growable: false),
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
            icon: Icon(
              Icons.delete_outline,
              size: 19,
              color: esUnoMismo ? AppColors.textoSecundario.withValues(alpha: 0.4) : AppColors.error,
            ),
            tooltip: esUnoMismo
                ? 'No podés eliminar tu propio usuario mientras estás logueado con él'
                : 'Eliminar',
            onPressed: esUnoMismo ? null : onEliminar,
          ),
        ],
      ),
    );
  }
}

/// Alta/edición de un usuario, con el checklist de roles incluido en el
/// mismo formulario — mismo criterio que `_FormularioRol` en
/// `roles_screen.dart`.
class _FormularioUsuario extends StatefulWidget {
  const _FormularioUsuario({
    required this.repositorio,
    required this.catalogoRoles,
    this.usuario,
  });

  final UsuarioRepository repositorio;
  final List<Rol> catalogoRoles;
  final UsuarioGestion? usuario;

  @override
  State<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends State<_FormularioUsuario> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  late final TextEditingController _apellidoController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late bool _activo;
  late Set<int> _rolIdsSeleccionados;

  bool _guardando = false;
  ApiException? _error;

  static final _regexIdEnMensaje = RegExp(r'\(id (\d+)\)');

  bool get _esAlta => widget.usuario == null;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.usuario?.nombre ?? '');
    _apellidoController = TextEditingController(text: widget.usuario?.apellido ?? '');
    _emailController = TextEditingController(text: widget.usuario?.email ?? '');
    _passwordController = TextEditingController();
    _activo = widget.usuario?.activo ?? true;
    _rolIdsSeleccionados =
        widget.usuario?.roles.map((r) => r.id).toSet() ?? <int>{};
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      final apellido = _apellidoController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_esAlta) {
        await widget.repositorio.crear(
          nombre: nombre,
          apellido: apellido,
          email: email,
          password: password,
          activo: _activo,
          rolIds: _rolIdsSeleccionados.toList(),
        );
      } else {
        await widget.repositorio.actualizar(
          widget.usuario!.id,
          nombre: nombre,
          apellido: apellido,
          email: email,
          password: password.isEmpty ? null : password,
          activo: _activo,
        );
        await widget.repositorio.asignarRoles(
          widget.usuario!.id,
          _rolIdsSeleccionados.toList(),
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

    return AlertDialog(
      title: Text(_esAlta ? 'Agregar usuario' : 'Editar usuario'),
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
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final valor = v?.trim() ?? '';
                    if (valor.isEmpty) return 'Ingrese el email.';
                    if (!valor.contains('@')) return 'Ingrese un email válido.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: _esAlta ? 'Contraseña' : 'Nueva contraseña (opcional)',
                    helperText: _esAlta
                        ? 'Mínimo 8 caracteres.'
                        : 'Dejar en blanco para no cambiarla.',
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    final valor = v ?? '';
                    if (_esAlta && valor.isEmpty) return 'Ingrese una contraseña.';
                    if (valor.isNotEmpty && valor.length < 8) {
                      return 'Mínimo 8 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Usuario activo', style: TextStyle(fontSize: 13.5)),
                  subtitle: const Text(
                    'Si está inactivo, no puede iniciar sesión (pero sigue en la lista).',
                    style: TextStyle(fontSize: 11),
                  ),
                  value: _activo,
                  onChanged: (valor) => setState(() => _activo = valor),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Roles',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tildá los roles que va a tener este usuario.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textoSecundario),
                ),
                const SizedBox(height: 4),
                if (widget.catalogoRoles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No hay roles cargados todavía.',
                      style: TextStyle(fontSize: 12, color: AppColors.textoSecundario),
                    ),
                  )
                else
                  ...widget.catalogoRoles.map(
                    (rol) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _rolIdsSeleccionados.contains(rol.id),
                      onChanged: (marcado) => setState(() {
                        if (marcado ?? false) {
                          _rolIdsSeleccionados.add(rol.id);
                        } else {
                          _rolIdsSeleccionados.remove(rol.id);
                        }
                      }),
                      title: Text(rol.nombre, style: const TextStyle(fontSize: 13)),
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

/// Lista de usuarios dados de baja, con botón de restaurar por fila —
/// ver `_UsuariosScreenState._verEliminados()`.
class _DialogoUsuariosEliminados extends StatefulWidget {
  const _DialogoUsuariosEliminados({required this.repositorio});

  final UsuarioRepository repositorio;

  @override
  State<_DialogoUsuariosEliminados> createState() => _DialogoUsuariosEliminadosState();
}

class _DialogoUsuariosEliminadosState extends State<_DialogoUsuariosEliminados> {
  bool _cargando = true;
  ApiException? _error;
  List<UsuarioGestion> _eliminados = const [];

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

  Future<void> _restaurar(UsuarioGestion usuario) async {
    try {
      await widget.repositorio.restaurar(usuario.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(() => _eliminados = _eliminados.where((u) => u.id != usuario.id).toList());
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
      title: const Text('Usuarios eliminados'),
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
                          'No hay ningún usuario eliminado.',
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
                            final usuario = _eliminados[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(usuario.nombreCompleto),
                              subtitle: Text(usuario.email),
                              trailing: TextButton.icon(
                                onPressed: () => _restaurar(usuario),
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

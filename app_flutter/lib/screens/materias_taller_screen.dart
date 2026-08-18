import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/especialidad.dart';
import '../models/materia_taller.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/especialidad_repository.dart';
import '../services/materia_taller_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

const _regimenes = ['anual', 'trimestral', 'semestral', 'personalizado'];

/// Sección "Materias de Taller" del panel de escritorio — CRUD contra
/// `/materias-taller` (ver `MateriasTallerController` en el backend).
///
/// Catálogo permanente (ej. "Dibujo Técnico" dentro de
/// "Electromecánica"), no depende de ningún ciclo lectivo. Requiere al
/// menos una especialidad ya cargada. Los grupos de taller (pantalla
/// aparte) se arman después, sobre estas materias.
///
/// Tiene "Ver eliminados", pero sin el atajo "(id X)" que sí tiene
/// Especialidades: acá el nombre no tiene restricción de unicidad (dos
/// especialidades distintas pueden compartir el nombre de una materia,
/// ver el docblock de `MateriaTallerRepository`), así que nunca se
/// produce ese error — "Ver eliminados" es la ÚNICA forma de restaurar
/// una materia borrada.
class MateriasTallerScreen extends StatefulWidget {
  const MateriasTallerScreen({super.key});

  @override
  State<MateriasTallerScreen> createState() => _MateriasTallerScreenState();
}

class _MateriasTallerScreenState extends State<MateriasTallerScreen> {
  late final MateriaTallerRepository _repositorioMaterias;
  late final EspecialidadRepository _repositorioEspecialidades;

  bool _cargando = true;
  ApiException? _errorCarga;
  List<MateriaTaller> _materias = const [];
  List<Especialidad> _especialidades = const [];
  int? _filtroEspecialidadId;

  @override
  void initState() {
    super.initState();
    final apiClient = context.read<AuthProvider>().apiClient;
    _repositorioMaterias = MateriaTallerRepository(apiClient);
    _repositorioEspecialidades = EspecialidadRepository(apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final especialidades = await _repositorioEspecialidades.obtenerTodos();
      final materias = await _repositorioMaterias.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _especialidades = especialidades;
        _materias = materias;
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

  List<MateriaTaller> get _materiasFiltradas => _filtroEspecialidadId == null
      ? _materias
      : _materias.where((m) => m.especialidadId == _filtroEspecialidadId).toList();

  Future<void> _abrirFormulario({MateriaTaller? materia}) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioMateriaTaller(
        repositorio: _repositorioMaterias,
        especialidades: _especialidades,
        materia: materia,
      ),
    );
    if (resultado == true) {
      _cargar();
    }
  }

  /// Ver el razonamiento en `EspecialidadesScreen._verEliminados()` —
  /// acá es más importante todavía, porque es la ÚNICA vía de
  /// restauración (no hay atajo "(id X)" para materias de taller).
  Future<void> _verEliminados() async {
    final huboRestauracion = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoMateriasEliminadas(
        repositorio: _repositorioMaterias,
        especialidades: _especialidades,
      ),
    );
    if (huboRestauracion == true) {
      _cargar();
    }
  }

  Future<void> _confirmarEliminar(MateriaTaller materia) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar materia/taller'),
        content: Text(
          '¿Eliminar "${materia.nombre}"? Si ya tiene grupos de taller '
          'armados, el sistema no va a dejar eliminarla.',
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
      await _repositorioMaterias.eliminar(materia.id);
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
                        'Materias de Taller',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Las materias de cada especialidad (ej. "Dibujo '
                        'Técnico" en Electromecánica), con su régimen de '
                        'cursada.',
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
              mensaje: 'Cada materia cuelga de una especialidad del '
                  'catálogo. Los grupos de taller (por ciclo lectivo) se '
                  'arman en su propia sección, sobre estas materias.',
            ),
            const SizedBox(height: 24),
            _FiltroEspecialidad(
              especialidades: _especialidades,
              valor: _filtroEspecialidadId,
              onCambiar: (valor) => setState(() => _filtroEspecialidadId = valor),
            ),
            const SizedBox(height: 16),
            if (_materiasFiltradas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No hay ninguna materia de taller cargada todavía.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ..._materiasFiltradas.map(
                (materia) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _FilaMateria(
                    materia: materia,
                    onEditar: () => _abrirFormulario(materia: materia),
                    onEliminar: () => _confirmarEliminar(materia),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FiltroEspecialidad extends StatelessWidget {
  const _FiltroEspecialidad({
    required this.especialidades,
    required this.valor,
    required this.onCambiar,
  });

  final List<Especialidad> especialidades;
  final int? valor;
  final ValueChanged<int?> onCambiar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<int?>(
        initialValue: valor,
        decoration: const InputDecoration(labelText: 'Filtrar por especialidad'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
          ...especialidades.map(
            (e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.nombre)),
          ),
        ],
        onChanged: onCambiar,
      ),
    );
  }
}

class _FilaMateria extends StatelessWidget {
  const _FilaMateria({
    required this.materia,
    required this.onEditar,
    required this.onEliminar,
  });

  final MateriaTaller materia;
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
            child: const Icon(Icons.construction_outlined, size: 17, color: AppColors.azulPrimario),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  materia.nombre,
                  style: const TextStyle(fontSize: 14, color: AppColors.textoPrincipal),
                ),
                const SizedBox(height: 2),
                Text(
                  '${materia.especialidadNombre ?? "Sin especialidad"} · Régimen ${materia.regimenCursada}',
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
    );
  }
}

/// Alta/edición de una materia de taller. Si `materia` es `null`, es un
/// alta; si no, edita esa materia.
class _FormularioMateriaTaller extends StatefulWidget {
  const _FormularioMateriaTaller({
    required this.repositorio,
    required this.especialidades,
    this.materia,
  });

  final MateriaTallerRepository repositorio;
  final List<Especialidad> especialidades;
  final MateriaTaller? materia;

  @override
  State<_FormularioMateriaTaller> createState() => _FormularioMateriaTallerState();
}

class _FormularioMateriaTallerState extends State<_FormularioMateriaTaller> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  int? _especialidadId;
  String? _regimenCursada;

  bool _guardando = false;
  bool _intentoDeGuardado = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.materia?.nombre ?? '');
    _especialidadId = widget.materia?.especialidadId;
    _regimenCursada = widget.materia?.regimenCursada;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _intentoDeGuardado = true);

    if (!_formKey.currentState!.validate() || _regimenCursada == null) {
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final nombre = _nombreController.text.trim();

      if (widget.materia == null) {
        await widget.repositorio.crear(
          especialidadId: _especialidadId,
          nombre: nombre,
          regimenCursada: _regimenCursada!,
        );
      } else {
        await widget.repositorio.actualizar(
          widget.materia!.id,
          especialidadId: _especialidadId,
          nombre: nombre,
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
      title: Text(widget.materia == null ? 'Agregar materia de taller' : 'Editar materia de taller'),
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
              const Text('Especialidad', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text(
                'Dejá "Sin especialidad" para materias de ciclo básico '
                '(1° y 2° año), donde los alumnos todavía no tienen una '
                'orientación asignada.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textoSecundario, height: 1.3),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<int?>(
                initialValue: _especialidadId,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin especialidad (ciclo básico)'),
                  ),
                  ...widget.especialidades.map(
                    (e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.nombre)),
                  ),
                ],
                onChanged: (valor) => setState(() => _especialidadId = valor),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre (ej: Dibujo Técnico)'),
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre.' : null,
              ),
              const SizedBox(height: 14),
              const Text('Régimen de cursada', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: _regimenCursada,
                decoration: InputDecoration(
                  errorText: _intentoDeGuardado && _regimenCursada == null
                      ? 'Elija un régimen.'
                      : null,
                ),
                items: _regimenes
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(growable: false),
                onChanged: (valor) => setState(() => _regimenCursada = valor),
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

/// Lista de materias de taller dadas de baja, con botón de restaurar
/// por fila — ver `_MateriasTallerScreenState._verEliminados()`. Con
/// el mismo filtro por especialidad que la lista activa, porque puede
/// haber muchas materias eliminadas acumuladas.
class _DialogoMateriasEliminadas extends StatefulWidget {
  const _DialogoMateriasEliminadas({
    required this.repositorio,
    required this.especialidades,
  });

  final MateriaTallerRepository repositorio;
  final List<Especialidad> especialidades;

  @override
  State<_DialogoMateriasEliminadas> createState() => _DialogoMateriasEliminadasState();
}

class _DialogoMateriasEliminadasState extends State<_DialogoMateriasEliminadas> {
  bool _cargando = true;
  ApiException? _error;
  List<MateriaTaller> _eliminadas = const [];
  int? _filtroEspecialidadId;
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
      final eliminadas =
          await widget.repositorio.obtenerEliminados(especialidadId: _filtroEspecialidadId);
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

  Future<void> _restaurar(MateriaTaller materia) async {
    try {
      await widget.repositorio.restaurar(materia.id);
      _huboRestauracion = true;
      if (!mounted) return;
      setState(() => _eliminadas = _eliminadas.where((m) => m.id != materia.id).toList());
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
      title: const Text('Materias de taller eliminadas'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.especialidades.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                initialValue: _filtroEspecialidadId,
                decoration: const InputDecoration(labelText: 'Filtrar por especialidad'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                  ...widget.especialidades.map(
                    (e) => DropdownMenuItem<int?>(value: e.id, child: Text(e.nombre)),
                  ),
                ],
                onChanged: (valor) {
                  setState(() => _filtroEspecialidadId = valor);
                  _cargar();
                },
              ),
              const SizedBox(height: 12),
            ],
            if (_cargando)
              const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              BannerError(mensaje: _error!.mensaje)
            else if (_eliminadas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No hay ninguna materia de taller eliminada.',
                  style: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _eliminadas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final materia = _eliminadas[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(materia.nombre),
                      subtitle: Text(
                        '${materia.especialidadNombre ?? "Sin especialidad"} · Régimen ${materia.regimenCursada}',
                      ),
                      trailing: TextButton.icon(
                        onPressed: () => _restaurar(materia),
                        icon: const Icon(Icons.restore_outlined, size: 18),
                        label: const Text('Restaurar'),
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
          onPressed: () => Navigator.of(context).pop(_huboRestauracion),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

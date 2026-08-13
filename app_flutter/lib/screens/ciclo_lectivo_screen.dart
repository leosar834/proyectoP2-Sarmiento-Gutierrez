import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ciclo_lectivo.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/ciclo_lectivo_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';

/// Sección "Ciclo lectivo" del panel de escritorio — `GET`/`POST
/// /ciclos-lectivos` (ver `CiclosLectivosController` en el backend).
///
/// Alcance de ESTA pantalla, a propósito acotado: solo cubre dar de
/// alta el PRIMER ciclo lectivo de una instalación nueva (si todavía no
/// existe ninguno) y mostrar el estado del ciclo actual una vez que ya
/// existe. El proceso de cerrar un ciclo y abrir el siguiente (clonar
/// cursos, definir desenlaces, generar inscripciones — Fases 1 a 4,
/// backend ya listo en `CierreCicloController`/`AperturaCicloController`
/// y compañía) es una pantalla propia, más grande, que se construye
/// aparte.

class CicloLectivoScreen extends StatefulWidget {
  const CicloLectivoScreen({super.key});

  @override
  State<CicloLectivoScreen> createState() => _CicloLectivoScreenState();
}

class _CicloLectivoScreenState extends State<CicloLectivoScreen> {
  late final CicloLectivoRepository _repositorio;

  bool _cargando = true;
  ApiException? _errorCarga;
  List<CicloLectivo> _ciclos = const [];

  @override
  void initState() {
    super.initState();
    _repositorio =
        CicloLectivoRepository(context.read<AuthProvider>().apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final ciclos = await _repositorio.obtenerTodos();
      if (!mounted) return;
      setState(() {
        _ciclos = ciclos;
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

    if (_ciclos.isEmpty) {
      return _CrearPrimerCicloForm(
        repositorio: _repositorio,
        onCreado: (ciclo) => setState(() => _ciclos = [ciclo]),
      );
    }

    return _EstadoCiclos(ciclos: _ciclos);
  }
}

/// Formulario de alta del primer ciclo lectivo — solo se muestra cuando
/// todavía no existe ninguno.
class _CrearPrimerCicloForm extends StatefulWidget {
  const _CrearPrimerCicloForm({
    required this.repositorio,
    required this.onCreado,
  });

  final CicloLectivoRepository repositorio;
  final ValueChanged<CicloLectivo> onCreado;

  @override
  State<_CrearPrimerCicloForm> createState() => _CrearPrimerCicloFormState();
}

class _CrearPrimerCicloFormState extends State<_CrearPrimerCicloForm> {
  final _formKey = GlobalKey<FormState>();
  final _anioController = TextEditingController();

  DateTime? _fechaInicio;
  bool _guardando = false;
  ApiException? _errorGuardado;

  @override
  void dispose() {
    _anioController.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final ahora = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaInicio ?? ahora,
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 1),
      // Corto a propósito: el header de `showDatePicker` tiene un ancho
      // fijo que Flutter no expone para agrandar (no es un tamaño de
      // diálogo configurable), así que un texto más largo se trunca con
      // "..." en vez de mostrarse completo — ver la conversación del
      // 12/08/2026. El campo de arriba ("Fecha de inicio *") ya da el
      // contexto, así que no hace falta repetir "del ciclo lectivo" acá.
      helpText: 'Fecha de inicio',
    );
    if (fecha == null) return;
    setState(() => _fechaInicio = fecha);
  }

  Future<void> _guardar() async {
    // Mismo patrón que en LoginScreen/AdminRegistroScreen/InstitucionScreen:
    // limpiar el error de un intento anterior ANTES de validar de nuevo,
    // y esperar el frame que dispara ese `setState` antes de llamar a
    // `validate()` — ver el docblock de `_submit()` en `login_screen.dart`.
    if (_errorGuardado != null) {
      setState(() => _errorGuardado = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    _intentoDeGuardado = true;
    final formValido = _formKey.currentState!.validate();
    final fechaValida = _fechaInicio != null;
    if (!formValido || !fechaValida) {
      setState(() {}); // Repinta para mostrar el error de fecha si falta.
      return;
    }

    setState(() => _guardando = true);

    try {
      final ciclo = await widget.repositorio.crear(
        anio: int.parse(_anioController.text.trim()),
        fechaInicio: _fechaInicio!.toIso8601String().split('T').first,
      );

      widget.onCreado(ciclo);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = error;
      });
    }
  }

  String? _validarAnio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingrese el año.';
    }
    final numero = int.tryParse(valor.trim());
    if (numero == null || numero < 2000 || numero > 2100) {
      return 'Ingrese un año válido.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crear el primer ciclo lectivo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'El sistema todavía no tiene ningún ciclo lectivo cargado. '
                'Este es el punto de partida: a partir de acá, cerrar el '
                'ciclo y abrir el siguiente se hace desde un proceso '
                'aparte, no volviendo a esta pantalla.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textoSecundario,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (_errorGuardado != null) ...[
                BannerError(mensaje: _errorGuardado!.mensaje),
                const SizedBox(height: 16),
              ],
              Text(
                'Año *',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _anioController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (v) => _validarAnio(v) ?? _errorGuardado?.errorDeCampo('anio'),
                style: const TextStyle(fontSize: 14, color: AppColors.textoPrincipal),
                decoration: InputDecoration(
                  hintText: 'Ej: ${DateTime.now().year}',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textoSecundario),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borde),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.borde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.azulPrimario, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.error, width: 1.5),
                  ),
                  errorStyle: const TextStyle(fontSize: 11.5, color: AppColors.error),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Fecha de inicio *',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _elegirFecha,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                    errorText: (!_formularioFueEnviado || _fechaInicio != null)
                        ? null
                        : 'Elija la fecha de inicio.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.borde),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.borde),
                    ),
                  ),
                  child: Text(
                    _fechaInicio == null
                        ? 'Elegir fecha'
                        : _formatearFecha(_fechaInicio!),
                    style: TextStyle(
                      fontSize: 14,
                      color: _fechaInicio == null
                          ? AppColors.textoSecundario
                          : AppColors.textoPrincipal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulPrimario,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.azulPrimario.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add, size: 20),
                  label: const Text(
                    'Crear ciclo lectivo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Solo para no mostrar "Elija la fecha de inicio." antes de que el
  // usuario intente guardar por primera vez (mismo criterio que
  // `AutovalidateMode.onUserInteraction` usa para los demás campos).
  bool get _formularioFueEnviado => _intentoDeGuardado;
  bool _intentoDeGuardado = false;

  String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}

/// Muestra el ciclo lectivo actual (el que está en estado `abierto`, o
/// el más reciente si por algún motivo no hubiera ninguno abierto) y,
/// si existiera más de uno, un historial simple debajo.
class _EstadoCiclos extends StatelessWidget {
  const _EstadoCiclos({required this.ciclos});

  final List<CicloLectivo> ciclos;

  @override
  Widget build(BuildContext context) {
    final actual = ciclos.firstWhere(
      (c) => c.abierto,
      orElse: () => ciclos.first,
    );
    final anteriores = ciclos.where((c) => c.id != actual.id).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ciclo lectivo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textoPrincipal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'El ciclo lectivo actual del sistema. Cerrarlo y abrir el '
              'siguiente es un proceso propio que todavía no tiene '
              'pantalla — se construye como próximo paso.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textoSecundario,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            _TarjetaCiclo(ciclo: actual, destacado: true),
            if (anteriores.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Ciclos anteriores',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 10),
              ...anteriores.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TarjetaCiclo(ciclo: c, destacado: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaCiclo extends StatelessWidget {
  const _TarjetaCiclo({required this.ciclo, required this.destacado});

  final CicloLectivo ciclo;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: destacado ? AppColors.azulPrimario.withValues(alpha: 0.4) : AppColors.borde,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_repeat_outlined,
            size: 22,
            color: destacado ? AppColors.azulPrimario : AppColors.textoSecundario,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ciclo lectivo ${ciclo.anio}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ciclo.fechaInicio == null
                      ? 'Sin fecha de inicio registrada.'
                      : 'Inicio: ${ciclo.fechaInicio}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (ciclo.abierto ? AppColors.azulPrimario : AppColors.textoSecundario)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ciclo.abierto ? 'Abierto' : 'Cerrado',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ciclo.abierto ? AppColors.azulPrimario : AppColors.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

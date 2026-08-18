import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/institucion.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/institucion_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/campo_texto.dart';

/// Edición de la ficha de la institución — `GET`/`PUT /institucion`
/// (ver `InstitucionController` en el backend). Estos datos ya se
/// cargan obligatoriamente en el registro del primer administrador
/// (`AdminRegistroScreen`); esta pantalla es la forma prometida ahí de
/// poder corregirlos después, en cualquier momento, sin volver a tocar
/// la base a mano.
///
/// Se embebe como contenido dentro de `PanelEscritorioScreen` — no arma
/// su propio `Scaffold`, para no duplicar el menú lateral.
class InstitucionScreen extends StatefulWidget {
  const InstitucionScreen({super.key, this.onActualizada});

  /// Avisa al panel que la contiene que los datos cambiaron, para que
  /// la sección "Inicio" (que muestra una copia de solo lectura) no
  /// quede desactualizada sin tener que volver a entrar a la app.
  final ValueChanged<Institucion>? onActualizada;

  @override
  State<InstitucionScreen> createState() => _InstitucionScreenState();
}

class _InstitucionScreenState extends State<InstitucionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _domicilioController = TextEditingController();
  final _cueController = TextEditingController();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();

  // Sin controller de texto porque no es un campo libre — arranca en
  // null solo hasta que `_cargar()` trae el valor real; nunca se manda
  // así al backend (`ActualizarInstitucionRequest` lo exige siempre).
  String? _modalidad;

  late final InstitucionRepository _repositorio;

  bool _cargando = true;
  bool _guardando = false;
  ApiException? _errorCarga;
  ApiException? _errorGuardado;

  @override
  void initState() {
    super.initState();
    _repositorio =
        InstitucionRepository(context.read<AuthProvider>().apiClient);
    _cargar();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _domicilioController.dispose();
    _cueController.dispose();
    _localidadController.dispose();
    _provinciaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final institucion = await _repositorio.obtener();
      _nombreController.text = institucion.nombre;
      _domicilioController.text = institucion.domicilio;
      _cueController.text = institucion.cue;
      _localidadController.text = institucion.localidad;
      _provinciaController.text = institucion.provincia;
      if (!mounted) return;
      setState(() {
        _modalidad = institucion.modalidad;
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

  Future<void> _guardar() async {
    // Mismo bug (y misma corrección) que en LoginScreen/AdminRegistroScreen:
    // limpiar `_errorGuardado` DESPUÉS de este primer `validate()` deja
    // la pantalla trabada en el error del intento anterior si se
    // corrige el dato y se reenvía — ver el docblock de `_submit()` en
    // `login_screen.dart` para el detalle completo.
    if (_errorGuardado != null) {
      setState(() => _errorGuardado = null);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _guardando = true);

    try {
      final institucion = await _repositorio.actualizar(
        nombre: _nombreController.text.trim(),
        domicilio: _domicilioController.text.trim(),
        cue: _cueController.text.trim(),
        localidad: _localidadController.text.trim(),
        provincia: _provinciaController.text.trim(),
        // Siempre no-null acá: el formulario recién se muestra después
        // de que `_cargar()` lo haya poblado (ver el gate `_cargando`
        // en build()).
        modalidad: _modalidad!,
      );

      widget.onActualizada?.call(institucion);

      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Datos de la institución actualizados.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = error;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
    }
  }

  String? _validarRequerido(String? valor, String etiqueta) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingrese $etiqueta.';
    }
    return null;
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Datos de la institución',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Identifican al establecimiento que administrás. Se '
                'muestran en el panel y, más adelante, en reportes y '
                'planillas impresas.',
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
              CampoTexto(
                etiqueta: 'Nombre de la institución *',
                controller: _nombreController,
                hint: 'Ej: EETN.° 1 Cnel. Manuel Álvarez Prado',
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    _validarRequerido(v, 'el nombre de la institución'),
                errorServidor: _errorGuardado?.errorDeCampo('nombre'),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Domicilio *',
                controller: _domicilioController,
                hint: 'Ej: Av. Siempre Viva 123',
                textInputAction: TextInputAction.next,
                validator: (v) => _validarRequerido(v, 'el domicilio'),
                errorServidor: _errorGuardado?.errorDeCampo('domicilio'),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'CUE *',
                controller: _cueController,
                hint: 'Clave Única de Establecimiento',
                textInputAction: TextInputAction.next,
                validator: (v) => _validarRequerido(v, 'el CUE'),
                errorServidor: _errorGuardado?.errorDeCampo('cue'),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Localidad *',
                controller: _localidadController,
                hint: 'Ej: San Salvador de Jujuy',
                textInputAction: TextInputAction.next,
                validator: (v) => _validarRequerido(v, 'la localidad'),
                errorServidor: _errorGuardado?.errorDeCampo('localidad'),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Provincia *',
                controller: _provinciaController,
                hint: 'Ej: Jujuy',
                textInputAction: TextInputAction.done,
                validator: (v) => _validarRequerido(v, 'la provincia'),
                errorServidor: _errorGuardado?.errorDeCampo('provincia'),
                onFieldSubmitted: (_) => _guardar(),
              ),
              const SizedBox(height: 24),
              const Text(
                'Modalidad',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textoPrincipal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Define qué secciones te conviene ver en el menú — se '
                'puede cambiar en cualquier momento, no borra datos ya '
                'cargados.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textoSecundario,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              _OpcionModalidad(
                valor: 'tecnico_profesional_contraturno',
                grupoValor: _modalidad,
                titulo: 'Técnico-profesional con contraturnos',
                descripcion: 'Tiene talleres — muestra "Materias de '
                    'Taller" y "Grupos de Taller" en el menú.',
                onSeleccionar: (v) => setState(() => _modalidad = v),
              ),
              const SizedBox(height: 8),
              _OpcionModalidad(
                valor: 'secundaria_comun_orientaciones',
                grupoValor: _modalidad,
                titulo: 'Secundaria común con orientaciones',
                descripcion: 'Sin talleres — oculta esas dos secciones '
                    'del menú. Las orientaciones se siguen cargando en '
                    '"Especialidades".',
                onSeleccionar: (v) => setState(() => _modalidad = v),
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
                      : const Icon(Icons.save_outlined, size: 20),
                  label: const Text(
                    'Guardar cambios',
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
}

/// Una tarjeta seleccionable de "Modalidad" — mismo look que el resto
/// de las tarjetas de la app (`AppColors.tarjeta`/`borde`), en vez del
/// `RadioListTile` de Material por defecto, para no romper el estilo
/// visual del formulario.
class _OpcionModalidad extends StatelessWidget {
  const _OpcionModalidad({
    required this.valor,
    required this.grupoValor,
    required this.titulo,
    required this.descripcion,
    required this.onSeleccionar,
  });

  final String valor;
  final String? grupoValor;
  final String titulo;
  final String descripcion;
  final ValueChanged<String> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final seleccionada = valor == grupoValor;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onSeleccionar(valor),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionada
              ? AppColors.azulPrimario.withValues(alpha: 0.06)
              : AppColors.tarjeta,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionada ? AppColors.azulPrimario : AppColors.borde,
            width: seleccionada ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              seleccionada ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: seleccionada ? AppColors.azulPrimario : AppColors.textoSecundario,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: seleccionada ? AppColors.azulPrimario : AppColors.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textoSecundario,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

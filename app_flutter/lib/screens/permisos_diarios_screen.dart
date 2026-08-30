import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/permiso_diario.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/permiso_diario_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/banner_info.dart';

/// Sección "Permisos diarios" del panel de escritorio — RF2, "el jefe de
/// preceptores abre manualmente a diario el permiso para tomar
/// asistencia" (ver `PermisosDiariosController` en el backend). Sin esto
/// abierto, el propio trigger `trg_planillas_before_insert` de MySQL
/// rechaza cualquier planilla nueva de HOY — por eso esta pantalla es
/// prerequisito de "tomar asistencia" (RF2 del lado móvil, todavía sin
/// construir).
///
/// El cierre normal NO es una acción de esta pantalla: pasada
/// `horaLimite` el permiso queda cerrado solo. Lo único que se gestiona
/// acá es la apertura y, si hiciera falta, un cierre anticipado
/// explícito (`cerrado_manual`).
class PermisosDiariosScreen extends StatefulWidget {
  const PermisosDiariosScreen({super.key});

  @override
  State<PermisosDiariosScreen> createState() => _PermisosDiariosScreenState();
}

class _PermisosDiariosScreenState extends State<PermisosDiariosScreen> {
  late final PermisoDiarioRepository _repositorio;

  bool _cargando = true;
  ApiException? _errorCarga;
  EstadoPermisoDiario? _estado;

  bool _procesando = false;
  ApiException? _errorAccion;

  @override
  void initState() {
    super.initState();
    _repositorio =
        PermisoDiarioRepository(context.read<AuthProvider>().apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final estado = await _repositorio.obtenerHoy();
      if (!mounted) return;
      setState(() {
        _estado = estado;
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

  Future<void> _abrir({String? horaLimite}) async {
    setState(() {
      _procesando = true;
      _errorAccion = null;
    });

    try {
      final permiso = await _repositorio.abrir(horaLimite: horaLimite);
      if (!mounted) return;
      setState(() {
        _estado = EstadoPermisoDiario(abierto: true, permiso: permiso);
        _procesando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _errorAccion = error;
      });
    }
  }

  Future<void> _cerrar() async {
    setState(() {
      _procesando = true;
      _errorAccion = null;
    });

    try {
      final permiso = await _repositorio.cerrar();
      if (!mounted) return;
      setState(() {
        _estado = EstadoPermisoDiario(abierto: false, permiso: permiso);
        _procesando = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _errorAccion = error;
      });
    }
  }

  /// Selector opcional de hora límite antes de abrir — si el usuario
  /// cancela el picker, `abrir()` se llama igual sin `horaLimite` (el
  /// backend cae en el default `23:59:59`).
  Future<void> _elegirHoraYAbrir() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 23, minute: 59),
      helpText: 'Hora límite de hoy',
    );
    if (hora == null) return;

    final horaLimite =
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}:00';
    await _abrir(horaLimite: horaLimite);
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

    final estado = _estado!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Permisos diarios',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textoPrincipal,
                  ),
                ),
                IconButton(
                  onPressed: _cargando ? null : _cargar,
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Habilita a preceptores y profesores a tomar asistencia hoy. '
              'Sin este permiso abierto, el sistema no deja abrir ninguna '
              'planilla nueva del día.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textoSecundario,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (_errorAccion != null) ...[
              BannerError(mensaje: _errorAccion!.mensaje),
              const SizedBox(height: 16),
            ],
            _TarjetaEstado(estado: estado),
            const SizedBox(height: 20),
            _Acciones(
              estado: estado,
              procesando: _procesando,
              onAbrir: () => _abrir(),
              onElegirHoraYAbrir: _elegirHoraYAbrir,
              onCerrar: _cerrar,
            ),
            if (estado.permiso == null) ...[
              const SizedBox(height: 20),
              const BannerInfo(
                mensaje: 'El cierre normal es automático: pasada la hora '
                    'límite, el permiso se cierra solo sin que haga falta '
                    'ninguna acción acá. "Cerrar anticipadamente" es solo '
                    'para el caso puntual de terminar el día antes de esa '
                    'hora.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TarjetaEstado extends StatelessWidget {
  const _TarjetaEstado({required this.estado});

  final EstadoPermisoDiario estado;

  @override
  Widget build(BuildContext context) {
    final permiso = estado.permiso;
    final abierto = estado.abierto;

    final Color colorEstado = abierto ? AppColors.exito : AppColors.textoSecundario;
    final String etiquetaEstado = abierto ? 'Abierto' : 'Cerrado';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: abierto ? AppColors.exito.withValues(alpha: 0.4) : AppColors.borde,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            abierto ? Icons.lock_open_outlined : Icons.lock_outline,
            size: 22,
            color: colorEstado,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  permiso == null ? 'Hoy' : 'Hoy, ${permiso.fecha}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  permiso == null
                      ? 'Todavía no se abrió ningún permiso para hoy.'
                      : abierto
                          ? 'Abierto desde las ${permiso.horaAperturaCorta} — '
                              'se cierra solo a las ${permiso.horaLimiteCorta}.'
                          : permiso.cerradoManual
                              ? 'Se abrió a las ${permiso.horaAperturaCorta} y '
                                  'se cerró antes de tiempo, a mano.'
                              : 'Se abrió a las ${permiso.horaAperturaCorta} y '
                                  'ya venció (hora límite: '
                                  '${permiso.horaLimiteCorta}).',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              etiquetaEstado,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colorEstado,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.estado,
    required this.procesando,
    required this.onAbrir,
    required this.onElegirHoraYAbrir,
    required this.onCerrar,
  });

  final EstadoPermisoDiario estado;
  final bool procesando;
  final VoidCallback onAbrir;
  final VoidCallback onElegirHoraYAbrir;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    if (estado.abierto) {
      return SizedBox(
        height: 46,
        child: OutlinedButton.icon(
          onPressed: procesando ? null : onCerrar,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: procesando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_clock_outlined, size: 20),
          label: const Text(
            'Cerrar anticipadamente',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              onPressed: procesando ? null : onAbrir,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.azulPrimario,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.azulPrimario.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: procesando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.lock_open_outlined, size: 20),
              label: Text(
                estado.permiso == null
                    ? 'Abrir permiso de hoy'
                    : 'Volver a abrir',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: procesando ? null : onElegirHoraYAbrir,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.azulPrimario,
              side: const BorderSide(color: AppColors.azulPrimario),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text(
              'Con hora límite...',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }
}

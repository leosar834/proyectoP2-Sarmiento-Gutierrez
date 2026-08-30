import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asignacion.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/asistencia_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import 'tomar_asistencia_screen.dart';

/// Pantalla de inicio real de la app móvil (RF2) — reemplaza a
/// `HomePlaceholderScreen` para `plataforma == 'movil'` (ver
/// `SplashScreen`). Lista "mis asignaciones" (`GET /mis-asignaciones`) y
/// deja entrar a tomar asistencia de un curso.
///
/// Alcance a propósito acotado, igual que el backend
/// (`AsistenciaController::alumnos()`): solo los ítems `area == 'teorica'`
/// llevan a algo real. Los de `taller`/`ed_fisica` se muestran igual —
/// para que quien tenga esas asignaciones sepa que existen — pero
/// deshabilitados, con la misma etiqueta "Pronto" que ya usa el panel de
/// escritorio para sus secciones sin construir todavía.
class MisAsignacionesScreen extends StatefulWidget {
  const MisAsignacionesScreen({super.key});

  @override
  State<MisAsignacionesScreen> createState() => _MisAsignacionesScreenState();
}

class _MisAsignacionesScreenState extends State<MisAsignacionesScreen> {
  late final AsistenciaRepository _repositorio;

  bool _cargando = true;
  ApiException? _errorCarga;
  List<Asignacion> _asignaciones = const [];

  /// Curso elegido para tomar asistencia — `null` muestra la lista.
  /// A propósito NO se usa `Navigator.push` para esto, ver el docblock
  /// de `TomarAsistenciaScreen`.
  Asignacion? _cursoSeleccionado;

  @override
  void initState() {
    super.initState();
    _repositorio =
        AsistenciaRepository(context.read<AuthProvider>().apiClient);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final asignaciones = await _repositorio.misAsignaciones();
      if (!mounted) return;
      setState(() {
        _asignaciones = asignaciones;
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
    // Sin AppBar propia mientras hay un curso elegido: `TomarAsistenciaScreen`
    // ya trae su propio encabezado con "volver" — dos barras superiores
    // apiladas (esta + la suya) se veía redundante y le comía espacio a
    // la grilla de alumnos, que en un celular ya es lo más apretado de
    // la pantalla.
    if (_cursoSeleccionado != null) {
      return Scaffold(
        body: SafeArea(
          child: TomarAsistenciaScreen(
            cursoId: _cursoSeleccionado!.id,
            etiqueta: _cursoSeleccionado!.etiqueta,
            onCerrar: () => setState(() => _cursoSeleccionado = null),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis cursos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
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

    if (_asignaciones.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Todavía no tenés ningún curso o grupo asignado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 13.5),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _asignaciones.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, indice) {
          final asignacion = _asignaciones[indice];
          return _TarjetaAsignacion(
            asignacion: asignacion,
            onTap: asignacion.esTeorica
                ? () => setState(() => _cursoSeleccionado = asignacion)
                : null,
          );
        },
      ),
    );
  }
}

class _TarjetaAsignacion extends StatelessWidget {
  const _TarjetaAsignacion({required this.asignacion, required this.onTap});

  final Asignacion asignacion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disponible = onTap != null;

    return Material(
      color: AppColors.tarjeta,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borde),
          ),
          child: Row(
            children: [
              Icon(
                _iconoPorArea(asignacion.area),
                size: 22,
                color: disponible ? AppColors.azulPrimario : AppColors.textoSecundario,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  asignacion.etiqueta,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: disponible ? AppColors.textoPrincipal : AppColors.textoSecundario,
                  ),
                ),
              ),
              if (!disponible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.textoSecundario.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Pronto',
                    style: TextStyle(fontSize: 10.5, color: AppColors.textoSecundario),
                  ),
                )
              else
                const Icon(Icons.chevron_right, color: AppColors.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconoPorArea(String area) {
    return switch (area) {
      'teorica' => Icons.meeting_room_outlined,
      'taller' => Icons.construction_outlined,
      'ed_fisica' => Icons.sports_soccer_outlined,
      _ => Icons.class_outlined,
    };
  }
}

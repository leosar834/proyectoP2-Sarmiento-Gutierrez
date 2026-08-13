import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/institucion.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/institucion_repository.dart';
import '../theme/app_colors.dart';
import 'alumnos_screen.dart';
import 'ciclo_lectivo_screen.dart';
import 'cursos_screen.dart';
import 'divisiones_screen.dart';
import 'institucion_screen.dart';
import 'niveles_screen.dart';
import 'roles_screen.dart';
import 'usuarios_screen.dart';

/// Casa del panel de administración de escritorio: menú lateral fijo +
/// contenido que cambia de sección. Reemplaza a `HomePlaceholderScreen`
/// para `plataforma == 'escritorio'` (ver `SplashScreen`) — la app
/// móvil sigue usando el placeholder, porque su pantalla de inicio real
/// es "tomar asistencia" (RF2), un desarrollo aparte.
///
/// "Inicio", "Institución", "Ciclo lectivo", "Niveles" y "Divisiones"
/// tienen contenido real hoy — el resto de las secciones (Usuarios,
/// Roles, Alumnos, Cursos, Reportes, Alertas) ya tienen su API lista en
/// el backend (`permiso:gestionar_sistema`), pero construir cada
/// pantalla es trabajo aparte; se muestran acá como navegación real con
/// un contenido "Próximamente" en vez de placeholders inertes, para que
/// el menú completo ya esté a la vista de quien use el sistema.
///
/// "Niveles" y "Divisiones" van ANTES que "Cursos" a propósito, aunque
/// esta última todavía sea "Próximamente": un curso es nivel + división
/// + ciclo lectivo, así que hacen falta estos dos catálogos cargados
/// antes de que la pantalla de Cursos tenga algo de qué elegir.
class PanelEscritorioScreen extends StatefulWidget {
  const PanelEscritorioScreen({super.key});

  @override
  State<PanelEscritorioScreen> createState() => _PanelEscritorioScreenState();
}

enum _Seccion {
  inicio,
  usuarios,
  roles,
  alumnos,
  niveles,
  divisiones,
  cursos,
  cicloLectivo,
  reportes,
  alertas,
  institucion,
}

class _ItemMenu {
  const _ItemMenu({
    required this.seccion,
    required this.etiqueta,
    required this.icono,
    this.disponible = false,
  });

  final _Seccion seccion;
  final String etiqueta;
  final IconData icono;

  /// Si es `false`, la sección todavía no tiene pantalla propia y el
  /// contenido muestra un aviso de "Próximamente" en vez de romper la
  /// navegación.
  final bool disponible;
}

const _itemsMenu = [
  _ItemMenu(
    seccion: _Seccion.inicio,
    etiqueta: 'Inicio',
    icono: Icons.home_outlined,
    disponible: true,
  ),
  _ItemMenu(
    seccion: _Seccion.usuarios,
    etiqueta: 'Usuarios',
    icono: Icons.people_outline,
    disponible: true,
  ),
  _ItemMenu(
    seccion: _Seccion.roles,
    etiqueta: 'Roles y permisos',
    icono: Icons.admin_panel_settings_outlined,
    disponible: true,
  ),
  _ItemMenu(
    seccion: _Seccion.alumnos,
    etiqueta: 'Alumnos',
    icono: Icons.school_outlined,
    disponible: true,
  ),
  _ItemMenu(
    seccion: _Seccion.niveles,
    etiqueta: 'Niveles',
    icono: Icons.stairs_outlined,
    disponible: true,
  ),
  _ItemMenu(
    seccion: _Seccion.divisiones,
    etiqueta: 'Divisiones',
    icono: Icons.view_column_outlined,
    disponible: true,
  ),
  _ItemMenu(
    seccion: _Seccion.cursos,
    etiqueta: 'Cursos',
    icono: Icons.meeting_room_outlined,
    disponible: true,
  ),
  _ItemMenu(
    seccion: _Seccion.cicloLectivo,
    etiqueta: 'Ciclo lectivo',
    icono: Icons.event_repeat_outlined,
    disponible: true,
  ),
  _ItemMenu(
    seccion: _Seccion.reportes,
    etiqueta: 'Reportes',
    icono: Icons.bar_chart_outlined,
  ),
  _ItemMenu(
    seccion: _Seccion.alertas,
    etiqueta: 'Alertas',
    icono: Icons.notifications_active_outlined,
  ),
  _ItemMenu(
    seccion: _Seccion.institucion,
    etiqueta: 'Institución',
    icono: Icons.apartment_outlined,
    disponible: true,
  ),
];

class _PanelEscritorioScreenState extends State<PanelEscritorioScreen> {
  _Seccion _seccionActual = _Seccion.inicio;

  Institucion? _institucion;
  bool _cargandoInstitucion = true;

  @override
  void initState() {
    super.initState();
    _cargarInstitucion();
  }

  /// Se carga una sola vez acá arriba (no en cada sección) porque tanto
  /// el encabezado del menú como "Inicio" la necesitan. Si falla (sin
  /// red, backend caído) no bloquea el panel entero — simplemente el
  /// encabezado y "Inicio" quedan con el nombre genérico del sistema;
  /// la sección "Institución" tiene su propio manejo de error con
  /// reintento, porque ahí sí es el contenido principal de la pantalla.
  Future<void> _cargarInstitucion() async {
    try {
      final repositorio =
          InstitucionRepository(context.read<AuthProvider>().apiClient);
      final institucion = await repositorio.obtener();
      if (!mounted) return;
      setState(() {
        _institucion = institucion;
        _cargandoInstitucion = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _cargandoInstitucion = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _MenuLateral(
            seccionActual: _seccionActual,
            institucion: _institucion,
            cargandoInstitucion: _cargandoInstitucion,
            onSeleccionar: (seccion) =>
                setState(() => _seccionActual = seccion),
          ),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFF3F4F6),
              child: _contenidoDeSeccion(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenidoDeSeccion() {
    switch (_seccionActual) {
      case _Seccion.inicio:
        return _InicioContenido(
          institucion: _institucion,
          cargandoInstitucion: _cargandoInstitucion,
        );
      case _Seccion.institucion:
        return InstitucionScreen(
          onActualizada: (institucion) =>
              setState(() => _institucion = institucion),
        );
      case _Seccion.cicloLectivo:
        return const CicloLectivoScreen();
      case _Seccion.niveles:
        return const NivelesScreen();
      case _Seccion.divisiones:
        return const DivisionesScreen();
      case _Seccion.cursos:
        return const CursosScreen();
      case _Seccion.roles:
        return const RolesScreen();
      case _Seccion.usuarios:
        return const UsuariosScreen();
      case _Seccion.alumnos:
        return const AlumnosScreen();
      default:
        final item =
            _itemsMenu.firstWhere((item) => item.seccion == _seccionActual);
        return _ProximamenteContenido(item: item);
    }
  }
}

class _MenuLateral extends StatelessWidget {
  const _MenuLateral({
    required this.seccionActual,
    required this.institucion,
    required this.cargandoInstitucion,
    required this.onSeleccionar,
  });

  final _Seccion seccionActual;
  final Institucion? institucion;
  final bool cargandoInstitucion;
  final ValueChanged<_Seccion> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.usuario;

    return Container(
      width: 260,
      color: AppColors.fondoOscuro,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cargandoInstitucion)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  else
                    Text(
                      institucion?.nombre ?? 'Sistema de Asistencia',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'Panel de administración',
                    style: TextStyle(
                      color: AppColors.textoSecundarioSobreOscuro,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _itemsMenu.map((item) {
                  final seleccionado = item.seccion == seccionActual;
                  return _ItemMenuTile(
                    item: item,
                    seleccionado: seleccionado,
                    onTap: () => onSeleccionar(item.seccion),
                  );
                }).toList(growable: false),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.azulPrimario,
                    child: Icon(Icons.person, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          usuario?.nombreCompleto ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          usuario?.roles.join(', ') ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textoSecundarioSobreOscuro,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                    tooltip: 'Cerrar sesión',
                    onPressed: () => context.read<AuthProvider>().logout(),
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

class _ItemMenuTile extends StatelessWidget {
  const _ItemMenuTile({
    required this.item,
    required this.seleccionado,
    required this.onTap,
  });

  final _ItemMenu item;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: seleccionado
            ? AppColors.azulPrimario.withValues(alpha: 0.9)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  item.icono,
                  size: 19,
                  color: seleccionado ? Colors.white : Colors.white70,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.etiqueta,
                    style: TextStyle(
                      color: seleccionado ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight:
                          seleccionado ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (!item.disponible)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Pronto',
                      style: TextStyle(color: Colors.white70, fontSize: 9.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InicioContenido extends StatelessWidget {
  const _InicioContenido({
    required this.institucion,
    required this.cargandoInstitucion,
  });

  final Institucion? institucion;
  final bool cargandoInstitucion;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.usuario;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              usuario == null ? 'Hola' : 'Hola, ${usuario.nombre}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textoPrincipal,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Este es el panel de administración del sistema de '
              'asistencia.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textoSecundario),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.tarjeta,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borde),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment_outlined,
                          size: 20, color: AppColors.azulPrimario),
                      const SizedBox(width: 8),
                      const Text(
                        'Institución',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (cargandoInstitucion)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (institucion == null)
                    const Text(
                      'No se pudieron cargar los datos de la institución. '
                      'Probá de nuevo desde "Institución" en el menú.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textoSecundario,
                      ),
                    )
                  else ...[
                    Text(
                      institucion!.nombre,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _FilaDato(etiqueta: 'Domicilio', valor: institucion!.domicilio),
                    _FilaDato(
                      etiqueta: 'Localidad',
                      valor: '${institucion!.localidad}, ${institucion!.provincia}',
                    ),
                    _FilaDato(etiqueta: 'CUE', valor: institucion!.cue),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  const _FilaDato({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$etiqueta: $valor',
        style: const TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
      ),
    );
  }
}

class _ProximamenteContenido extends StatelessWidget {
  const _ProximamenteContenido({required this.item});

  final _ItemMenu item;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icono, size: 40, color: AppColors.textoSecundario),
            const SizedBox(height: 12),
            Text(
              item.etiqueta,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textoPrincipal,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Esta sección todavía no está lista — es un próximo paso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

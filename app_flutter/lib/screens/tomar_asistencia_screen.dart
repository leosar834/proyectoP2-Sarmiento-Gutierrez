import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alumno_asistencia.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/asistencia_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';

/// RF2 — la pantalla que define si el sistema sirve o no. Abre (o
/// recupera) la planilla de HOY para un curso teórico y deja marcar el
/// estado de cada alumno inscripto.
///
/// A propósito esto NO es una pantalla con ruta propia (`Navigator.push`)
/// — es un panel que `MisAsignacionesScreen` muestra "ahí mismo" en su
/// propio `body` cuando hay un curso elegido, alternando con `setState`
/// (ver `onCerrar`). Mismo criterio, y mismo motivo, que
/// `InscripcionPorCursoScreen` en el panel de escritorio: encadenar
/// `Navigator.push` desde el `onTap` de una tarjeta dispara, de forma
/// reproducible en web/desktop, un bug del framework de Flutter
/// (`Assertion failed... mouse_tracker.dart:199`) al sacar del árbol el
/// widget que originó la navegación justo cuando arranca la ruta nueva.
/// Ver el docblock de `InscripcionPorCursoScreen` para el detalle
/// completo — se aplica igual acá, y en este proyecto se prueba
/// habitualmente por Chrome.
///
/// A diferencia de taller, un curso teórico no tiene paso de "enviar":
/// `AsistenciaController::enviar()` solo acepta planillas de taller, así
/// que acá `guardarDetalles()` se puede llamar tantas veces como haga
/// falta durante el día — no hace falta completar los 30 alumnos de una
/// para poder guardar lo que ya se marcó.
class TomarAsistenciaScreen extends StatefulWidget {
  const TomarAsistenciaScreen({
    super.key,
    required this.cursoId,
    required this.etiqueta,
    required this.onCerrar,
  });

  final int cursoId;
  final String etiqueta;

  /// Vuelve a "Mis cursos" — no recibe ningún resultado porque guardar
  /// asistencia no cambia nada de lo que esa lista muestra (a diferencia
  /// de `InscripcionPorCursoScreen`, que sí necesita avisar si hay que
  /// refrescar).
  final VoidCallback onCerrar;

  @override
  State<TomarAsistenciaScreen> createState() => _TomarAsistenciaScreenState();
}

class _TomarAsistenciaScreenState extends State<TomarAsistenciaScreen> {
  late final AsistenciaRepository _repositorio;

  bool _cargando = true;
  ApiException? _errorCarga;

  int? _idPlanilla;
  List<AlumnoAsistencia> _alumnos = const [];

  // inscripcionId -> estado. Arranca con lo que ya haya llegado cargado
  // (`estadoInicial`) y el usuario lo va pisando al tocar un chip — es
  // la única fuente de verdad para lo que se manda en `_guardar()`, los
  // objetos de `_alumnos` nunca se tocan.
  final Map<int, String> _estados = {};

  bool _guardando = false;
  ApiException? _errorGuardado;

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
      final planilla =
          await _repositorio.abrirPlanillaTeorica(cursoId: widget.cursoId);
      final alumnos = await _repositorio.obtenerAlumnos(planilla.idPlanilla);

      if (!mounted) return;
      setState(() {
        _idPlanilla = planilla.idPlanilla;
        _alumnos = alumnos;
        _estados.clear();
        for (final alumno in alumnos) {
          if (alumno.estadoInicial != null) {
            _estados[alumno.inscripcionId] = alumno.estadoInicial!;
          }
        }
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

  void _elegirEstado(int inscripcionId, String estado) {
    setState(() => _estados[inscripcionId] = estado);
  }

  Future<void> _guardar() async {
    if (_estados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marcá al menos un alumno antes de guardar.')),
      );
      return;
    }

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });

    try {
      await _repositorio.guardarDetalles(
        idPlanilla: _idPlanilla!,
        detalles: _estados.entries
            .map((entrada) => DetalleParaGuardar(
                  inscripcionId: entrada.key,
                  estado: entrada.value,
                ))
            .toList(),
      );

      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asistencia guardada.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Encabezado(etiqueta: widget.etiqueta, onCerrar: widget.onCerrar),
        Expanded(child: _cuerpo()),
        if (!_cargando && _errorCarga == null) _barraGuardar(),
      ],
    );
  }

  Widget _barraGuardar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: AppColors.tarjeta,
          border: Border(top: BorderSide(color: AppColors.borde)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorGuardado != null) ...[
              BannerError(mensaje: _errorGuardado!.mensaje),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
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
                label: Text(
                  'Guardar (${_estados.length}/${_alumnos.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorCarga != null) {
      // Cubre, con el mismo cartel, tanto "no hay permiso diario
      // abierto" como "hoy es día sin clases" o "el profesor avisó que
      // hoy no toca" — los tres llegan como `ApiException` con un
      // mensaje ya armado por el backend (ver
      // `AsistenciaController::crear()`), así que no hace falta
      // distinguirlos acá.
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

    if (_alumnos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Este curso no tiene alumnos con inscripción activa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 13.5),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _alumnos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, indice) {
        final alumno = _alumnos[indice];
        return _FilaAlumno(
          alumno: alumno,
          estadoActual: _estados[alumno.inscripcionId],
          onElegir: (estado) => _elegirEstado(alumno.inscripcionId, estado),
        );
      },
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.etiqueta, required this.onCerrar});

  final String etiqueta;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
        child: Row(
          children: [
            IconButton(
              onPressed: onCerrar,
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver a mis cursos',
            ),
            Expanded(
              child: Text(
                etiqueta,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textoPrincipal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcionEstado {
  const _OpcionEstado(this.valor, this.etiqueta, this.icono, this.color);

  final String valor;
  final String etiqueta;
  final IconData icono;
  final Color color;
}

const _opcionesEstado = [
  _OpcionEstado('presente', 'Presente', Icons.check_circle_outline, AppColors.exito),
  _OpcionEstado('ausente', 'Ausente', Icons.cancel_outlined, AppColors.error),
  _OpcionEstado('tardanza', 'Tardanza', Icons.schedule_outlined, AppColors.advertencia),
  _OpcionEstado('falta_justificada', 'Justif.', Icons.description_outlined, AppColors.azulPrimario),
];

class _FilaAlumno extends StatelessWidget {
  const _FilaAlumno({
    required this.alumno,
    required this.estadoActual,
    required this.onElegir,
  });

  final AlumnoAsistencia alumno;
  final String? estadoActual;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alumno.nombreCompleto,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textoPrincipal,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _opcionesEstado
                .map((opcion) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _ChipEstado(
                          opcion: opcion,
                          seleccionado: estadoActual == opcion.valor,
                          onTap: () => onElegir(opcion.valor),
                        ),
                      ),
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  const _ChipEstado({
    required this.opcion,
    required this.seleccionado,
    required this.onTap,
  });

  final _OpcionEstado opcion;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: seleccionado ? opcion.color.withValues(alpha: 0.12) : AppColors.tarjeta,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: seleccionado ? opcion.color : AppColors.borde,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              opcion.icono,
              size: 17,
              color: seleccionado ? opcion.color : AppColors.textoSecundario,
            ),
            const SizedBox(height: 3),
            Text(
              opcion.etiqueta,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: seleccionado ? FontWeight.w700 : FontWeight.normal,
                color: seleccionado ? opcion.color : AppColors.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

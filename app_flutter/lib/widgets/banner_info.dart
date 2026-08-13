import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cartel informativo (no es un error) — mismo estilo celeste que la
/// caja de ayuda de `LoginScreen`. Se usa para explicar, dentro de la
/// pantalla misma, cómo se relaciona lo que se está cargando acá con
/// otra pantalla — por ejemplo, que "Niveles" y "Divisiones" son
/// catálogos independientes que recién se combinan en "Cursos".
class BannerInfo extends StatelessWidget {
  const BannerInfo({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoFondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.infoTexto),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.infoTexto,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

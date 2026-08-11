import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cartel de error general (mensaje que no corresponde a un campo
/// puntual) — mismo estilo en login, registro de administrador, y
/// cualquier otro formulario que lo necesite más adelante.
class BannerError extends StatelessWidget {
  const BannerError({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: const TextStyle(fontSize: 12.5, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

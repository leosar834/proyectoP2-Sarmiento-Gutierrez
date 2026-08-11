import 'package:flutter/material.dart';

/// Paleta extraída de los bocetos de Figma compartidos el 11/08/2026
/// (pantallas de login móvil/escritorio y panel de administración).

class AppColors {
  AppColors._();

  // Fondo oscuro de las pantallas de login (igual en móvil y escritorio,
  // según los bocetos) y de la futura app móvil de docentes/preceptores.
  static const Color fondoOscuro = Color(0xFF101B33);

  // Tarjeta blanca centrada del login.
  static const Color tarjeta = Color(0xFFFFFFFF);

  // Texto sobre fondo claro (dentro de la tarjeta).
  static const Color textoPrincipal = Color(0xFF1B2A4D);
  static const Color textoSecundario = Color(0xFF6B7280);

  // Texto sobre fondo oscuro (fuera de la tarjeta — footer, etc.).
  static const Color textoSecundarioSobreOscuro = Color(0xFF9AA5BD);

  // Azul de marca / botón primario — coincide aprox. con el seed
  // `Colors.indigo` que ya se usaba en el theme de Material.
  static const Color azulPrimario = Color(0xFF2F5FAD);

  // Caja informativa celeste debajo del botón principal.
  static const Color infoFondo = Color(0xFFE8F0FE);
  static const Color infoTexto = Color(0xFF3B5998);

  // Estados semánticos (presentes/ausentes/alertas — para pantallas
  // futuras de toma de asistencia, ya adelantados acá).
  static const Color exito = Color(0xFF22A55E);
  static const Color error = Color(0xFFDC2626);
  static const Color advertencia = Color(0xFFF59E0B);

  // Borde de los campos de texto.
  static const Color borde = Color(0xFFD1D5DB);
}

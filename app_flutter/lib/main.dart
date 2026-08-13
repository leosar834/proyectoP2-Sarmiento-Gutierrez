import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const AsistenciaApp());
}

/// Raíz de la app. `AuthProvider` vive acá arriba de todo (un solo
/// `ChangeNotifierProvider`, no uno por pantalla) porque la sesión es
/// estado global — cualquier pantalla nueva que se agregue más adelante
/// ya lo tiene disponible sin tener que volver a tocar este archivo.
class AsistenciaApp extends StatelessWidget {
  const AsistenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Sistema de Asistencia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        // Toda la app está en español — esto hace que los widgets del
        // propio framework (el selector de fecha de "Ciclo lectivo",
        // los botones "Cancelar"/"Aceptar" de cualquier diálogo nativo,
        // etc.) también salgan en español en vez del inglés por
        // defecto. Un solo locale soportado a propósito: el sistema es
        // para una institución argentina, no hace falta detectar el
        // idioma del sistema operativo ni ofrecer alternativas.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('es')],
        locale: const Locale('es'),
        home: const SplashScreen(),
      ),
    );
  }
}

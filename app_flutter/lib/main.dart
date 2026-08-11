import 'package:flutter/material.dart';
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
        home: const SplashScreen(),
      ),
    );
  }
}

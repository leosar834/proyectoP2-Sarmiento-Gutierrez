import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'home_placeholder_screen.dart';
import 'login_screen.dart';

/// Punto de entrada de la app: mientras `AuthProvider` todavía no sabe si
/// hay una sesión guardada (`AuthStatus.desconocido`) muestra un loading;
/// apenas lo sabe, redirige — así nunca se ve un parpadeo de "pantalla de
/// login" de por medio si en realidad ya había una sesión guardada.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // postFrameCallback en vez de llamarlo directo en initState: evita
    // disparar notifyListeners() durante el primer build del widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().cargarSesionGuardada();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.desconocido:
          case AuthStatus.autenticando:
            return const _CargandoScreen();
          case AuthStatus.autenticado:
            return const HomePlaceholderScreen();
          case AuthStatus.noAutenticado:
            return const LoginScreen();
        }
      },
    );
  }
}

class _CargandoScreen extends StatelessWidget {
  const _CargandoScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

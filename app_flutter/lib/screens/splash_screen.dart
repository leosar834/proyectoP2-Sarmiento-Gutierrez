import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'mis_asignaciones_screen.dart';
import 'panel_escritorio_screen.dart';

/// Punto de entrada de la app: mientras `AuthProvider` todavía no sabe si
/// hay una sesión guardada (`AuthStatus.desconocido`) muestra un loading;
/// apenas lo sabe, redirige — así nunca se ve un parpadeo de "pantalla de
/// login" de por medio si en realidad ya había una sesión guardada.
///
/// Autenticado, el destino depende de la plataforma sellada en el token
/// (ver `AuthProvider.plataforma`): escritorio va al panel de
/// administración real (`PanelEscritorioScreen`); móvil va a "Mis
/// cursos" (`MisAsignacionesScreen`), que es la puerta de entrada a
/// tomar asistencia (RF2). Por ahora solo lleva a algo real para
/// asignaciones de área `teorica` — taller/ed_fisica quedan pendientes,
/// ver el docblock de esa pantalla.
///
/// `AuthStatus.autenticando` queda agrupado con `noAutenticado` (sigue
/// mostrando `LoginScreen`), NO con `desconocido` — bug real encontrado
/// el 12/08/2026: agruparlo con `desconocido` hacía que, al tocar
/// "Iniciar sesión" con credenciales incorrectas, esta pantalla
/// reemplazara `LoginScreen` por `_CargandoScreen` (un widget de otro
/// tipo) apenas arrancaba el pedido, destruyendo el `State` de
/// `LoginScreen` con el error todavía en camino; cuando el backend
/// respondía con el 422 y el status volvía a `noAutenticado`, se creaba
/// una `LoginScreen` NUEVA, así que el `setState` que iba a mostrar el
/// error corría sobre un `State` ya descartado (`mounted == false`) y
/// se perdía en silencio — la pantalla "parpadeaba" pero nunca mostraba
/// por qué. `LoginScreen` ya tiene su propio spinner en el botón
/// (`context.watch<AuthProvider>().status == AuthStatus.autenticando`),
/// así que no hace falta un `_CargandoScreen` aparte para ese momento.

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
            return const _CargandoScreen();
          case AuthStatus.autenticando:
          case AuthStatus.noAutenticado:
            return const LoginScreen();
          case AuthStatus.autenticado:
            return auth.plataforma == 'escritorio'
                ? const PanelEscritorioScreen()
                : const MisAsignacionesScreen();
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

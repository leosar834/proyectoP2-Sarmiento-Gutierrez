import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Placeholder a propósito, igual que `LoginPlaceholderScreen` — la
/// pantalla real (tomar asistencia del día, per RF2) es un paso
/// posterior. Esta existe para probar de punta a punta que login,
/// persistencia de sesión, y `GET /me` funcionan: si ves tu nombre y
/// plataforma acá después de loguearte, la estructura común anda bien.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final usuario = auth.usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Asistencia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 48),
              const SizedBox(height: 16),
              Text(
                usuario == null
                    ? 'Sesión activa'
                    : 'Hola, ${usuario.nombreCompleto}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (usuario != null) ...[
                const SizedBox(height: 4),
                Text(usuario.email, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  'Roles: ${usuario.roles.join(", ")}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Plataforma: ${auth.plataforma ?? "-"}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pantalla de "tomar asistencia" — próximo paso.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

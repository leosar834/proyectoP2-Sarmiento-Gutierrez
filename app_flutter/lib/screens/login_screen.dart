import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/campo_texto.dart';
import 'admin_registro_screen.dart';

/// Pantalla real de login.
///
/// El estilo (fondo oscuro, tarjeta blanca centrada, logo, tipografía,
/// caja informativa celeste) sigue los bocetos de Figma compartidos el
/// 11/08/2026, que usan el mismo diseño de login tanto para la app móvil
/// como para el panel de escritorio. Lo único que cambia respecto al
/// boceto es la FUNCIÓN (según lo pedido: "ten en cuenta los estilos mas
/// no las funciones"): el boceto muestra login solo con Google, pero el
/// backend (`LoginRequest`) espera email + contraseña + `plataforma`, así
/// que el botón de Google se reemplaza por un formulario normal.
///
/// La `plataforma` ('movil'/'escritorio') no se pide en un selector —
/// se resuelve sola según dónde corre el build (ver `ApiConfig.plataforma`),
/// que es justamente lo que asume el boceto (la pantalla ya "sabe" en qué
/// app está).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _passwordVisible = false;
  ApiException? _ultimoError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _ultimoError = null);

    try {
      await context.read<AuthProvider>().login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            plataforma: ApiConfig.plataforma,
          );
      // No hace falta navegar a mano: SplashScreen escucha AuthProvider y,
      // apenas el status pasa a `autenticado`, reemplaza esta pantalla
      // por HomePlaceholderScreen solo.
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _ultimoError = error);
      // El Form ya validó con los closures viejos (sin `_ultimoError`)
      // en el `validate()` de más arriba. Se vuelve a pedir acá, después
      // del rebuild, para que los campos tomen los errores del backend
      // (ej. "Estas credenciales no coinciden...") sin esperar a un
      // segundo submit.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
    }
  }

  String? _validarEmail(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingrese su email.';
    }
    if (!valor.contains('@')) {
      return 'Ingrese un email válido.';
    }
    return null;
  }

  String? _validarPassword(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Ingrese tu contraseña.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final autenticando =
        context.watch<AuthProvider>().status == AuthStatus.autenticando;

    return Scaffold(
      backgroundColor: AppColors.fondoOscuro,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.tarjeta,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _Logo(),
                          const SizedBox(height: 16),
                          const Text(
                            'ASISTENCIA ESCOLAR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: AppColors.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sistema de Gestión de Asistencia Escolar',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: AppColors.borde),
                          const SizedBox(height: 20),
                          const Text(
                            'INICIAR SESIÓN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_ultimoError != null) ...[
                            BannerError(mensaje: _ultimoError!.mensaje),
                            const SizedBox(height: 16),
                          ],
                          CampoTexto(
                            etiqueta: 'Email *',
                            controller: _emailController,
                            hint: 'Ej: nombre@escuela.edu.ar',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: _validarEmail,
                            errorServidor: _ultimoError?.errorDeCampo('email'),
                          ),
                          const SizedBox(height: 14),
                          CampoTexto(
                            etiqueta: 'Contraseña *',
                            controller: _passwordController,
                            hint: 'Tu contraseña',
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.done,
                            validator: _validarPassword,
                            errorServidor:
                                _ultimoError?.errorDeCampo('password'),
                            onFieldSubmitted: (_) => _submit(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: AppColors.textoSecundario,
                              ),
                              onPressed: () => setState(
                                () => _passwordVisible = !_passwordVisible,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: autenticando ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.azulPrimario,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.azulPrimario.withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: autenticando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Iniciar sesión',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.infoFondo,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: AppColors.infoTexto,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ingrese con el usuario y la contraseña '
                                    'que le dio la institución.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.infoTexto,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // El boceto de escritorio incluye este enlace
                          // debajo de la tarjeta de login; el de móvil no
                          // lo tiene (los docentes/preceptores no se
                          // autoregistran). Se muestra solo cuando
                          // `ApiConfig.plataforma` es 'escritorio'.
                          if (ApiConfig.plataforma == 'escritorio') ...[
                            const SizedBox(height: 16),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AdminRegistroScreen(),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.azulPrimario,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text(
                                  '¿No tenés acceso? Registrá la primera '
                                  'cuenta de administrador aquí',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Ayuda de desarrollo: contra qué backend está apuntando
                // este build. Útil mientras se prueba en distintas
                // máquinas/emuladores — se puede sacar más adelante.
                Text(
                  'Backend: ${ApiConfig.baseUrl}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textoSecundarioSobreOscuro,
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.fondoOscuro,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.school, color: Colors.white, size: 32),
      ),
    );
  }
}

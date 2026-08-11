import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/banner_error.dart';
import '../widgets/campo_texto.dart';

/// Registro real del primer administrador del sistema — llama a
/// `POST /registro-administrador` (ver `RegistroAdministradorController`
/// en el backend). Reemplaza al placeholder anterior.
///
/// Estilo del boceto "Admin - Registro del Administrador" (barra oscura
/// con título arriba, formulario centrado sobre fondo claro). Función
/// distinta al boceto, como el resto de esta pantalla de auth: en vez de
/// "Vincular con Google" se pide contraseña propia + confirmación,
/// porque el sistema no tiene integración con Google (ver el docblock
/// de `RegistroAdministradorRequest` en el backend). Tampoco hay paso de
/// "Registro de la Institución" — el sistema asume una sola institución
/// fija, no hace falta darla de alta.
class AdminRegistroScreen extends StatefulWidget {
  const AdminRegistroScreen({super.key});

  @override
  State<AdminRegistroScreen> createState() => _AdminRegistroScreenState();
}

class _AdminRegistroScreenState extends State<AdminRegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _passwordVisible = false;
  bool _passwordConfirmVisible = false;
  ApiException? _ultimoError;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _ultimoError = null);

    try {
      await context.read<AuthProvider>().registrarAdministrador(
            nombre: _nombreController.text.trim(),
            apellido: _apellidoController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            passwordConfirmation: _passwordConfirmController.text,
          );

      if (!mounted) return;
      // A diferencia del login (que no está "pusheado", SplashScreen lo
      // devuelve directo), esta pantalla sí se abrió con
      // `Navigator.push` — hay que cerrarla a mano para que quede a la
      // vista lo que SplashScreen ya cambió por debajo (HomePlaceholder,
      // ahora que el status es `autenticado`).
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _ultimoError = error);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _formKey.currentState?.validate();
      });
    }
  }

  String? _validarRequerido(String? valor, String etiqueta) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingrese $etiqueta.';
    }
    return null;
  }

  String? _validarEmail(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Ingrese un email.';
    }
    if (!valor.contains('@')) {
      return 'Ingrese un email válido.';
    }
    return null;
  }

  String? _validarPassword(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Ingrese una contraseña.';
    }
    if (valor.length < 8) {
      return 'Tiene que tener al menos 8 caracteres.';
    }
    return null;
  }

  String? _validarConfirmacion(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Repita la contraseña.';
    }
    if (valor != _passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final autenticando =
        context.watch<AuthProvider>().status == AuthStatus.autenticando;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.fondoOscuro,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Volver al login',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: 48),
                      child: Text(
                        'Configuración Inicial del Sistema — Registro del '
                        'Administrador',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.tarjeta,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Esta cuenta va a tener acceso total al sistema '
                            '(gestión de usuarios, cursos, alumnos, '
                            'reportes y corrección de asistencia).',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textoSecundario,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (_ultimoError != null) ...[
                            BannerError(mensaje: _ultimoError!.mensaje),
                            const SizedBox(height: 16),
                          ],
                          CampoTexto(
                            etiqueta: 'Nombre *',
                            controller: _nombreController,
                            hint: 'Ej: Verónica',
                            textInputAction: TextInputAction.next,
                            validator: (v) => _validarRequerido(v, 'tu nombre'),
                            errorServidor: _ultimoError?.errorDeCampo('nombre'),
                          ),
                          const SizedBox(height: 14),
                          CampoTexto(
                            etiqueta: 'Apellido *',
                            controller: _apellidoController,
                            hint: 'Ej: Aparicio',
                            textInputAction: TextInputAction.next,
                            validator: (v) =>
                                _validarRequerido(v, 'tu apellido'),
                            errorServidor:
                                _ultimoError?.errorDeCampo('apellido'),
                          ),
                          const SizedBox(height: 14),
                          CampoTexto(
                            etiqueta: 'Cuenta institucional o de Gmail *',
                            controller: _emailController,
                            hint: 'Ej: veronica@gmail.com',
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            validator: _validarEmail,
                            errorServidor: _ultimoError?.errorDeCampo('email'),
                          ),
                          const SizedBox(height: 14),
                          CampoTexto(
                            etiqueta: 'Contraseña *',
                            controller: _passwordController,
                            hint: 'Mínimo 8 caracteres',
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.next,
                            validator: _validarPassword,
                            errorServidor:
                                _ultimoError?.errorDeCampo('password'),
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
                          const SizedBox(height: 14),
                          CampoTexto(
                            etiqueta: 'Confirmar contraseña *',
                            controller: _passwordConfirmController,
                            hint: 'Repite la contraseña',
                            obscureText: !_passwordConfirmVisible,
                            textInputAction: TextInputAction.done,
                            validator: _validarConfirmacion,
                            onFieldSubmitted: (_) => _submit(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _passwordConfirmVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                                color: AppColors.textoSecundario,
                              ),
                              onPressed: () => setState(
                                () => _passwordConfirmVisible =
                                    !_passwordConfirmVisible,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
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
                              icon: autenticando
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline,
                                      size: 20),
                              label: const Text(
                                'Crear cuenta de administrador',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Al confirmar, se crea tu cuenta y quedarás '
                            'logueado directamente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

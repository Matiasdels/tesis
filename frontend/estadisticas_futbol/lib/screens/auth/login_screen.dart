import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_api.dart';
import '../../data/remote/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  bool _registerMode = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _usuarioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final busy = auth.loading || !auth.initialized;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border.all(color: AppColors.borderSubtle, width: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(registerMode: _registerMode),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _usuarioController,
                          enabled: !busy,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: _registerMode
                                ? 'Nombre de usuario'
                                : 'Usuario o email',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: _required,
                        ),
                        if (_registerMode) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailController,
                            enabled: !busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: _email,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _nombreController,
                                  enabled: !busy,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre',
                                  ),
                                  validator: _required,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _apellidoController,
                                  enabled: !busy,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Apellido',
                                  ),
                                  validator: _required,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !busy,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => busy ? null : _submit(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: busy
                                  ? null
                                  : () => setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      }),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final message = _required(value);
                            if (message != null) return message;
                            if (value!.length < 8) {
                              return 'Mínimo 8 caracteres';
                            }
                            return null;
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: busy ? null : _submit,
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : Icon(_registerMode
                                  ? Icons.person_add_alt
                                  : Icons.login),
                          label: Text(!auth.initialized
                              ? 'Comprobando sesión'
                              : _registerMode
                                  ? 'Crear cuenta'
                                  : 'Iniciar sesión'),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                    _registerMode = !_registerMode;
                                    _error = null;
                                  }),
                          child: Text(
                            _registerMode ? 'Ya tengo cuenta' : 'Crear cuenta',
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
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obligatorio';
    }
    return null;
  }

  String? _email(String? value) {
    final message = _required(value);
    if (message != null) return message;

    final email = value!.trim();
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) {
      return 'Ingresá un email válido';
    }

    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthState>();
    setState(() => _error = null);

    try {
      if (_registerMode) {
        await auth.register(
          nombreUsuario: _usuarioController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          nombre: _nombreController.text.trim(),
          apellido: _apellidoController.text.trim(),
          rolId: 1,
        );
      } else {
        await auth.login(
          usuarioOEmail: _usuarioController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (mounted) {
        context.go(AppConstants.routeDashboard);
      }
    } on AuthApiException catch (error) {
      setState(() => _error = error.toString());
    } catch (_) {
      setState(() {
        _error = 'No pudimos completar la acción. Intentá nuevamente.';
      });
    }
  }
}

class _Header extends StatelessWidget {
  final bool registerMode;

  const _Header({required this.registerMode});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sports_soccer, color: Colors.black),
            ),
            const SizedBox(width: 12),
            const Text(
              'Kancha',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          registerMode ? 'Crear acceso' : 'Inicio de sesión',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          registerMode
              ? 'Registrá un usuario para acceder al sistema.'
              : 'Ingresá con tu usuario o email registrado.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

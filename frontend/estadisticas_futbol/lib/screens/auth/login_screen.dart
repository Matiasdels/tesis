import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
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
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginSportBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _IdentityBlock(),
                      const SizedBox(height: 22),
                      _LoginPanel(
                        formKey: _formKey,
                        registerMode: _registerMode,
                        busy: busy,
                        initialized: auth.initialized,
                        usuarioController: _usuarioController,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        nombreController: _nombreController,
                        apellidoController: _apellidoController,
                        obscurePassword: _obscurePassword,
                        error: _error,
                        onTogglePassword: () => setState(() {
                          _obscurePassword = !_obscurePassword;
                        }),
                        onSubmit: _submit,
                        onToggleMode: () => setState(() {
                          _registerMode = !_registerMode;
                          _error = null;
                        }),
                        requiredValidator: _required,
                        emailValidator: _email,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
      return 'Ingresa un email valido';
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
        _error = 'No pudimos completar la accion. Intenta nuevamente.';
      });
    }
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderSubtle.withValues(alpha: 0.9),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgDeep.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.accentDim,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.35),
                      width: 0.5,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/kancha_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kancha',
                        style: AppTypography.textTheme.displayMedium?.copyWith(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Panel técnico deportivo',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Datos claros para decisiones dentro y fuera de la cancha.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _IdentityChip(label: 'Seguimiento'),
                _IdentityChip(label: 'Eventos'),
                _IdentityChip(label: 'Reportes'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  final String label;

  const _IdentityChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgMuted.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final bool registerMode;
  final bool busy;
  final bool initialized;
  final TextEditingController usuarioController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController nombreController;
  final TextEditingController apellidoController;
  final bool obscurePassword;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final FormFieldValidator<String> requiredValidator;
  final FormFieldValidator<String> emailValidator;

  const _LoginPanel({
    required this.formKey,
    required this.registerMode,
    required this.busy,
    required this.initialized,
    required this.usuarioController,
    required this.emailController,
    required this.passwordController,
    required this.nombreController,
    required this.apellidoController,
    required this.obscurePassword,
    required this.error,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onToggleMode,
    required this.requiredValidator,
    required this.emailValidator,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.96),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgDeep.withValues(alpha: 0.55),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                registerMode ? 'Crear acceso' : 'Inicio de sesión',
                style: AppTypography.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                registerMode
                    ? 'Registrá un usuario para acceder al sistema.'
                    : 'Accedé al panel técnico del plantel.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: usuarioController,
                enabled: !busy,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText:
                      registerMode ? 'Nombre de usuario' : 'Usuario o email',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: requiredValidator,
              ),
              if (registerMode) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: emailValidator,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: nombreController,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: requiredValidator,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: apellidoController,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        decoration:
                            const InputDecoration(labelText: 'Apellido'),
                        validator: requiredValidator,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                enabled: !busy,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => busy ? null : onSubmit(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: obscurePassword
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    onPressed: busy ? null : onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  final message = requiredValidator(value);
                  if (message != null) return message;
                  if (value!.length < 8) {
                    return 'Mínimo 8 caracteres';
                  }
                  return null;
                },
              ),
              if (error != null) ...[
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: busy ? null : onSubmit,
                icon: busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bgDeep,
                        ),
                      )
                    : Icon(registerMode ? Icons.person_add_alt : Icons.login),
                label: Text(
                  !initialized
                      ? 'Comprobando sesión'
                      : registerMode
                          ? 'Crear cuenta'
                          : 'Iniciar sesión',
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: busy ? null : onToggleMode,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Text(
                    registerMode ? 'Ya tengo cuenta' : 'Crear cuenta',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginSportBackground extends StatelessWidget {
  const _LoginSportBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LoginSportBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _LoginSportBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = AppColors.bgDeep;
    canvas.drawRect(Offset.zero & size, basePaint);

    final accentPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final linePaint = Paint()
      ..color = AppColors.borderSubtle.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final mutedPaint = Paint()
      ..color = AppColors.bgSurface.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final fieldRect = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.08,
      size.width * 0.8,
      size.height * 0.84,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(fieldRect, const Radius.circular(22)),
      linePaint,
    );
    canvas.drawLine(
      Offset(fieldRect.left, fieldRect.center.dy),
      Offset(fieldRect.right, fieldRect.center.dy),
      linePaint,
    );
    canvas.drawCircle(fieldRect.center, size.width * 0.16, accentPaint);
    canvas.drawCircle(fieldRect.center, 3, accentPaint);

    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.16 + i * 0.16);
      canvas.drawLine(
        Offset(size.width * -0.1, y),
        Offset(size.width * 1.1, y + size.height * 0.08),
        linePaint,
      );
    }

    canvas.drawCircle(
      Offset(size.width * 0.16, size.height * 0.18),
      size.width * 0.22,
      mutedPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.86, size.height * 0.78),
      size.width * 0.28,
      mutedPaint,
    );

    final arcPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.92, size.height * 0.16),
        radius: size.width * 0.26,
      ),
      math.pi * 0.6,
      math.pi * 0.95,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_LoginSportBackgroundPainter oldDelegate) => false;
}

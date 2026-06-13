import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LogoMark(),
                SizedBox(height: 22),
                Text(
                  'Kancha',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Preparando tu espacio de trabajo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 28),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppColors.accent,
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

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const Icon(
        Icons.sports_soccer,
        color: Colors.black,
        size: 42,
      ),
    );
  }
}

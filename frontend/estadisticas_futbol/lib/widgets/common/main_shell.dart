import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/remote/auth_state.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppConstants.tabletBreakpoint;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            const _AppSidebar(),
            VerticalDivider(width: 0.5, color: AppColors.borderSubtle),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        titleSpacing: 16,
        title: InkWell(
          onTap: () {
            context.go(AppConstants.routeDashboard);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Image.asset(
              'assets/images/kancha_logo.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            onPressed: () {
              _showSettingsPanel(context);
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Perfil',
            onPressed: () {
              _showProfileSheet(context);
            },
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.55),
                  AppColors.borderSubtle,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: child,
      bottomNavigationBar: const _AppBottomNav(),
    );
  }
}

// ignore: unused_element
void _showSettingsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configuración',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Consumer<ThemeController>(
                builder: (context, themeController, _) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.borderSubtle,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: themeController.isDarkMode
                                ? AppColors.purpleDim
                                : AppColors.warningDim,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            themeController.isDarkMode
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: themeController.isDarkMode
                                ? AppColors.purple
                                : AppColors.warning,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tema de la aplicación',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                themeController.isDarkMode
                                    ? 'Modo noche'
                                    : 'Modo día',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ThemeToggle(
                          isDarkMode: themeController.isDarkMode,
                          onChanged: themeController.setDarkMode,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

void _showSettingsPanel(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.82;
      return Consumer<ThemeController>(
        builder: (context, themeController, _) {
          final sheetBackground =
              themeController.isDarkMode ? AppColors.bgCard : AppColors.bgDeep;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: sheetBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Configuracion',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SettingsSection(
                        title: 'Apariencia',
                        children: [
                          Consumer<ThemeController>(
                            builder: (context, themeController, _) {
                              return _SettingsTile(
                                icon: themeController.isDarkMode
                                    ? Icons.dark_mode_rounded
                                    : Icons.light_mode_rounded,
                                iconColor: themeController.isDarkMode
                                    ? AppColors.purple
                                    : AppColors.warning,
                                iconBackground: themeController.isDarkMode
                                    ? AppColors.purpleDim
                                    : AppColors.warningDim,
                                title: 'Tema de la aplicacion',
                                subtitle: themeController.isDarkMode
                                    ? 'Modo noche'
                                    : 'Modo dia',
                                trailing: _ThemeToggle(
                                  isDarkMode: themeController.isDarkMode,
                                  onChanged: themeController.setDarkMode,
                                ),
                              );
                            },
                          ),
                          Divider(height: 1, color: AppColors.borderSubtle),
                        Consumer<AppSettingsController>(
                          builder: (context, settingsController, _) {
                            final settings = settingsController.settings;
                            return _SettingsSwitchTile(
                                icon: Icons.waving_hand_outlined,
                                title: 'Mostrar saludo del panel',
                                subtitle: settings.showDashboardGreeting
                                    ? 'El saludo inicial esta visible'
                                    : 'El saludo inicial esta oculto',
                                value: settings.showDashboardGreeting,
                                onChanged: (value) {
                                  settingsController.save(
                                    settings.copyWith(
                                      showDashboardGreeting: value,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SettingsSection(
                      title: 'Alineacion',
                      children: [
                        Consumer<AppSettingsController>(
                          builder: (context, settingsController, _) {
                            final settings = settingsController.settings;
                            return _SettingsActionTile(
                              icon: Icons.account_tree_outlined,
                              title: 'Formacion predeterminada',
                              subtitle: settings.defaultFormation,
                              onTap: () => _selectDefaultFormation(
                                context,
                                settingsController,
                              ),
                            );
                          },
                        ),
                        Divider(height: 1, color: AppColors.borderSubtle),
                        Consumer<AppSettingsController>(
                          builder: (context, settingsController, _) {
                            final settings = settingsController.settings;
                            return _SettingsSwitchTile(
                              icon: Icons.history_rounded,
                              title: 'Recordar ultima formacion',
                              subtitle: settings.rememberLastFormation
                                  ? 'Usa la ultima formacion guardada'
                                  : 'Mantiene la formacion predeterminada',
                              value: settings.rememberLastFormation,
                              onChanged: (value) {
                                settingsController.save(
                                  settings.copyWith(
                                    rememberLastFormation: value,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SettingsSection(
                      title: 'Partido en vivo',
                      children: [
                        Consumer<AppSettingsController>(
                          builder: (context, settingsController, _) {
                            final settings = settingsController.settings;
                            final count = settings.radialMenuActions.length;
                            return _SettingsActionTile(
                              icon: Icons.adjust_rounded,
                              title: 'Menu radial',
                              subtitle: '$count acciones rapidas visibles',
                              onTap: () => _selectRadialMenuActions(
                                context,
                                settingsController,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SettingsSection(
                      title: 'Cuenta y datos',
                      children: [
                        _SettingsActionTile(
                          icon: Icons.logout_rounded,
                          title: 'Cerrar sesion',
                          subtitle: 'Salir de la cuenta actual',
                          iconColor: AppColors.danger,
                          iconBackground: AppColors.dangerDim,
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await _logout(context);
                          },
                        ),
                        Divider(height: 1, color: AppColors.borderSubtle),
                        Consumer2<AppSettingsController, ThemeController>(
                          builder: (
                            context,
                            settingsController,
                            themeController,
                            _,
                          ) {
                            return _SettingsActionTile(
                              icon: Icons.restart_alt_rounded,
                              title: 'Restablecer configuraciones',
                              subtitle: 'Vuelve a los valores originales',
                              onTap: () async {
                                await settingsController.resetToDefaults();
                                await themeController.resetToDefaults();
                                if (!sheetContext.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Configuraciones restablecidas',
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _selectDefaultFormation(
  BuildContext context,
  AppSettingsController settingsController,
) async {
  final current = settingsController.settings.defaultFormation;
  final sheetBackground =
      AppColors.isDarkMode ? AppColors.bgCard : AppColors.bgDeep;
  final selected = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: sheetBackground,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Formacion predeterminada',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...AppSettingsController.availableFormations.map(
                (formation) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    formation,
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: current == formation
                      ? const Icon(Icons.check_rounded, color: AppColors.accent)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop(formation);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (selected == null) return;
  await settingsController.save(
    settingsController.settings.copyWith(defaultFormation: selected),
  );
}

Future<void> _selectRadialMenuActions(
  BuildContext context,
  AppSettingsController settingsController,
) async {
  final current = List<String>.from(
    settingsController.settings.radialMenuActions,
  );
  final sheetBackground =
      AppColors.isDarkMode ? AppColors.bgCard : AppColors.bgDeep;

  final selected = await showModalBottomSheet<List<String>>(
    context: context,
    backgroundColor: sheetBackground,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      var draft = List<String>.from(current);

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menu radial',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Elegi hasta ${AppConstants.radialSegments} acciones para tener a mano durante el partido.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppColors.borderSubtle),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: EventTypes.registrable.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.borderSubtle),
                      itemBuilder: (context, index) {
                        final action = EventTypes.registrable[index];
                        final isSelected = draft.contains(action);
                        final canAdd =
                            isSelected || draft.length < AppConstants.radialSegments;
                        final canRemove = !isSelected || draft.length > 1;

                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: AppColors.accent,
                          checkColor: Colors.black,
                          enabled: canAdd && canRemove,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          title: Text(
                            action,
                            style: TextStyle(
                              color: canAdd && canRemove
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: !canAdd && !isSelected
                              ? Text(
                                  'Maximo ${AppConstants.radialSegments} acciones',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                          onChanged: (_) {
                            setSheetState(() {
                              if (isSelected) {
                                if (draft.length > 1) draft.remove(action);
                              } else if (draft.length <
                                  AppConstants.radialSegments) {
                                draft.add(action);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              draft = List<String>.from(EventTypes.radialPrimary);
                            });
                          },
                          child: const Text('Restablecer'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(draft);
                          },
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (selected == null) return;
  await settingsController.save(
    settingsController.settings.copyWith(radialMenuActions: selected),
  );
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final sectionTitleColor =
        AppColors.isDarkMode ? AppColors.textSecondary : AppColors.textPrimary;
    final sectionBackground =
        AppColors.isDarkMode ? AppColors.bgSurface : AppColors.bgCard;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: sectionTitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: sectionBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSubtle, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _SettingsIcon(
            icon: icon,
            color: iconColor,
            backgroundColor: iconBackground,
          ),
          const SizedBox(width: 12),
          Expanded(child: _SettingsText(title: title, subtitle: subtitle)),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? iconBackground;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.iconBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _SettingsIcon(
              icon: icon,
              color: iconColor ?? AppColors.textSecondary,
              backgroundColor: iconBackground ?? AppColors.bgMuted,
            ),
            const SizedBox(width: 12),
            Expanded(child: _SettingsText(title: title, subtitle: subtitle)),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: icon,
      iconColor: value ? AppColors.accent : AppColors.textSecondary,
      iconBackground: value ? AppColors.accentDim : AppColors.bgMuted,
      title: title,
      subtitle: subtitle,
      trailing: Switch(
        value: value,
        activeThumbColor: AppColors.accent,
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _SettingsIcon({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _SettingsText extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SettingsText({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onChanged;

  const _ThemeToggle({
    required this.isDarkMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: isDarkMode,
      label: isDarkMode ? 'Activar modo día' : 'Activar modo noche',
      child: InkWell(
        onTap: () {
          onChanged(!isDarkMode);
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: 68,
          height: 36,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color:
                isDarkMode ? const Color(0xFF2F3157) : const Color(0xFFFFE7A3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? AppColors.purple.withValues(alpha: 0.45)
                  : AppColors.warning.withValues(alpha: 0.55),
            ),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment:
                isDarkMode ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF17182E)
                    : const Color(0xFFFFFFFF),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                size: 17,
                color: isDarkMode ? AppColors.purple : AppColors.warning,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _logout(BuildContext context) async {
  final authState = context.read<AuthState>();
  final router = GoRouter.of(context);
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text(
          'Cerrar sesion',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '¿Seguro que queres salir de la sesion?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesion'),
          ),
        ],
      );
    },
  );

  if (shouldLogout != true) return;

  await authState.logout();
  router.go(AppConstants.routeLogin);
}

void _showProfileSheet(BuildContext context) {
  final auth = context.read<AuthState>();
  final user = auth.user;
  final fullName =
      user == null ? 'Usuario' : '${user.nombre} ${user.apellido}'.trim();
  final initials = _initials(user?.nombre, user?.apellido);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bgCard,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Perfil',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.purpleDim,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName.isEmpty ? 'Usuario' : fullName,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user?.email ?? 'Sesión activa',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentDim,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                user?.rol ?? 'Usuario',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle, width: 0.5),
                ),
                child: Column(
                  children: [
                    _ProfileInfoRow(
                      icon: Icons.person_outline,
                      label: 'Usuario',
                      value: user?.nombreUsuario ?? '-',
                    ),
                    Divider(height: 1, color: AppColors.borderSubtle),
                    _ProfileInfoRow(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Rol',
                      value: user?.rol ?? 'Usuario',
                    ),
                    Divider(height: 1, color: AppColors.borderSubtle),
                    const _ProfileInfoRow(
                      icon: Icons.verified_user_outlined,
                      label: 'Estado',
                      value: 'Sesión activa',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _logout(context);
                },
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _initials(String? nombre, String? apellido) {
  final first = nombre != null && nombre.isNotEmpty ? nombre[0] : '';
  final last = apellido != null && apellido.isNotEmpty ? apellido[0] : '';
  final value = '$first$last'.toUpperCase();
  return value.isEmpty ? 'US' : value;
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Center(
                child: Icon(icon, size: 17, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 82,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppSidebar extends StatelessWidget {
  const _AppSidebar();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Container(
      width: AppConstants.sidebarWidth,
      color: AppColors.bgSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SidebarLogo(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _SidebarSection(label: 'Principal', items: [
                  _SidebarItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Dashboard',
                    route: AppConstants.routeDashboard,
                    current: location,
                  ),
                  _SidebarItem(
                    icon: Icons.sports_soccer,
                    label: 'Partidos',
                    route: AppConstants.routeMatches,
                    current: location,
                  ),
                  _SidebarItem(
                    icon: Icons.fitness_center,
                    label: 'Entrenamientos',
                    route: AppConstants.routeTraining,
                    current: location,
                  ),
                ]),
                _SidebarSection(label: 'Análisis', items: [
                  _SidebarItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Estadísticas',
                    route: AppConstants.routeStatistics,
                    current: location,
                  ),
                  _SidebarItem(
                    icon: Icons.description_outlined,
                    label: 'Reportes',
                    route: AppConstants.routeReports,
                    current: location,
                  ),
                  _SidebarItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Observaciones',
                    route: AppConstants.routeObservations,
                    current: location,
                  ),
                ]),
                _SidebarSection(label: 'Plantilla', items: [
                  _SidebarItem(
                    icon: Icons.people_outline,
                    label: 'Jugadores',
                    route: AppConstants.routePlayers,
                    current: location,
                  ),
                ]),
              ],
            ),
          ),
          const _SidebarUser(),
        ],
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.sports_soccer, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            'Kancha',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final String label;
  final List<_SidebarItem> items;

  const _SidebarSection({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String current;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.current,
  });

  bool get _active =>
      current == route || (route != '/' && current.startsWith(route));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: _active ? AppColors.accentDim : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.go(route);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: _active ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: _active ? AppColors.accent : AppColors.textSecondary,
                    fontWeight: _active ? FontWeight.w500 : FontWeight.w400,
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

class _SidebarUser extends StatelessWidget {
  const _SidebarUser();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final initials = _initials(user?.nombre, user?.apellido);
    final fullName =
        user == null ? 'Usuario' : '${user.nombre} ${user.apellido}'.trim();
    final role = user?.rol ?? 'Usuario';

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _showProfileSheet(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.purpleDim,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.purple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.isEmpty ? 'Usuario' : fullName,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              role,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Configuración',
            onPressed: () {
              _showSettingsPanel(context);
            },
            icon: const Icon(Icons.settings_outlined),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _AppBottomNav extends StatelessWidget {
  const _AppBottomNav();

  static const _items = [
    (icon: Icons.dashboard_outlined, label: 'Inicio', route: '/'),
    (icon: Icons.sports_soccer, label: 'Partidos', route: '/matches'),
    (icon: Icons.people_outline, label: 'Plantilla', route: '/players'),
    (icon: Icons.bar_chart_outlined, label: 'Stats', route: '/statistics'),
    (icon: Icons.description_outlined, label: 'Reportes', route: '/reports'),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    int current = 0;
    for (var i = 0; i < _items.length; i++) {
      final route = _items[i].route;
      if (route == '/' ? location == route : location.startsWith(route)) {
        current = i;
        break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = i == current;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    context.go(item.route);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: active ? AppColors.accent : AppColors.textMuted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              active ? AppColors.accent : AppColors.textMuted,
                          fontWeight:
                              active ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

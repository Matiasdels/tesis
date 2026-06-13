import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
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
            const VerticalDivider(width: 0.5, color: AppColors.borderSubtle),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kancha'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: const _AppBottomNav(),
    );
  }
}

Future<void> _logout(BuildContext context) async {
  await context.read<AuthState>().logout();
  if (context.mounted) {
    context.go(AppConstants.routeLogin);
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
      decoration: const BoxDecoration(
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
            child: const Icon(Icons.bolt, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
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
            style: const TextStyle(
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
          onTap: () => context.go(route),
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
    final initials = user == null
        ? 'US'
        : '${user.nombre.isNotEmpty ? user.nombre[0] : ''}'
                '${user.apellido.isNotEmpty ? user.apellido[0] : ''}'
            .toUpperCase();
    final fullName =
        user == null ? 'Usuario' : '${user.nombre} ${user.apellido}'.trim();
    final role = user?.rol ?? 'Usuario';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.purpleDim,
            child: Text(
              initials.isEmpty ? 'US' : initials,
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
                  fullName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: () => _logout(context),
            icon: const Icon(
              Icons.logout,
              size: 16,
              color: AppColors.textMuted,
            ),
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
    (icon: Icons.more_horiz, label: 'Más', route: '/reports'),
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
      decoration: const BoxDecoration(
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
                  onTap: () => context.go(item.route),
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

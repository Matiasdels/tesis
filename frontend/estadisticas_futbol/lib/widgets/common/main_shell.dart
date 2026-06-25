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
      appBar: const _MobileBrandAppBar(),
      body: child,
      bottomNavigationBar: const _AppBottomNav(),
    );
  }
}

class _MobileBrandAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _MobileBrandAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final initials = _initials(user?.nombre, user?.apellido);

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: preferredSize.height,
      backgroundColor: AppColors.bgSurface,
      elevation: 0,
      titleSpacing: 14,
      title: InkWell(
        onTap: () => context.go(AppConstants.routeDashboard),
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              _KanchaLogoMark(size: 40),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kancha',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Gestion deportiva',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: () => _showProfileSheet(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.bgMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderDefault, width: 0.7),
              ),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
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
    );
  }
}

class _KanchaLogoMark extends StatelessWidget {
  final double size;

  const _KanchaLogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF23A83E),
                      AppColors.pitchGreenAlt,
                      AppColors.pitchGreen,
                    ],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: CustomPaint(painter: _TurfLogoBackgroundPainter()),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size * 0.11,
              child: Container(
                width: size * 0.54,
                height: size * 0.13,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Container(
              width: size * 0.68,
              height: size * 0.68,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.sports_soccer,
                color: Colors.black,
                size: size * 0.58,
              ),
            ),
            Positioned(
              right: size * 0.07,
              top: size * 0.07,
              child: Container(
                width: size * 0.18,
                height: size * 0.18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'K',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: size * 0.13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurfLogoBackgroundPainter extends CustomPainter {
  const _TurfLogoBackgroundPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round;

    for (var x = -size.width; x < size.width * 2; x += size.width * 0.28) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.width * 0.75, 0),
        stripePaint,
      );
    }

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.34, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Future<void> _logout(BuildContext context) async {
  await context.read<AuthState>().logout();
  if (context.mounted) {
    context.go(AppConstants.routeLogin);
  }
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
              const Text(
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
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user?.email ?? 'Sesión activa',
                            style: const TextStyle(
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
                    const Divider(height: 1, color: AppColors.borderSubtle),
                    _ProfileInfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Rol',
                      value: user?.rol ?? 'Usuario',
                    ),
                    const Divider(height: 1, color: AppColors.borderSubtle),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
            child:
                const Icon(Icons.sports_soccer, color: Colors.black, size: 18),
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
    final initials = _initials(user?.nombre, user?.apellido);
    final fullName =
        user == null ? 'Usuario' : '${user.nombre} ${user.apellido}'.trim();
    final role = user?.rol ?? 'Usuario';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showProfileSheet(context),
        child: Container(
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
              const Icon(
                Icons.expand_less,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
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

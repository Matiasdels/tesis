import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:estadisticas_futbol/core/constants/app_constants.dart';
import 'package:estadisticas_futbol/screens/dashboard/dashboard_screen.dart';
import 'package:estadisticas_futbol/screens/players/players_screen.dart';
import 'package:estadisticas_futbol/screens/players/player_detail_screen.dart';
import 'package:estadisticas_futbol/screens/matches/matches_screen.dart';
import 'package:estadisticas_futbol/screens/live_match/live_match_screen.dart';
import 'package:estadisticas_futbol/screens/training/training_screen.dart';
import 'package:estadisticas_futbol/screens/statistics/statistics_screen.dart';
import 'package:estadisticas_futbol/screens/auth/login_screen.dart';
import 'package:estadisticas_futbol/data/remote/auth_state.dart';
import 'package:estadisticas_futbol/widgets/common/main_shell.dart';
import '../../screens/observations/observations_screen.dart';
import '../../screens/reports/reports_screen.dart';

GoRouter createRouter(AuthState authState) => GoRouter(
      initialLocation: AppConstants.routeLogin,
      debugLogDiagnostics: false,
      refreshListenable: authState,
      redirect: (context, state) {
        final isLogin = state.matchedLocation == AppConstants.routeLogin;

        if (!authState.initialized) {
          return isLogin ? null : AppConstants.routeLogin;
        }

        if (!authState.isAuthenticated) {
          return isLogin ? null : AppConstants.routeLogin;
        }

        if (isLogin) {
          return AppConstants.routeDashboard;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppConstants.routeLogin,
          pageBuilder: (c, s) => _fade(const LoginScreen()),
        ),
        // Shell route wraps all main tabs with bottom nav / sidebar
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: AppConstants.routeDashboard,
              pageBuilder: (c, s) => _fade(const DashboardScreen()),
            ),
            GoRoute(
              path: AppConstants.routePlayers,
              pageBuilder: (c, s) => _fade(const PlayersScreen()),
            ),
            GoRoute(
              path: AppConstants.routeMatches,
              pageBuilder: (c, s) => _fade(const MatchesScreen()),
            ),
            GoRoute(
              path: AppConstants.routeTraining,
              pageBuilder: (c, s) => _fade(const TrainingScreen()),
            ),
            GoRoute(
              path: AppConstants.routeStatistics,
              pageBuilder: (c, s) => _fade(const StatisticsScreen()),
            ),
            GoRoute(
              path: AppConstants.routeReports,
              pageBuilder: (c, s) => _fade(const ReportsScreen()),
            ),
            GoRoute(
              path: AppConstants.routeObservations,
              pageBuilder: (c, s) => _fade(const ObservationsScreen()),
            ),
          ],
        ),
        // Full-screen routes (outside shell)
        GoRoute(
          path: AppConstants.routePlayerDetail,
          pageBuilder: (c, s) {
            final id = s.pathParameters['id'] ?? '0';
            return _slide(PlayerDetailScreen(playerId: id));
          },
        ),
        GoRoute(
          path: AppConstants.routeLiveMatch,
          pageBuilder: (c, s) {
            final id = s.pathParameters['id'] ?? '0';
            return _slide(LiveMatchScreen(matchId: id));
          },
        ),
      ],
    );

CustomTransitionPage<void> _fade(Widget child) => CustomTransitionPage(
      child: child,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: AppConstants.animFast,
    );

CustomTransitionPage<void> _slide(Widget child) => CustomTransitionPage(
      child: child,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: AppConstants.animNormal,
    );

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:estadisticas_futbol/core/constants/app_constants.dart';
import 'package:estadisticas_futbol/screens/dashboard/dashboard_screen.dart';
import 'package:estadisticas_futbol/screens/players/players_screen.dart';
import 'package:estadisticas_futbol/screens/players/player_detail_screen.dart';
import 'package:estadisticas_futbol/screens/players/player_form_screen.dart';
import 'package:estadisticas_futbol/screens/matches/matches_screen.dart';
import 'package:estadisticas_futbol/screens/matches/match_form_screen.dart';
import 'package:estadisticas_futbol/screens/matches/match_detail_screen.dart';
import 'package:estadisticas_futbol/models/models.dart';
import 'package:estadisticas_futbol/screens/matches/lineup_screen.dart';
import 'package:estadisticas_futbol/screens/live_match/live_match_screen.dart';
import 'package:estadisticas_futbol/screens/live_match/penales_screen.dart';
import 'package:estadisticas_futbol/screens/matches/match_summary_screen.dart';
import 'package:estadisticas_futbol/screens/training/training_screen.dart';
import 'package:estadisticas_futbol/screens/statistics/statistics_screen.dart';
import 'package:estadisticas_futbol/screens/auth/login_screen.dart';
import 'package:estadisticas_futbol/screens/auth/splash_screen.dart';
import 'package:estadisticas_futbol/data/remote/auth_state.dart';
import 'package:estadisticas_futbol/widgets/common/main_shell.dart';
import '../../screens/observations/observations_screen.dart';
import '../../screens/reports/reports_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthState authState) => GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppConstants.routeSplash,
      debugLogDiagnostics: false,
      refreshListenable: authState,
      redirect: (context, state) {
        final isLogin = state.matchedLocation == AppConstants.routeLogin;
        final isSplash = state.matchedLocation == AppConstants.routeSplash;

        if (!authState.initialized) {
          return isSplash ? null : AppConstants.routeSplash;
        }

        if (!authState.isAuthenticated) {
          return isLogin ? null : AppConstants.routeLogin;
        }

        if (isLogin || isSplash) {
          return AppConstants.routeDashboard;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppConstants.routeSplash,
          pageBuilder: (c, s) => _fade(s, const SplashScreen()),
        ),
        GoRoute(
          path: AppConstants.routeLogin,
          pageBuilder: (c, s) => _fade(s, const LoginScreen()),
        ),
        // Shell route wraps all main tabs with bottom nav / sidebar
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: AppConstants.routeDashboard,
              pageBuilder: (c, s) => _fade(s, const DashboardScreen()),
            ),
            GoRoute(
              path: AppConstants.routePlayers,
              pageBuilder: (c, s) => _fade(s, const PlayersScreen()),
            ),
            GoRoute(
              path: AppConstants.routeMatches,
              pageBuilder: (c, s) => _fade(s, const MatchesScreen()),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (c, s) =>
                      _slide<bool>(s, const MatchFormScreen()),
                ),
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (c, s) {
                    final id = int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
                    final playerCtx = s.extra is PlayerMatchModel
                        ? s.extra as PlayerMatchModel
                        : null;
                    return _slide<bool>(
                        s, MatchDetailScreen(matchId: id, playerContext: playerCtx));
                  },
                  routes: [
                    GoRoute(
                      path: 'summary',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (c, s) {
                        final id =
                            int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
                        return _slide(s, MatchSummaryScreen(matchId: id));
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: AppConstants.routeTraining,
              pageBuilder: (c, s) => _fade(s, const TrainingScreen()),
            ),
            GoRoute(
              path: AppConstants.routeStatistics,
              pageBuilder: (c, s) => _fade(s, const StatisticsScreen()),
            ),
            GoRoute(
              path: AppConstants.routeReports,
              pageBuilder: (c, s) => _fade(s, const ReportsScreen()),
            ),
            GoRoute(
              path: AppConstants.routeObservations,
              pageBuilder: (c, s) => _fade(s, const ObservationsScreen()),
            ),
          ],
        ),
        // Full-screen routes (outside shell)
        GoRoute(
          path: '/matches/:id/edit',
          pageBuilder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
            return _slide<bool>(s, MatchFormScreen(matchId: id));
          },
        ),
        GoRoute(
          path: '/matches/:id/lineup',
          pageBuilder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
            return _slide<bool>(s, LineupScreen(matchId: id));
          },
        ),
        GoRoute(
          path: AppConstants.routePlayerCreate,
          pageBuilder: (c, s) => _slide<bool>(s, const PlayerFormScreen()),
        ),
        GoRoute(
          path: AppConstants.routePlayerDetail,
          pageBuilder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
            return _slide<bool>(s, PlayerDetailScreen(playerId: id));
          },
        ),
        GoRoute(
          path: AppConstants.routePlayerEdit,
          pageBuilder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
            return _slide<bool>(s, PlayerFormScreen(playerId: id));
          },
        ),
        GoRoute(
          path: AppConstants.routeLiveMatch,
          pageBuilder: (c, s) {
            final id = s.pathParameters['id'] ?? '0';
            return _slide(s, LiveMatchScreen(matchId: id));
          },
        ),
        GoRoute(
          path: '/matches/:id/penales',
          pageBuilder: (c, s) {
            final id = int.tryParse(s.pathParameters['id'] ?? '0') ?? 0;
            return _slide(s, PenalesScreen(matchId: id));
          },
        ),
      ],
    );

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: AppConstants.animFast,
    );

CustomTransitionPage<T> _slide<T>(GoRouterState state, Widget child) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      transitionDuration: AppConstants.animNormal,
    );

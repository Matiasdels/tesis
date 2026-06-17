import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/match_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _api = MatchApi();

  List<PartidoModel> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthState>().session!.accessToken;
      final matches = await _api.getMatches(accessToken: token);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los partidos. Intente nuevamente.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Partidos',
      subtitle: 'Gestión de partidos',
      actions: [
        ElevatedButton.icon(
          onPressed: () async {
            final created =
                await context.push<bool>(AppConstants.routeMatchCreate);
            if (created == true) _load();
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Nuevo'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? EmptyState(
                    icon: Icons.error_outline,
                    title: 'Error al cargar',
                    subtitle: _error!,
                    actionLabel: 'Reintentar',
                    onAction: _load,
                  )
                : _matches.isEmpty
                    ? EmptyState(
                        icon: Icons.sports_soccer_outlined,
                        title: 'Sin partidos registrados',
                        subtitle:
                            'Todavía no hay partidos. Creá el primero con el botón "Nuevo".',
                        actionLabel: 'Nuevo partido',
                        onAction: () async {
                          final created = await context
                              .push<bool>(AppConstants.routeMatchCreate);
                          if (created == true) _load();
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppConstants.pagePadding),
                        itemCount: _matches.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) => _MatchTile(
                          match: _matches[i],
                          onTap: () async {
                            final changed = await context.push<bool>(
                              '/matches/${_matches[i].id}',
                            );
                            if (changed == true) _load();
                          },
                        ),
                      ),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final PartidoModel match;
  final VoidCallback onTap;

  const _MatchTile({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Row(
          children: [
            _EstadoIndicator(estado: match.estado),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.rival,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _EstadoBadge(estado: match.estado),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(match.fecha)}  ·  ${match.tipoCompeticion}  ·  ${match.esLocal ? 'Local' : 'Visitante'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (match.categoriaNombre != null)
                    Text(
                      match.categoriaNombre!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day/$month/${d.year} $hour:$min';
  }
}

class _EstadoIndicator extends StatelessWidget {
  final String estado;
  const _EstadoIndicator({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'EnJuego' => AppColors.accent,
      'Finalizado' => AppColors.textMuted,
      'Cancelado' => AppColors.danger,
      _ => AppColors.info,
    };
    return Container(
      width: 4,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (estado) {
      'EnJuego' => (AppColors.accent, AppColors.accentDim),
      'Finalizado' => (AppColors.textMuted, AppColors.bgSurface),
      'Cancelado' => (AppColors.danger, AppColors.dangerDim),
      _ => (AppColors.info, AppColors.infoDim),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

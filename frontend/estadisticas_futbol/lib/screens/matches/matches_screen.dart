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
  int? _filterYear;

  List<int> get _availableYears {
    final years = _matches.map((m) => m.fecha.year).toSet().toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<PartidoModel> get _filteredMatches => _filterYear == null
      ? _matches
      : _matches.where((m) => m.fecha.year == _filterYear).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<bool> _confirmDelete(PartidoModel match) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: Text(
          'Eliminar partido',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '¿Estás seguro de que querés eliminar este partido? '
          'Esta acción ocultará el partido del listado.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return false;

    try {
      final token = context.read<AuthState>().session!.accessToken;
      await _api.deleteMatch(match.id, token);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos eliminar el partido.')),
        );
      }
      return false;
    }
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
      matches.sort((a, b) {
        int estadoPriority(PartidoModel m) =>
            m.isEnJuego ? 0 : (m.isProgramado ? 1 : 2);
        final ep = estadoPriority(a).compareTo(estadoPriority(b));
        if (ep != 0) return ep;
        final fd = b.fecha.compareTo(a.fecha);
        if (fd != 0) return fd;
        return b.id.compareTo(a.id);
      });
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_availableYears.isNotEmpty)
                  _YearFilterBar(
                    years: _availableYears,
                    selected: _filterYear,
                    onSelect: (y) => setState(() => _filterYear = y),
                  ),
                Expanded(
                  child: _error != null
                      ? EmptyState(
                          icon: Icons.error_outline,
                          title: 'Error al cargar',
                          subtitle: _error!,
                          actionLabel: 'Reintentar',
                          onAction: _load,
                        )
                      : _filteredMatches.isEmpty
                          ? EmptyState(
                              icon: Icons.sports_soccer_outlined,
                              title: _filterYear != null
                                  ? 'Sin partidos en $_filterYear'
                                  : 'Sin partidos registrados',
                              subtitle: _filterYear != null
                                  ? 'No hay partidos registrados para este año.'
                                  : 'Todavía no hay partidos. Creá el primero con el botón "Nuevo".',
                              actionLabel:
                                  _filterYear != null ? null : 'Nuevo partido',
                              onAction: _filterYear != null
                                  ? null
                                  : () async {
                                      final created = await context.push<bool>(
                                          AppConstants.routeMatchCreate);
                                      if (created == true) _load();
                                    },
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(
                                    AppConstants.pagePadding),
                                itemCount: _filteredMatches.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final match = _filteredMatches[i];
                                  return Dismissible(
                                    key: ValueKey(match.id),
                                    direction: DismissDirection.endToStart,
                                    background: const _SwipeDeleteBackground(),
                                    confirmDismiss: (_) =>
                                        _confirmDelete(match),
                                    onDismissed: (_) {
                                      setState(() => _matches.removeWhere(
                                          (m) => m.id == match.id));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Partido eliminado.'),
                                        ),
                                      );
                                    },
                                    child: _MatchTile(
                                      match: match,
                                      onTap: () async {
                                        final changed =
                                            await context.push<bool>(
                                          '/matches/${match.id}',
                                        );
                                        if (changed == true) _load();
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
    );
  }
}

class _YearFilterBar extends StatelessWidget {
  final List<int> years;
  final int? selected;
  final ValueChanged<int?> onSelect;

  const _YearFilterBar({
    required this.years,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgSurface,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _YearChip(
              label: 'Todos',
              active: selected == null,
              onTap: () => onSelect(null),
            ),
            ...years.map((y) => _YearChip(
                  label: '$y',
                  active: selected == y,
                  onTap: () => onSelect(y),
                )),
          ],
        ),
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _YearChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: active,
        onSelected: (_) => onTap(),
        backgroundColor: AppColors.bgMuted,
        selectedColor: AppColors.accentDim,
        checkmarkColor: AppColors.accent,
        side: BorderSide(
          color: active
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.borderDefault,
          width: 0.5,
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          color: active ? AppColors.accent : AppColors.textSecondary,
          fontWeight: active ? FontWeight.w500 : FontWeight.w400,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          style: TextStyle(
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
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  if (match.categoriaNombre != null)
                    Text(
                      match.categoriaNombre!,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
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

class _SwipeDeleteBackground extends StatelessWidget {
  const _SwipeDeleteBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 22),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delete_outline,
            color: AppColors.danger.withValues(alpha: 0.85),
            size: 20,
          ),
          const SizedBox(height: 3),
          Text(
            'Borrar',
            style: TextStyle(
              color: AppColors.danger.withValues(alpha: 0.75),
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
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

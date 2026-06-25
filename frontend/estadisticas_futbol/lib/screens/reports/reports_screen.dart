import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/event_api.dart';
import '../../data/remote/match_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';
import 'match_report_pdf_exporter.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _matchApi = MatchApi();
  final _eventApi = EventApi();

  List<PartidoModel> _matches = [];
  bool _loading = true;
  String? _error;
  int? _exportingMatchId;

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
      final matches = await _matchApi.getMatches(accessToken: token);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los reportes. Intente nuevamente.';
        _loading = false;
      });
    }
  }

  Future<void> _exportPdf(PartidoModel match) async {
    if (_exportingMatchId != null) return;

    setState(() => _exportingMatchId = match.id);
    try {
      final token = context.read<AuthState>().session!.accessToken;
      final events = await _eventApi.getEventos(match.id, token);
      await MatchReportPdfExporter.export(match: match, events: events);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar el PDF.')),
      );
    } finally {
      if (mounted) setState(() => _exportingMatchId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Reportes',
      subtitle: 'Resumen y exportacion de partidos',
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
                        icon: Icons.analytics_outlined,
                        title: 'Sin partidos para reportar',
                        subtitle:
                            'Cuando haya partidos registrados, sus reportes van a aparecer aca.',
                        actionLabel: 'Actualizar',
                        onAction: _load,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppConstants.pagePadding),
                        itemCount: _matches.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final match = _matches[index];
                          return _ReportMatchTile(
                            match: match,
                            exporting: _exportingMatchId == match.id,
                            onOpen: () =>
                                context.push('/matches/${match.id}/summary'),
                            onExport: () => _exportPdf(match),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ReportMatchTile extends StatelessWidget {
  final PartidoModel match;
  final bool exporting;
  final VoidCallback onOpen;
  final VoidCallback onExport;

  const _ReportMatchTile({
    required this.match,
    required this.exporting,
    required this.onOpen,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EstadoBadge(estado: match.estado),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDate(match.fecha)} - ${match.tipoCompeticion} - ${match.esLocal ? 'Local' : 'Visitante'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      match.categoriaNombre ?? 'Sin categoria',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Exportar PDF',
                onPressed: exporting ? null : onExport,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accentDim,
                  foregroundColor: AppColors.accent,
                  disabledBackgroundColor: AppColors.bgMuted,
                ),
                icon: exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 20),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$min';
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

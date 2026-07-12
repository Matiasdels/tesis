import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/event_api.dart';
import '../../data/remote/match_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';
import '../../widgets/match/pitch_view.dart';

class MatchSummaryScreen extends StatefulWidget {
  final int matchId;
  const MatchSummaryScreen({super.key, required this.matchId});

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  final _matchApi = MatchApi();
  final _eventApi = EventApi();

  PartidoModel? _match;
  List<EventoPartidoModel> _events = [];
  bool _loading = true;
  String? _error;
  bool _exportingPdf = false;
  bool _generatingAnalysis = false;
  AnalisisPartidoModel? _analysis;

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
      final results = await Future.wait([
        _matchApi.getMatch(widget.matchId, token),
        _eventApi.getEventos(widget.matchId, token),
      ]);
      if (!mounted) return;
      setState(() {
        _match = results[0] as PartidoModel;
        _events = results[1] as List<EventoPartidoModel>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar el resumen. Intente nuevamente.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _match == null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Algo salió mal',
                  subtitle: _error ?? 'Partido no encontrado',
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              : _buildContent(_match!),
    );
  }

  Widget _buildContent(PartidoModel match) {
    final golesOwn = match.golesEquipo ?? 0;
    final golesRival = match.golesRival ?? 0;

    final countByType = <String, int>{};
    for (final e in _events) {
      countByType[e.tipoEventoNombre] = (countByType[e.tipoEventoNombre] ?? 0) + 1;
    }

    final goals = _events.where((e) => e.tipoEventoNombre == EventTypes.goal).toList();
    final yellowCards = _events.where((e) => e.tipoEventoNombre == EventTypes.yellowCard).toList();
    final redCards = _events.where((e) => e.tipoEventoNombre == EventTypes.redCard).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.bgSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            color: AppColors.textPrimary,
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Resumen del partido',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => context.go(AppConstants.routeMatches),
              icon: const Icon(Icons.list_alt_rounded, size: 16, color: AppColors.accent),
              label: const Text(
                'Partidos',
                style: TextStyle(color: AppColors.accent, fontSize: 13),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ScoreBanner(match: match, golesOwn: golesOwn, golesRival: golesRival),
              const SizedBox(height: AppConstants.sectionSpacing),

              _InfoCard(match: match),
              const SizedBox(height: AppConstants.sectionSpacing),

              if (countByType.isNotEmpty) ...[
                _StatsCard(countByType: countByType),
                const SizedBox(height: AppConstants.sectionSpacing),
              ],

              if (goals.isNotEmpty || yellowCards.isNotEmpty || redCards.isNotEmpty) ...[
                _HighlightsCard(
                  goals: goals,
                  yellowCards: yellowCards,
                  redCards: redCards,
                ),
                const SizedBox(height: AppConstants.sectionSpacing),
              ],

              _HeatMapCard(events: _events),
              const SizedBox(height: AppConstants.sectionSpacing),

              _IntelligentAnalysisCard(
                analysis: _analysis,
                generating: _generatingAnalysis,
                onGenerate: _generateAnalysis,
              ),
              const SizedBox(height: AppConstants.sectionSpacing),

              _EventsCard(events: _events),
              const SizedBox(height: AppConstants.sectionSpacing),

              _InfoBanner(),
              const SizedBox(height: AppConstants.sectionSpacing),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _exportingPdf
                      ? null
                      : () => _exportPdf(match, countByType, goals, yellowCards, redCards),
                  icon: _exportingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 20),
                  label: const Text('Exportar PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _exportPdf(
    PartidoModel match,
    Map<String, int> countByType,
    List<EventoPartidoModel> goals,
    List<EventoPartidoModel> yellowCards,
    List<EventoPartidoModel> redCards,
  ) async {
    setState(() => _exportingPdf = true);
    try {
      final doc = pw.Document();
      final golesOwn = match.golesEquipo ?? 0;
      final golesRival = match.golesRival ?? 0;
      const teamName = 'Kancha';

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => [
            pw.Text('Kancha — Resumen del partido',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text(
              match.esLocal
                  ? '$teamName $golesOwn – $golesRival ${match.rival}'
                  : '${match.rival} $golesRival – $golesOwn $teamName',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Fecha: ${_formatDate(match.fecha)}'),
            pw.Text('Tipo: ${match.tipoCompeticion}'),
            if (match.categoriaNombre != null) pw.Text('Categoría: ${match.categoriaNombre}'),
            if (match.lugar != null && match.lugar!.isNotEmpty) pw.Text('Lugar: ${match.lugar}'),
            pw.Text('Condición: ${match.esLocal ? "Local" : "Visitante"}'),
            pw.SizedBox(height: 16),

            if (countByType.isNotEmpty) ...[
              pw.Text('Estadísticas',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Evento',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Cantidad',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...countByType.entries.map(
                    (e) => pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6), child: pw.Text(e.key)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${e.value}')),
                    ]),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            if (goals.isNotEmpty) ...[
              pw.Text('Goles',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              ...goals.map((e) => pw.Text(
                  '  ${e.minuto}\' — ${e.nombreJugador ?? "Sin jugador"}')),
              pw.SizedBox(height: 12),
            ],

            if (yellowCards.isNotEmpty || redCards.isNotEmpty) ...[
              pw.Text('Tarjetas',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              ...yellowCards.map((e) => pw.Text(
                  '  Amarilla — ${e.minuto}\' — ${e.nombreJugador ?? "Sin jugador"}')),
              ...redCards.map((e) => pw.Text(
                  '  Roja — ${e.minuto}\' — ${e.nombreJugador ?? "Sin jugador"}')),
              pw.SizedBox(height: 12),
            ],

            pw.Text('Todos los eventos',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            if (_events.isEmpty)
              pw.Text('No se registraron eventos.')
            else
              ..._events.map((e) => pw.Text(
                  '  ${e.minuto}\' — ${e.tipoEventoNombre}'
                  '${e.nombreJugador != null ? " — ${e.nombreJugador}" : ""}')),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await doc.save(),
        filename:
            'partido_vs_${match.rival.replaceAll(' ', '_')}_${_formatDateFile(match.fecha)}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo generar el PDF.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatDateFile(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  Future<void> _generateAnalysis() async {
    if (_generatingAnalysis) return;

    setState(() => _generatingAnalysis = true);
    try {
      final token = context.read<AuthState>().session!.accessToken;
      final result =
          await _matchApi.generateIntelligentAnalysis(widget.matchId, token);

      if (!mounted) return;
      setState(() {
        _analysis = result;
        _generatingAnalysis = false;
      });

      final message = result.generadoConIa
          ? 'Análisis generado correctamente.'
          : result.mensaje ??
              'Esta función necesita conexión a internet para generar el análisis.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is MatchApiException
          ? error.message
          : 'No se pudo conectar con el servidor. Verifica que este iniciado e intenta nuevamente.';
      setState(() {
        _analysis = AnalisisPartidoModel(
          resumenGeneral: '',
          puntosPositivos: const [],
          aspectosAMejorar: const [],
          sugerenciasEntrenamiento: const [],
          analisisZonas: '',
          generadoConIa: false,
          mensaje: message,
        );
        _generatingAnalysis = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

// ── Score banner ──────────────────────────────────────────────────────────────

class _ScoreBanner extends StatelessWidget {
  final PartidoModel match;
  final int golesOwn, golesRival;
  const _ScoreBanner({required this.match, required this.golesOwn, required this.golesRival});

  @override
  Widget build(BuildContext context) {
    const ownName = 'Kancha';
    final rivalName = match.rival;

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TeamBadge(name: match.esLocal ? ownName : rivalName),
              Text(
                match.esLocal
                    ? '$golesOwn  —  $golesRival'
                    : '$golesRival  —  $golesOwn',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              _TeamBadge(name: match.esLocal ? rivalName : ownName),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              match.isFinished ? 'Partido finalizado' : match.estado,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final String name;
  const _TeamBadge({required this.name});

  @override
  Widget build(BuildContext context) {
    final abbr = name.length >= 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase();
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.bgMuted,
          child: Text(abbr,
              style: TextStyle(
                  fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(name,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final PartidoModel match;
  const _InfoCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Información general'),
          const SizedBox(height: 10),
          _Row('Rival', match.rival),
          _Row('Fecha', _fmt(match.fecha)),
          _Row('Tipo', match.tipoCompeticion),
          _Row('Condición', match.esLocal ? 'Local' : 'Visitante'),
          if (match.categoriaNombre != null) _Row('Categoría', match.categoriaNombre!),
          if (match.lugar != null && match.lugar!.isNotEmpty) _Row('Lugar', match.lugar!),
          if (match.minutoActual != null) _Row('Minutos jugados', '${match.minutoActual}\''),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Stats card ────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final Map<String, int> countByType;
  const _StatsCard({required this.countByType});

  @override
  Widget build(BuildContext context) {
    final sorted = countByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Estadísticas'),
          const SizedBox(height: 12),
          ...sorted.map((e) => _StatRow(label: e.key, count: e.value, total: _events(countByType))),
        ],
      ),
    );
  }

  int _events(Map<String, int> map) => map.values.fold(0, (a, b) => a + b);
}

class _StatRow extends StatelessWidget {
  final String label;
  final int count, total;
  const _StatRow({required this.label, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              Text('$count',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.bgMuted,
              color: AppColors.accent,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Highlights card ───────────────────────────────────────────────────────────

class _HighlightsCard extends StatelessWidget {
  final List<EventoPartidoModel> goals, yellowCards, redCards;
  const _HighlightsCard(
      {required this.goals, required this.yellowCards, required this.redCards});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Destacados'),
          const SizedBox(height: 10),
          if (goals.isNotEmpty) ...[
            _HighlightSection(
              label: 'Goles',
              icon: Icons.emoji_events_rounded,
              color: const Color(0xFFFFEB3B),
              events: goals,
            ),
            const SizedBox(height: 10),
          ],
          if (yellowCards.isNotEmpty) ...[
            _HighlightSection(
              label: 'Tarjetas amarillas',
              icon: Icons.square_rounded,
              color: AppColors.warning,
              events: yellowCards,
            ),
            const SizedBox(height: 10),
          ],
          if (redCards.isNotEmpty)
            _HighlightSection(
              label: 'Tarjetas rojas',
              icon: Icons.square_rounded,
              color: AppColors.danger,
              events: redCards,
            ),
        ],
      ),
    );
  }
}

class _HighlightSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<EventoPartidoModel> events;
  const _HighlightSection(
      {required this.label, required this.icon, required this.color, required this.events});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ...events.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 20),
              child: Row(
                children: [
                  Text("${e.minuto}'",
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Text(e.nombreJugador ?? 'Sin jugador',
                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                ],
              ),
            )),
      ],
    );
  }
}

// ── Events list card ──────────────────────────────────────────────────────────

class _EventsCard extends StatelessWidget {
  final List<EventoPartidoModel> events;
  const _EventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Todos los eventos'),
          const SizedBox(height: 10),
          if (events.isEmpty)
            Text('No se registraron eventos en este partido.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
          else
            ...events.map((e) => _EventRow(event: e)),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final EventoPartidoModel event;
  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text("${event.minuto}'",
                style: TextStyle(
                    fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ),
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: _color(event.tipoEventoNombre),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(event.tipoEventoNombre,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Text(event.nombreJugador ?? 'Sin jugador',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Color _color(String type) => switch (type) {
        'Gol' => const Color(0xFFFFEB3B),
        'Remate' => AppColors.warning,
        'Falta' => AppColors.danger,
        'Tarjeta amarilla' => AppColors.warning,
        'Tarjeta roja' => AppColors.danger,
        'Recuperación' => AppColors.info,
        'Intercepción' => AppColors.info,
        'Atajada' => AppColors.purple,
        'Pase correcto' || 'Pase clave' => AppColors.accent,
        _ => AppColors.textMuted,
      };
}

// ── Info banner ───────────────────────────────────────────────────────────────

class _HeatMapCard extends StatefulWidget {
  static const int minEvents = 3;

  final List<EventoPartidoModel> events;

  const _HeatMapCard({required this.events});

  @override
  State<_HeatMapCard> createState() => _HeatMapCardState();
}

class _HeatMapCardState extends State<_HeatMapCard> {
  static const _allFilter = 'Todos';
  String _selectedFilter = _allFilter;

  List<EventoPartidoModel> _eventsForFilter(
    List<EventoPartidoModel> events,
    String filter,
  ) {
    return switch (filter) {
      'Pases' => events
          .where((event) =>
              event.tipoEventoNombre == EventTypes.passOk ||
              event.tipoEventoNombre == EventTypes.passKey ||
              event.tipoEventoNombre == EventTypes.passBad)
          .toList(),
      'Remates' => events
          .where((event) => event.tipoEventoNombre == EventTypes.shot)
          .toList(),
      'Recuperaciones' => events
          .where((event) =>
              event.tipoEventoNombre == EventTypes.recovery ||
              event.tipoEventoNombre == EventTypes.interception)
          .toList(),
      'Faltas' => events
          .where((event) => event.tipoEventoNombre == EventTypes.foul)
          .toList(),
      'Goles' => events
          .where((event) =>
              event.tipoEventoNombre == EventTypes.goal ||
              event.tipoEventoNombre == EventTypes.goalRival)
          .toList(),
      _ => events,
    };
  }

  @override
  Widget build(BuildContext context) {
    final locatedEvents = widget.events
        .where((event) =>
            event.pitchX >= 0 &&
            event.pitchX <= 1 &&
            event.pitchY >= 0 &&
            event.pitchY <= 1)
        .toList();
    final filteredEvents = _eventsForFilter(locatedEvents, _selectedFilter);
    final enoughData = filteredEvents.length >= _HeatMapCard.minEvents;
    final selectedLabel =
        _selectedFilter == _allFilter ? 'el partido' : _selectedFilter;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Mapa de calor'),
          const SizedBox(height: 6),
          Text(
            'Acciones con ubicacion en $selectedLabel: ${filteredEvents.length}',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 3),
          Text(
            'Minimo necesario: ${_HeatMapCard.minEvents} acciones',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          _HeatMapFilters(
            selected: _selectedFilter,
            onSelected: (filter) => setState(() => _selectedFilter = filter),
          ),
          const SizedBox(height: 12),
          if (!enoughData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgMuted,
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                border: Border.all(
                  color: AppColors.borderSubtle,
                  width: 0.5,
                ),
              ),
              child: Text(
                'Todavia no hay datos suficientes para el mapa de calor. '
                'Registra al menos ${_HeatMapCard.minEvents} acciones con ubicacion en este filtro para visualizarlo.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = width * 1.34;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                  child: MatchPitchView(
                    events: filteredEvents,
                    width: width,
                    height: height,
                    showEventDots: false,
                    showHeatMap: true,
                  ),
                );
              },
            ),
          if (enoughData) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                _HeatLegendItem(color: Color(0xFF16A34A), label: 'Baja'),
                SizedBox(width: 8),
                _HeatLegendItem(color: Color(0xFFFFEB3B), label: 'Media'),
                SizedBox(width: 8),
                _HeatLegendItem(color: Color(0xFFF97316), label: 'Alta'),
                SizedBox(width: 8),
                _HeatLegendItem(color: Color(0xFFDC2626), label: 'Mayor'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeatMapFilters extends StatelessWidget {
  static const filters = [
    'Todos',
    'Pases',
    'Remates',
    'Recuperaciones',
    'Faltas',
    'Goles',
  ];

  final String selected;
  final ValueChanged<String> onSelected;

  const _HeatMapFilters({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = selected == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: isSelected,
              label: Text(filter),
              labelStyle: TextStyle(
                fontSize: 12,
                color:
                    isSelected ? Colors.black : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.bgMuted,
              side: BorderSide(
                color: isSelected ? AppColors.accent : AppColors.borderSubtle,
                width: 0.5,
              ),
              onSelected: (_) => onSelected(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HeatLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _HeatLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelligentAnalysisCard extends StatelessWidget {
  final AnalisisPartidoModel? analysis;
  final bool generating;
  final VoidCallback onGenerate;

  const _IntelligentAnalysisCard({
    required this.analysis,
    required this.generating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final hasMessage = analysis?.mensaje?.trim().isNotEmpty ?? false;
    final hasContent = analysis?.hasContent ?? false;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(title: 'Análisis inteligente'),
              ),
              if (analysis?.generadoConIa ?? false)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.purpleDim,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'IA',
                    style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Generá una lectura del partido a partir de los eventos registrados.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.bgDeep,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                generating
                    ? 'Generando análisis...'
                    : 'Generar análisis inteligente',
              ),
            ),
          ),
          if (hasMessage) ...[
            const SizedBox(height: 12),
            _AnalysisMessage(message: analysis!.mensaje!),
          ],
          if (hasContent) ...[
            const SizedBox(height: 14),
            _AnalysisTextSection(
              title: 'Resumen general',
              content: analysis!.resumenGeneral,
            ),
            _AnalysisListSection(
              title: 'Puntos positivos',
              items: analysis!.puntosPositivos,
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.accent,
            ),
            _AnalysisListSection(
              title: 'Aspectos a mejorar',
              items: analysis!.aspectosAMejorar,
              icon: Icons.tips_and_updates_outlined,
              color: AppColors.warning,
            ),
            _AnalysisListSection(
              title: 'Sugerencias para entrenar',
              items: analysis!.sugerenciasEntrenamiento,
              icon: Icons.sports_soccer_rounded,
              color: AppColors.info,
            ),
            if (analysis!.analisisZonas.trim().isNotEmpty)
              _AnalysisTextSection(
                title: 'Análisis por zonas',
                content: analysis!.analisisZonas,
              ),
          ],
        ],
      ),
    );
  }
}

class _AnalysisMessage extends StatelessWidget {
  final String message;

  const _AnalysisMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningDim,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: AppColors.warning,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisTextSection extends StatelessWidget {
  final String title;
  final String content;

  const _AnalysisTextSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    if (content.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.42,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisListSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;

  const _AnalysisListSection({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoDim,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3), width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.info),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Podés volver a ver este resumen en cualquier momento desde Gestión de Partidos.',
              style: TextStyle(fontSize: 12, color: AppColors.info, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

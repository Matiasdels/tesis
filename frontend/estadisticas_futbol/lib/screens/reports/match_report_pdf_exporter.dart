import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../models/models.dart';

// =============================================================================
//  Pre-computed stats
// =============================================================================
class _MatchStats {
  final PartidoModel match;
  final List<EventoPartidoModel> events;

  _MatchStats({required this.match, required this.events});

  int _count(String type) =>
      events.where((e) => e.tipoEventoNombre == type).length;

  int _countIn(List<EventoPartidoModel> evs, String type) =>
      evs.where((e) => e.tipoEventoNombre == type).length;

  late final goles = _count(EventTypes.goal);
  late final golesRival = _count(EventTypes.goalRival);
  late final remates = _count(EventTypes.shot);
  late final rematesAlArco = _count(EventTypes.shotOnTarget);
  late final totalRemates = remates + rematesAlArco;
  late final asistencias = _count(EventTypes.assist);
  late final corners = _count(EventTypes.corner);
  late final recuperaciones = _count(EventTypes.recovery);
  late final intercepciones = _count(EventTypes.interception);
  late final perdidas = _count(EventTypes.loss);
  late final faltas = _count(EventTypes.foul);
  late final amarillas = _count(EventTypes.yellowCard);
  late final rojas = _count(EventTypes.redCard);

  late final firstHalf = events.where((e) => e.minuto <= 45).toList();
  late final secondHalf = events.where((e) => e.minuto > 45).toList();

  int firstHalfCount(String type) => _countIn(firstHalf, type);
  int secondHalfCount(String type) => _countIn(secondHalf, type);

  late final bool hasIndicadores = totalRemates > 0 || perdidas > 0;

  late final Map<String, Map<String, int>> playerStats = () {
    final result = <String, Map<String, int>>{};
    for (final e in events) {
      if (e.nombreJugador == null || e.nombreJugador!.isEmpty) continue;
      result.putIfAbsent(e.nombreJugador!, () => {});
      result[e.nombreJugador!]![e.tipoEventoNombre] =
          (result[e.nombreJugador!]![e.tipoEventoNombre] ?? 0) + 1;
    }
    return result;
  }();

  late final bool hasPlayerData = playerStats.isNotEmpty;

  int playerCount(String player, String type) =>
      playerStats[player]?[type] ?? 0;

  List<MapEntry<String, int>> topByEvent(String type, {int n = 5}) =>
      (playerStats.entries
              .map((e) => MapEntry(e.key, e.value[type] ?? 0))
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(n)
          .toList();

  late final List<String> insights = () {
    final result = <String>[];

    if (totalRemates > 0) {
      final pct = (goles / totalRemates * 100).round();
      result.add('El equipo convirtió el $pct% de sus remates en gol.');
    }
    if (rematesAlArco > 0) {
      final pct = (goles / rematesAlArco * 100).round();
      result.add('Convirtió el $pct% de sus remates al arco en gol.');
    }

    final defTotal = recuperaciones + intercepciones;
    if (defTotal > 0 || perdidas > 0) {
      if (defTotal > perdidas) {
        result.add(
            'Balance defensivo positivo: $defTotal recuperaciones vs $perdidas pérdidas.');
      } else if (perdidas > defTotal) {
        result.add(
            'Balance defensivo negativo: $perdidas pérdidas vs $defTotal recuperaciones.');
      }
    }

    final firstShots =
        firstHalfCount(EventTypes.shot) + firstHalfCount(EventTypes.shotOnTarget);
    final secondShots =
        secondHalfCount(EventTypes.shot) + secondHalfCount(EventTypes.shotOnTarget);
    if (firstShots + secondShots > 0) {
      if (secondShots > firstShots) {
        result.add(
            'El segundo tiempo concentró más remates ($secondShots vs $firstShots).');
      } else if (firstShots > secondShots) {
        result.add(
            'El primer tiempo concentró más remates ($firstShots vs $secondShots).');
      }
    }

    for (final entry in playerStats.entries) {
      final g = playerCount(entry.key, EventTypes.goal);
      final a = playerCount(entry.key, EventTypes.assist);
      if (g + a >= 2) {
        result.add('${entry.key} participó en ${g + a} goles (${g}G + ${a}A).');
        break;
      }
    }

    return result;
  }();
}

// =============================================================================
//  Exporter
// =============================================================================
class MatchReportPdfExporter {
  const MatchReportPdfExporter._();

  // Colors
  static const _green = PdfColor(0.063, 0.725, 0.506);
  static const _navy = PdfColor(0.059, 0.090, 0.165);
  static const _slate = PdfColor(0.118, 0.161, 0.231);
  static const _rowAlt = PdfColor(0.973, 0.980, 0.988);
  static const _muted = PdfColor(0.392, 0.455, 0.545);

  // ── Entry point ─────────────────────────────────────────────────────────────
  static Future<void> export({
    required PartidoModel match,
    required List<EventoPartidoModel> events,
  }) async {
    final doc = pw.Document();
    final stats = _MatchStats(match: match, events: events);
    final sortedEvents = List<EventoPartidoModel>.from(events)
      ..sort((a, b) => a.minuto.compareTo(b.minuto));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (ctx) =>
            ctx.pageNumber > 1 ? _miniHeader(match) : pw.SizedBox(),
        build: (ctx) => [
          // ─ Página 1 ─
          _buildHeader(match, stats),
          pw.SizedBox(height: 14),
          _buildResumenGeneral(stats),
          pw.SizedBox(height: 14),
          if (stats.hasIndicadores) ...[
            _buildIndicadores(stats),
            pw.SizedBox(height: 14),
          ],
          if (stats.hasPlayerData) ...[
            _buildDestacados(stats),
            pw.SizedBox(height: 14),
          ],
          // ─ Página 2 ─
          _buildEventosPorTipo(stats),
          pw.SizedBox(height: 14),
          _buildComparativaTiempos(stats),
          pw.SizedBox(height: 14),
          if (stats.hasPlayerData) ...[
            _buildParticipacionOfensiva(stats),
            pw.SizedBox(height: 14),
            _buildParticipacionDefensiva(stats),
            pw.SizedBox(height: 14),
          ],
          _buildTimeline(sortedEvents),
          if (stats.insights.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _buildInsights(stats),
          ],
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'partido_vs_${_sanitizeFileName(match.rival)}_${_formatDateFile(match.fecha)}.pdf',
    );
  }

  // ── Mini header (páginas 2+) ─────────────────────────────────────────────
  static pw.Widget _miniHeader(PartidoModel match) {
    const teamName = 'Kancha';
    final label = match.esLocal
        ? '$teamName vs ${match.rival}'
        : '${match.rival} vs $teamName';
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8, color: _muted, fontWeight: pw.FontWeight.bold)),
          pw.Text(_formatDate(match.fecha),
              style: pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
    );
  }

  // ── 1. Encabezado ────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(PartidoModel match, _MatchStats stats) {
    const teamName = 'Kancha';
    final golesOwn = match.golesEquipo ?? 0;
    final golesRiv = match.golesRival ?? 0;
    final localTeam = match.esLocal ? teamName : match.rival;
    final visitTeam = match.esLocal ? match.rival : teamName;
    final localScore = match.esLocal ? golesOwn : golesRiv;
    final visitScore = match.esLocal ? golesRiv : golesOwn;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(color: _navy),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('INFORME DE PARTIDO',
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: _green,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.0)),
              pw.Text('Kancha',
                  style: pw.TextStyle(fontSize: 8, color: _muted)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Text(localTeam,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 15,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 18),
                child: pw.Text('$localScore  —  $visitScore',
                    style: pw.TextStyle(
                        fontSize: 26,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.Expanded(
                child: pw.Text(visitTeam,
                    textAlign: pw.TextAlign.left,
                    style: pw.TextStyle(
                        fontSize: 15,
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: _slate, thickness: 0.5),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _metaChip('Fecha', _formatDate(match.fecha)),
              _metaChip('Competición', match.tipoCompeticion),
              if (match.categoriaNombre != null)
                _metaChip('Categoría', match.categoriaNombre!),
              _metaChip('Condición', match.esLocal ? 'Local' : 'Visitante'),
              _metaChip('Estado', match.estado),
            ],
          ),
          if (match.lugar != null && match.lugar!.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Lugar: ${match.lugar}',
                style: pw.TextStyle(fontSize: 7, color: _muted)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _metaChip(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 6, color: _muted, letterSpacing: 0.4)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold)),
        ],
      );

  // ── 2. Resumen general ───────────────────────────────────────────────────
  static pw.Widget _buildResumenGeneral(_MatchStats stats) {
    final rows = [
      ['Goles', '${stats.goles}', 'Remates totales', '${stats.totalRemates}'],
      ['Goles rival', '${stats.golesRival}', 'Remates al arco', '${stats.rematesAlArco}'],
      ['Asistencias', '${stats.asistencias}', 'Corners', '${stats.corners}'],
      ['Recuperaciones', '${stats.recuperaciones}', 'Intercepciones', '${stats.intercepciones}'],
      ['Pérdidas', '${stats.perdidas}', 'Faltas cometidas', '${stats.faltas}'],
      ['Tarjetas amarillas', '${stats.amarillas}', 'Tarjetas rojas', '${stats.rojas}'],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Resumen general'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(0.8),
            2: const pw.FlexColumnWidth(2.2),
            3: const pw.FlexColumnWidth(0.8),
          },
          children: rows.asMap().entries.map((entry) {
            final alt = entry.key.isOdd;
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                  color: alt ? _rowAlt : PdfColors.white),
              children: entry.value.asMap().entries.map((cell) {
                final isValue = cell.key == 1 || cell.key == 3;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: pw.Text(cell.value,
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: isValue
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                          color: isValue ? _navy : PdfColors.black)),
                );
              }).toList(),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── 3. Indicadores ──────────────────────────────────────────────────────
  static pw.Widget _buildIndicadores(_MatchStats stats) {
    final indicators = <_Indicator>[];

    if (stats.totalRemates > 0) {
      indicators.add(_Indicator(
        value: _pct(stats.rematesAlArco, stats.totalRemates),
        label: 'Precisión de remate',
        sub: '${stats.rematesAlArco} al arco / ${stats.totalRemates} totales',
      ));
      indicators.add(_Indicator(
        value: _pct(stats.goles, stats.totalRemates),
        label: 'Conversión de remates',
        sub: '${stats.goles} goles / ${stats.totalRemates} remates',
      ));
    }
    if (stats.rematesAlArco > 0) {
      indicators.add(_Indicator(
        value: _pct(stats.goles, stats.rematesAlArco),
        label: 'Conversión al arco',
        sub: '${stats.goles} goles / ${stats.rematesAlArco} al arco',
      ));
    }
    if (stats.perdidas > 0) {
      final defTotal = stats.recuperaciones + stats.intercepciones;
      indicators.add(_Indicator(
        value: _ratio(defTotal, stats.perdidas),
        label: 'Balance recup. / pérdida',
        sub: '$defTotal recuperaciones / ${stats.perdidas} pérdidas',
      ));
    }

    if (indicators.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Indicadores'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: indicators
              .map((ind) => pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 6),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _rowAlt,
                        border:
                            pw.Border.all(color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(ind.value,
                              style: pw.TextStyle(
                                  fontSize: 20,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _green)),
                          pw.SizedBox(height: 3),
                          pw.Text(ind.label,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _navy)),
                          pw.SizedBox(height: 2),
                          pw.Text(ind.sub,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(fontSize: 6, color: _muted)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── 4. Jugadores destacados ──────────────────────────────────────────────
  static pw.Widget _buildDestacados(_MatchStats stats) {
    final goleadores = stats.topByEvent(EventTypes.goal);
    final asistidores = stats.topByEvent(EventTypes.assist);
    final recuperadores = stats.topByEvent(EventTypes.recovery);

    if (goleadores.isEmpty && asistidores.isEmpty && recuperadores.isEmpty) {
      return pw.SizedBox();
    }

    pw.Widget rankingCol(
        String title, List<MapEntry<String, int>> entries, String unit) {
      return pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 7,
                      color: _green,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.5)),
              pw.SizedBox(height: 5),
              if (entries.isEmpty)
                pw.Text('Sin datos',
                    style: pw.TextStyle(fontSize: 8, color: _muted))
              else
                ...entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(e.key,
                                style: pw.TextStyle(
                                    fontSize: 8, color: PdfColors.black)),
                          ),
                          pw.Text('${e.value} $unit',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _navy)),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Jugadores destacados'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            rankingCol('Goleadores', goleadores, 'gol'),
            rankingCol('Asistencias', asistidores, 'ast'),
            rankingCol('Recuperaciones', recuperadores, 'rec'),
          ],
        ),
      ],
    );
  }

  // ── 5. Eventos por tipo ──────────────────────────────────────────────────
  static pw.Widget _buildEventosPorTipo(_MatchStats stats) {
    final entries = EventTypes.registrable
        .map((type) => MapEntry(type, stats._count(type)))
        .where((e) => e.value > 0)
        .toList();

    // Legacy — solo si existen en el historial
    for (final type in [
      EventTypes.passOk,
      EventTypes.passBad,
      EventTypes.tackleOk,
      EventTypes.tackleBad,
    ]) {
      final c = stats._count(type);
      if (c > 0) entries.add(MapEntry(type, c));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Eventos por tipo'),
        pw.SizedBox(height: 6),
        if (entries.isEmpty)
          pw.Text('No se registraron eventos.',
              style: pw.TextStyle(fontSize: 9, color: _muted))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              _headerRow(['Evento', 'Cantidad']),
              ...entries.asMap().entries.map((entry) => _dataRow(
                    [entry.value.key, '${entry.value.value}'],
                    alt: entry.key.isOdd,
                  )),
            ],
          ),
      ],
    );
  }

  // ── 6. Comparativa por tiempos ───────────────────────────────────────────
  static pw.Widget _buildComparativaTiempos(_MatchStats stats) {
    final metrics = [
      ['Goles', EventTypes.goal],
      ['Remates', EventTypes.shot],
      ['Remates al arco', EventTypes.shotOnTarget],
      ['Recuperaciones', EventTypes.recovery],
      ['Faltas', EventTypes.foul],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Comparativa por tiempos'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            _headerRow(['Métrica', '1er tiempo (≤45\')', '2do tiempo (>45\')']),
            ...metrics.asMap().entries.map((entry) => _dataRow(
                  [
                    entry.value[0],
                    '${stats.firstHalfCount(entry.value[1])}',
                    '${stats.secondHalfCount(entry.value[1])}',
                  ],
                  alt: entry.key.isOdd,
                )),
          ],
        ),
      ],
    );
  }

  // ── 7. Participación ofensiva ────────────────────────────────────────────
  static pw.Widget _buildParticipacionOfensiva(_MatchStats stats) {
    final offensiveTypes = [
      EventTypes.goal,
      EventTypes.assist,
      EventTypes.shot,
      EventTypes.shotOnTarget,
    ];
    final players = stats.playerStats.entries
        .where((e) => offensiveTypes.any((t) => (e.value[t] ?? 0) > 0))
        .toList()
      ..sort((a, b) =>
          (b.value[EventTypes.goal] ?? 0) - (a.value[EventTypes.goal] ?? 0));

    if (players.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Participación ofensiva'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1.2),
          },
          children: [
            _headerRow(['Jugador', 'Goles', 'Asist.', 'Remates', 'Al arco']),
            ...players.asMap().entries.map((entry) => _dataRow(
                  [
                    entry.value.key,
                    '${stats.playerCount(entry.value.key, EventTypes.goal)}',
                    '${stats.playerCount(entry.value.key, EventTypes.assist)}',
                    '${stats.playerCount(entry.value.key, EventTypes.shot)}',
                    '${stats.playerCount(entry.value.key, EventTypes.shotOnTarget)}',
                  ],
                  alt: entry.key.isOdd,
                )),
          ],
        ),
      ],
    );
  }

  // ── 8. Participación defensiva ───────────────────────────────────────────
  static pw.Widget _buildParticipacionDefensiva(_MatchStats stats) {
    final defensiveTypes = [
      EventTypes.recovery,
      EventTypes.interception,
      EventTypes.save,
      EventTypes.loss,
    ];
    final players = stats.playerStats.entries
        .where((e) => defensiveTypes.any((t) => (e.value[t] ?? 0) > 0))
        .toList()
      ..sort((a, b) {
        final ar = (a.value[EventTypes.recovery] ?? 0) +
            (a.value[EventTypes.interception] ?? 0);
        final br = (b.value[EventTypes.recovery] ?? 0) +
            (b.value[EventTypes.interception] ?? 0);
        return br - ar;
      });

    if (players.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Participación defensiva'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            _headerRow(['Jugador', 'Recup.', 'Intercep.', 'Ataj.', 'Pérd.']),
            ...players.asMap().entries.map((entry) => _dataRow(
                  [
                    entry.value.key,
                    '${stats.playerCount(entry.value.key, EventTypes.recovery)}',
                    '${stats.playerCount(entry.value.key, EventTypes.interception)}',
                    '${stats.playerCount(entry.value.key, EventTypes.save)}',
                    '${stats.playerCount(entry.value.key, EventTypes.loss)}',
                  ],
                  alt: entry.key.isOdd,
                )),
          ],
        ),
      ],
    );
  }

  // ── 9. Timeline ──────────────────────────────────────────────────────────
  static pw.Widget _buildTimeline(List<EventoPartidoModel> sortedEvents) {
    if (sortedEvents.isEmpty) return pw.SizedBox();

    // Agrupar por minuto
    final byMinute = <int, List<EventoPartidoModel>>{};
    for (final e in sortedEvents) {
      byMinute.putIfAbsent(e.minuto, () => []).add(e);
    }
    final minutes = byMinute.keys.toList()..sort();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Timeline del partido'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FixedColumnWidth(36),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            _headerRow(["Min'", 'Evento']),
            ...minutes.asMap().entries.expand((minuteEntry) {
              final minute = minuteEntry.value;
              final evts = byMinute[minute]!;
              return evts.asMap().entries.map((evEntry) {
                final ev = evEntry.value;
                final isFirst = evEntry.key == 0;
                final alt = minuteEntry.key.isOdd;
                return _dataRow(
                  [
                    isFirst ? "$minute'" : '',
                    '${ev.tipoEventoNombre}'
                        '${ev.nombreJugador != null ? " — ${ev.nombreJugador}" : ""}',
                  ],
                  alt: alt,
                );
              });
            }).toList(),
          ],
        ),
      ],
    );
  }

  // ── 10. Aspectos destacados ──────────────────────────────────────────────
  static pw.Widget _buildInsights(_MatchStats stats) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Aspectos destacados'),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _rowAlt,
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: stats.insights
                .map((insight) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 5),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: _green,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Expanded(
                            child: pw.Text(insight,
                                style: pw.TextStyle(
                                    fontSize: 9, color: PdfColors.black)),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  static pw.Widget _sectionTitle(String title) => pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: const pw.BoxDecoration(color: _slate),
        child: pw.Row(
          children: [
            pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.6),
            ),
          ],
        ),
      );

  static pw.TableRow _headerRow(List<String> cells) => pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 5),
                  child: pw.Text(c,
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold)),
                ))
            .toList(),
      );

  static pw.TableRow _dataRow(List<String> cells, {bool alt = false}) =>
      pw.TableRow(
        decoration:
            pw.BoxDecoration(color: alt ? _rowAlt : PdfColors.white),
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: pw.Text(c,
                      style: pw.TextStyle(
                          fontSize: 8, color: PdfColors.black)),
                ))
            .toList(),
      );

  static String _pct(int num, int den) {
    if (den == 0) return '—';
    return '${(num / den * 100).round()}%';
  }

  static String _ratio(int num, int den) {
    if (den == 0) return '—';
    return '${(num / den).toStringAsFixed(1)}x';
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _formatDateFile(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  static String _sanitizeFileName(String value) => value
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
}

// ── Data class para indicadores ──────────────────────────────────────────────
class _Indicator {
  final String value;
  final String label;
  final String sub;
  const _Indicator({required this.value, required this.label, required this.sub});
}

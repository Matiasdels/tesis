import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../models/models.dart';
import '../../widgets/match/pitch_view.dart';

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

  // ── Conteos base ──────────────────────────────────────────────────────────
  late final goles = _count(EventTypes.goal);
  late final golesRival = _count(EventTypes.goalRival);
  // Remate = disparo que no va al arco; Remate al arco = disparo salvado;
  // Los goles también son remates al arco — se suman en las métricas derivadas.
  late final rematesMisses = _count(EventTypes.shot);
  late final rematesSalvados = _count(EventTypes.shotOnTarget);
  late final asistencias = _count(EventTypes.assist);
  late final pasesClaves = _count(EventTypes.passKey);
  late final centros = _count(EventTypes.cross);
  late final corners = _count(EventTypes.corner);
  late final penalesAFavor = _count(EventTypes.penaltyFor);
  late final penalesEnContra = _count(EventTypes.penaltyAgainst);
  late final recuperaciones = _count(EventTypes.recovery);
  late final intercepciones = _count(EventTypes.interception);
  late final atajadas = _count(EventTypes.save);
  late final perdidas = _count(EventTypes.loss);
  late final faltas = _count(EventTypes.foul);
  late final amarillas = _count(EventTypes.yellowCard);
  late final rojas = _count(EventTypes.redCard);

  // ── Métricas ofensivas derivadas ─────────────────────────────────────────
  // Remates totales = errados + salvados + goles
  late final totalRemates = rematesMisses + rematesSalvados + goles;
  // Remates al arco reales = salvados + goles (todos los que fueron al palo)
  late final rematesAlArcoReales = rematesSalvados + goles;
  // Generación ofensiva = acciones que crean oportunidades
  late final generacionOfensiva =
      pasesClaves + centros + corners + penalesAFavor + asistencias;

  // ── Métricas defensivas derivadas ────────────────────────────────────────
  late final accionesDefensivasPositivas =
      recuperaciones + intercepciones + atajadas;
  late final balanceDefensivo = recuperaciones + intercepciones - perdidas;

  // ── Disciplina ───────────────────────────────────────────────────────────
  late final indiceDisciplinario = faltas + amarillas * 2 + rojas * 5;
  late final labelDisciplina = indiceDisciplinario == 0
      ? 'Sin incidentes disciplinarios'
      : indiceDisciplinario <= 5
          ? 'Bajo riesgo disciplinario'
          : indiceDisciplinario <= 12
              ? 'Riesgo disciplinario moderado'
              : 'Alto riesgo disciplinario';

  // ── Por tiempo ───────────────────────────────────────────────────────────
  // evento.periodo is the source of truth; minute thresholds are NOT used.
  late final firstHalf = events
      .where((e) => e.periodo == MatchPeriod.primerTiempo)
      .toList();
  late final secondHalf = events
      .where((e) => e.periodo == MatchPeriod.segundoTiempo)
      .toList();

  int firstHalfCount(String type) => _countIn(firstHalf, type);
  int secondHalfCount(String type) => _countIn(secondHalf, type);

  int get firstHalfTotalRemates =>
      firstHalfCount(EventTypes.shot) +
      firstHalfCount(EventTypes.shotOnTarget) +
      firstHalfCount(EventTypes.goal);
  int get secondHalfTotalRemates =>
      secondHalfCount(EventTypes.shot) +
      secondHalfCount(EventTypes.shotOnTarget) +
      secondHalfCount(EventTypes.goal);

  int get firstHalfGeneracion =>
      firstHalfCount(EventTypes.passKey) +
      firstHalfCount(EventTypes.cross) +
      firstHalfCount(EventTypes.corner) +
      firstHalfCount(EventTypes.penaltyFor) +
      firstHalfCount(EventTypes.assist);
  int get secondHalfGeneracion =>
      secondHalfCount(EventTypes.passKey) +
      secondHalfCount(EventTypes.cross) +
      secondHalfCount(EventTypes.corner) +
      secondHalfCount(EventTypes.penaltyFor) +
      secondHalfCount(EventTypes.assist);

  int get firstHalfDefensivePositive =>
      firstHalfCount(EventTypes.recovery) +
      firstHalfCount(EventTypes.interception) +
      firstHalfCount(EventTypes.save);
  int get secondHalfDefensivePositive =>
      secondHalfCount(EventTypes.recovery) +
      secondHalfCount(EventTypes.interception) +
      secondHalfCount(EventTypes.save);

  // ── Flags de disponibilidad ──────────────────────────────────────────────
  late final bool hasOfensiva = totalRemates > 0 || generacionOfensiva > 0;
  late final bool hasDefensiva =
      accionesDefensivasPositivas > 0 || perdidas > 0;
  late final bool hasDisciplina = indiceDisciplinario > 0;

  // ── Stats por jugador ─────────────────────────────────────────────────────
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

  int playerTotalRemates(String player) =>
      playerCount(player, EventTypes.shot) +
      playerCount(player, EventTypes.shotOnTarget) +
      playerCount(player, EventTypes.goal);

  int playerADPPos(String player) =>
      playerCount(player, EventTypes.recovery) +
      playerCount(player, EventTypes.interception) +
      playerCount(player, EventTypes.save);

  int playerIndiceDisciplinario(String player) =>
      playerCount(player, EventTypes.foul) +
      playerCount(player, EventTypes.yellowCard) * 2 +
      playerCount(player, EventTypes.redCard) * 5;

  List<MapEntry<String, int>> topByEvent(String type, {int n = 5}) =>
      (playerStats.entries
              .map((e) => MapEntry(e.key, e.value[type] ?? 0))
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(n)
          .toList();

  // ── Aspectos destacados ───────────────────────────────────────────────────
  late final List<String> insights = () {
    final result = <String>[];

    // Conversión de remates
    if (totalRemates > 0) {
      final pct = (goles / totalRemates * 100).round();
      result.add('El equipo convirtió el $pct% de sus remates en gol'
          ' ($goles de $totalRemates).');
    }

    // Conversión al arco
    if (rematesAlArcoReales > 0 && rematesAlArcoReales != totalRemates) {
      final pct = (goles / rematesAlArcoReales * 100).round();
      result.add('$pct% de los remates al arco terminaron en gol'
          ' ($goles de $rematesAlArcoReales).');
    }

    // Balance defensivo — frase precisa
    if (accionesDefensivasPositivas > 0 || perdidas > 0) {
      if (accionesDefensivasPositivas > perdidas) {
        result.add('Balance defensivo positivo: $recuperaciones recuperaciones'
            ' + $intercepciones intercepciones'
            ' frente a $perdidas pérdidas.');
      } else if (perdidas > accionesDefensivasPositivas) {
        result.add('Balance defensivo negativo: $perdidas pérdidas'
            ' frente a $accionesDefensivasPositivas acciones defensivas positivas.');
      }
    }

    // Comparativa ofensiva por tiempo
    if (firstHalfTotalRemates + secondHalfTotalRemates > 0) {
      if (firstHalfTotalRemates > secondHalfTotalRemates) {
        result.add('El primer tiempo concentró más remates'
            ' ($firstHalfTotalRemates vs $secondHalfTotalRemates).');
      } else if (secondHalfTotalRemates > firstHalfTotalRemates) {
        result.add('El segundo tiempo concentró más remates'
            ' ($secondHalfTotalRemates vs $firstHalfTotalRemates).');
      }
    }

    // Comparativa defensiva por tiempo
    if (firstHalfDefensivePositive + secondHalfDefensivePositive > 0) {
      if (secondHalfDefensivePositive > firstHalfDefensivePositive) {
        result.add(
            'La actividad defensiva se concentró en el segundo tiempo'
            ' ($secondHalfDefensivePositive vs $firstHalfDefensivePositive acciones).');
      } else if (firstHalfDefensivePositive > secondHalfDefensivePositive) {
        result.add(
            'La actividad defensiva se concentró en el primer tiempo'
            ' ($firstHalfDefensivePositive vs $secondHalfDefensivePositive acciones).');
      }
    }

    // Participación individual destacada
    for (final entry in playerStats.entries) {
      final g = playerCount(entry.key, EventTypes.goal);
      final a = playerCount(entry.key, EventTypes.assist);
      if (g + a >= 2) {
        result.add('${entry.key} participó en ${g + a} goles (${g}G + ${a}A).');
        break;
      }
    }

    // Disciplina
    if (hasDisciplina) {
      result.add('$labelDisciplina (índice: $indiceDisciplinario).');
    }

    return result.take(6).toList();
  }();
}

// =============================================================================
//  Exporter
// =============================================================================
class MatchReportPdfExporter {
  const MatchReportPdfExporter._();

  static const _green = PdfColor(0.063, 0.725, 0.506);
  static const _navy = PdfColor(0.059, 0.090, 0.165);
  static const _slate = PdfColor(0.118, 0.161, 0.231);
  static const _rowAlt = PdfColor(0.973, 0.980, 0.988);
  static const _muted = PdfColor(0.392, 0.455, 0.545);
  static const _amber = PdfColor(0.918, 0.702, 0.0);
  static const _red = PdfColor(0.863, 0.212, 0.267);

  // ── Render heat map off-screen → PNG bytes ──────────────────────────────────
  static Future<Uint8List?> _renderPitchHeatMap(
    List<EventoPartidoModel> events,
  ) async {
    if (events.isEmpty) return null;
    const w = 750;
    const h = 1005; // 1:1.34 ratio, matches app's height = width * 1.34
    final recorder = ui.PictureRecorder();
    MatchPitchPainter(
      events: events,
      showEventDots: false,
      showHeatMap: true,
    ).paint(ui.Canvas(recorder), ui.Size(w.toDouble(), h.toDouble()));
    final img = await recorder.endRecording().toImage(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  // ── Spatial distribution insights ────────────────────────────────────────────
  static List<String> _spatialInsights(List<EventoPartidoModel> events) {
    if (events.isEmpty) return [];
    final n = events.length;
    final result = <String>[];

    // Horizontal zones: left (x<0.33), center (0.33-0.67), right (x>0.67)
    final left = events.where((e) => e.pitchX < 0.33).length;
    final center =
        events.where((e) => e.pitchX >= 0.33 && e.pitchX <= 0.67).length;
    final right = events.where((e) => e.pitchX > 0.67).length;

    final maxH = [left, center, right].reduce((a, b) => a > b ? a : b);
    final dominantZone = maxH == left
        ? 'banda izquierda'
        : maxH == right
            ? 'banda derecha'
            : 'zona central';
    result.add(
        'Mayor actividad por $dominantZone (${(maxH / n * 100).round()}% de las acciones).');

    // Vertical split: upper half (y<0.5) vs lower half (y>=0.5)
    final upper = events.where((e) => e.pitchY < 0.5).length;
    final upperPct = (upper / n * 100).round();
    final lowerPct = 100 - upperPct;
    if (upperPct >= 60) {
      result.add('Concentración en la mitad superior del campo ($upperPct%).');
    } else if (lowerPct >= 60) {
      result.add('Concentración en la mitad inferior del campo ($lowerPct%).');
    } else {
      result.add(
          'Distribución equilibrada entre ambas mitades ($upperPct% superior / $lowerPct% inferior).');
    }

    return result;
  }

  // ── Análisis espacial page content ───────────────────────────────────────────
  static pw.Widget _buildAnalisisEspacial({
    required Uint8List? generalImg,
    required Uint8List? offensiveImg,
    required Uint8List? defensiveImg,
    required List<EventoPartidoModel> allEvents,
    required List<EventoPartidoModel> offensiveEvents,
    required List<EventoPartidoModel> defensiveEvents,
  }) {
    // Column width: (A4-landscape usable 770pt - 2×10pt gaps) / 3 ≈ 250pt
    const colW = 250.0;
    const mapH = colW * 1.34; // maintains app's pitch aspect ratio

    pw.Widget mapColumn({
      required String title,
      required Uint8List? imgBytes,
      required List<EventoPartidoModel> events,
    }) {
      final insights = _spatialInsights(events);
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: const pw.BoxDecoration(color: _slate),
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 5),
          if (imgBytes == null)
            pw.Container(
              width: colW,
              height: mapH,
              decoration: pw.BoxDecoration(
                color: _rowAlt,
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Center(
                child: pw.Text(
                  'No hay eventos\nregistrados\npara este mapa.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: _muted),
                ),
              ),
            )
          else
            pw.Image(
              pw.MemoryImage(imgBytes),
              width: colW,
              height: mapH,
              fit: pw.BoxFit.fill,
            ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${events.length} acciones',
            style: pw.TextStyle(
              fontSize: 7,
              color: _navy,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          ...insights.map(
            (s) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                '- $s',
                style: const pw.TextStyle(fontSize: 7, color: _muted),
              ),
            ),
          ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Análisis espacial del partido'),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: mapColumn(
                title: 'Distribución general de eventos',
                imgBytes: generalImg,
                events: allEvents,
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: mapColumn(
                title: 'Distribución de acciones ofensivas',
                imgBytes: offensiveImg,
                events: offensiveEvents,
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: mapColumn(
                title: 'Distribución de acciones defensivas',
                imgBytes: defensiveImg,
                events: defensiveEvents,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Entry point ─────────────────────────────────────────────────────────────
  static Future<void> export({
    required PartidoModel match,
    required List<EventoPartidoModel> events,
  }) async {
    final doc = pw.Document();
    final stats = _MatchStats(match: match, events: events);
    final sortedEvents = List<EventoPartidoModel>.from(events)
      ..sort((a, b) => a.minuto.compareTo(b.minuto));

    // ── Separate events by category for spatial analysis ────────────────────
    const offensiveTypes = {
      EventTypes.goal,
      EventTypes.assist,
      EventTypes.shot,
      EventTypes.shotOnTarget,
      EventTypes.passKey,
      EventTypes.cross,
      EventTypes.corner,
      EventTypes.penaltyFor,
      EventTypes.offside,
    };
    const defensiveTypes = {
      EventTypes.recovery,
      EventTypes.interception,
      EventTypes.save,
      EventTypes.loss,
      EventTypes.foul,
      EventTypes.penaltyAgainst,
    };
    final offensiveEvents =
        events.where((e) => offensiveTypes.contains(e.tipoEventoNombre)).toList();
    final defensiveEvents =
        events.where((e) => defensiveTypes.contains(e.tipoEventoNombre)).toList();

    // Render heat maps before building PDF (off-screen via PictureRecorder)
    final generalImg = await _renderPitchHeatMap(events);
    final offensiveImg = await _renderPitchHeatMap(offensiveEvents);
    final defensiveImg = await _renderPitchHeatMap(defensiveEvents);

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
          if (stats.hasOfensiva) ...[
            _buildEmbudoOfensivo(stats),
            pw.SizedBox(height: 14),
          ],
          if (stats.hasDefensiva) ...[
            _buildIndicadoresDefensivos(stats),
            pw.SizedBox(height: 14),
          ],
          if (stats.hasDisciplina) ...[
            _buildDisciplina(stats),
            pw.SizedBox(height: 14),
          ],
          if (stats.hasPlayerData) ...[
            _buildDestacados(stats),
            pw.SizedBox(height: 14),
          ],
          // ─ Página 2+ ─
          _buildEventosPorTipo(stats),
          pw.SizedBox(height: 14),
          _buildComparativaOfensivaTiempos(stats),
          pw.SizedBox(height: 14),
          if (stats.hasDefensiva) ...[
            _buildComparativaDefensivaTiempos(stats),
            pw.SizedBox(height: 14),
          ],
          if (stats.hasPlayerData) ...[
            _buildParticipacionOfensiva(stats),
            pw.SizedBox(height: 14),
            _buildParticipacionDefensiva(stats),
            pw.SizedBox(height: 14),
            _buildDisciplinaIndividual(stats),
            pw.SizedBox(height: 14),
          ],
          _buildTimeline(sortedEvents),
          if (stats.insights.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _buildInsights(stats),
          ],
          if (match.huboPenales) ...[
            pw.SizedBox(height: 14),
            _buildDefinicionPenales(match),
          ],
        ],
      ),
    );

    // ── Página de análisis espacial (A4 landscape, 3 mapas en columnas) ──────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        header: (ctx) => _miniHeader(match),
        build: (ctx) => [
          _buildAnalisisEspacial(
            generalImg: generalImg,
            offensiveImg: offensiveImg,
            defensiveImg: defensiveImg,
            allEvents: events,
            offensiveEvents: offensiveEvents,
            defensiveEvents: defensiveEvents,
          ),
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
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
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
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
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
                child: pw.Text('$localScore - $visitScore',
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
                style: const pw.TextStyle(fontSize: 7, color: _muted)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _metaChip(String label, String value) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label.toUpperCase(),
              style: const pw.TextStyle(
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
      ['Goles', '${stats.goles}', 'Goles rival', '${stats.golesRival}'],
      ['Remates totales', '${stats.totalRemates}', 'Remates al arco', '${stats.rematesAlArcoReales}'],
      ['Asistencias', '${stats.asistencias}', 'Pases clave', '${stats.pasesClaves}'],
      ['Centros', '${stats.centros}', 'Corners', '${stats.corners}'],
      ['Recuperaciones', '${stats.recuperaciones}', 'Intercepciones', '${stats.intercepciones}'],
      ['Atajadas', '${stats.atajadas}', 'Pérdidas', '${stats.perdidas}'],
      ['Faltas', '${stats.faltas}', 'Amarillas / Rojas', '${stats.amarillas} / ${stats.rojas}'],
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

  // ── 3. Embudo ofensivo ───────────────────────────────────────────────────
  static pw.Widget _buildEmbudoOfensivo(_MatchStats stats) {
    // Tarjetas del embudo: generación → remates → remates al arco → goles
    final funnelItems = <_FunnelItem>[
      if (stats.generacionOfensiva > 0)
        _FunnelItem(
          label: 'Generación ofensiva',
          value: '${stats.generacionOfensiva}',
          sub: 'Pases clave: ${stats.pasesClaves} | Centros: ${stats.centros}'
              ' | Corners: ${stats.corners} | Asistencias: ${stats.asistencias}',
        ),
      if (stats.totalRemates > 0)
        _FunnelItem(
          label: 'Remates totales',
          value: '${stats.totalRemates}',
          sub: 'Errados: ${stats.rematesMisses} | Al arco: ${stats.rematesSalvados} | Goles: ${stats.goles}',
        ),
      if (stats.rematesAlArcoReales > 0)
        _FunnelItem(
          label: 'Remates al arco',
          value: '${stats.rematesAlArcoReales}',
          sub: '${_pct(stats.rematesAlArcoReales, stats.totalRemates)} de precisión',
        ),
      _FunnelItem(
        label: 'Goles convertidos',
        value: '${stats.goles}',
        sub: stats.totalRemates > 0
            ? '${_pct(stats.goles, stats.totalRemates)} conversión total'
            : stats.rematesAlArcoReales > 0
                ? '${_pct(stats.goles, stats.rematesAlArcoReales)} conv. al arco'
                : 'Sin remates registrados',
      ),
    ];

    // Métricas de conversión
    final convMetrics = <List<String>>[];
    if (stats.totalRemates > 0) {
      convMetrics.add([
        'Precisión de remate',
        _pct(stats.rematesAlArcoReales, stats.totalRemates),
        '${stats.rematesAlArcoReales} al arco / ${stats.totalRemates} totales',
      ]);
      convMetrics.add([
        'Conversión de remates',
        _pct(stats.goles, stats.totalRemates),
        '${stats.goles} goles / ${stats.totalRemates} remates',
      ]);
    }
    if (stats.rematesAlArcoReales > 0) {
      convMetrics.add([
        'Conversión al arco',
        _pct(stats.goles, stats.rematesAlArcoReales),
        '${stats.goles} goles / ${stats.rematesAlArcoReales} al arco',
      ]);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Análisis ofensivo'),
        pw.SizedBox(height: 6),
        // Fila del embudo
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: funnelItems
              .map((item) => pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 6),
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: _rowAlt,
                        border: pw.Border.all(
                            color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(item.value,
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _green)),
                          pw.SizedBox(height: 2),
                          pw.Text(item.label,
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(
                                  fontSize: 7,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _navy)),
                          pw.SizedBox(height: 2),
                          pw.Text(item.sub,
                              textAlign: pw.TextAlign.center,
                              style:
                                  const pw.TextStyle(fontSize: 6, color: _muted)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
        // Métricas de conversión (si hay datos)
        if (convMetrics.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2.5),
            },
            children: [
              _headerRow(['Métrica', 'Valor', 'Detalle']),
              ...convMetrics.asMap().entries.map((entry) =>
                  _dataRow(entry.value, alt: entry.key.isOdd)),
            ],
          ),
        ],
      ],
    );
  }

  // ── 4. Indicadores defensivos ────────────────────────────────────────────
  static pw.Widget _buildIndicadoresDefensivos(_MatchStats stats) {
    final adp = stats.accionesDefensivasPositivas;
    final efectividad = adp + stats.faltas > 0
        ? _pct(adp, adp + stats.faltas)
        : '-';

    final cards = [
      _Indicator(
        value: '$adp',
        label: 'Acciones defensivas',
        sub: '${stats.recuperaciones} recup. + ${stats.intercepciones} intercep. + ${stats.atajadas} ataj.',
      ),
      _Indicator(
        value: '${stats.balanceDefensivo > 0 ? '+' : ''}${stats.balanceDefensivo}',
        label: 'Balance defensivo',
        sub: '${stats.recuperaciones} recup. + ${stats.intercepciones} intercep. - ${stats.perdidas} perd.',
      ),
      _Indicator(
        value: efectividad,
        label: 'Efectividad defensiva',
        sub: '$adp acciones positivas / ${adp + stats.faltas} totales (incl. faltas)',
      ),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Análisis defensivo'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: cards
              .map((ind) => pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 6),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: _rowAlt,
                        border: pw.Border.all(
                            color: PdfColors.grey300, width: 0.5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(ind.value,
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _navy)),
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
                              style:
                                  const pw.TextStyle(fontSize: 6, color: _muted)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── 5. Disciplina del equipo ─────────────────────────────────────────────
  static pw.Widget _buildDisciplina(_MatchStats stats) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Disciplina'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.white),
              children: [
                _disciplineCell('Faltas cometidas', '${stats.faltas}'),
                _disciplineCell('Amarillas', '${stats.amarillas}',
                    valueColor: stats.amarillas > 0 ? _amber : null),
                _disciplineCell('Rojas', '${stats.rojas}',
                    valueColor: stats.rojas > 0 ? _red : null),
                _disciplineCell('Índice disciplinario',
                    '${stats.indiceDisciplinario}'),
              ],
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _rowAlt),
              children: [
                pw.Padding(
                  padding:
                      const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: pw.Text(stats.labelDisciplina,
                      style: pw.TextStyle(
                          fontSize: 8,
                          color: stats.indiceDisciplinario > 12
                              ? _red
                              : stats.indiceDisciplinario > 5
                                  ? _amber
                                  : _navy,
                          fontWeight: pw.FontWeight.bold)),
                ),
                pw.SizedBox(),
                pw.SizedBox(),
                pw.SizedBox(),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _disciplineCell(String label, String value,
      {PdfColor? valueColor}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: valueColor ?? _navy)),
            pw.SizedBox(height: 2),
            pw.Text(label,
                style: const pw.TextStyle(fontSize: 7, color: _muted)),
          ],
        ),
      );

  // ── 6. Jugadores destacados ──────────────────────────────────────────────
  static pw.Widget _buildDestacados(_MatchStats stats) {
    // Ranking por participaciones de gol (goles + asistencias)
    final participaciones = (stats.playerStats.entries
            .map((e) => MapEntry(
                e.key,
                (e.value[EventTypes.goal] ?? 0) +
                    (e.value[EventTypes.assist] ?? 0)))
            .where((e) => e.value > 0)
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .toList();

    final goleadores = stats.topByEvent(EventTypes.goal);
    final recuperadores = stats.topByEvent(EventTypes.recovery);

    if (participaciones.isEmpty && goleadores.isEmpty && recuperadores.isEmpty) {
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
                    style: const pw.TextStyle(fontSize: 8, color: _muted))
              else
                ...entries.map((e) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(e.key,
                                style: const pw.TextStyle(
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
            rankingCol('Part. en goles', participaciones, 'pt'),
            rankingCol('Goleadores', goleadores, 'gol'),
            rankingCol('Recuperaciones', recuperadores, 'rec'),
          ],
        ),
      ],
    );
  }

  // ── 7. Eventos por tipo ──────────────────────────────────────────────────
  static pw.Widget _buildEventosPorTipo(_MatchStats stats) {
    const orderedTypes = [
      // Ataque
      EventTypes.goal,
      EventTypes.assist,
      EventTypes.shot,
      EventTypes.shotOnTarget,
      EventTypes.passKey,
      EventTypes.cross,
      EventTypes.corner,
      EventTypes.offside,
      EventTypes.penaltyFor,
      // Defensa
      EventTypes.goalRival,
      EventTypes.save,
      EventTypes.recovery,
      EventTypes.interception,
      EventTypes.loss,
      // Disciplina
      EventTypes.foul,
      EventTypes.yellowCard,
      EventTypes.redCard,
      EventTypes.penaltyAgainst,
      // Legado
      EventTypes.passOk,
      EventTypes.passBad,
      EventTypes.tackleOk,
      EventTypes.tackleBad,
    ];

    final entries = orderedTypes
        .map((type) => MapEntry(type, stats._count(type)))
        .where((e) => e.value > 0)
        .toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Eventos por tipo'),
        pw.SizedBox(height: 6),
        if (entries.isEmpty)
          pw.Text('No se registraron eventos.',
              style: const pw.TextStyle(fontSize: 9, color: _muted))
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

  // ── 8. Comparativa ofensiva por tiempos ─────────────────────────────────
  static pw.Widget _buildComparativaOfensivaTiempos(_MatchStats stats) {
    final metrics = [
      ['Goles', EventTypes.goal],
      ['Remates totales', '__totalRemates__'],
      ['Remates al arco', '__rematesAlArco__'],
      ['Generación ofensiva', '__generacion__'],
      ['Faltas recibidas', EventTypes.foul],
    ];

    String firstVal(String key) => switch (key) {
          '__totalRemates__' => '${stats.firstHalfTotalRemates}',
          '__rematesAlArco__' => '${stats.firstHalfCount(EventTypes.shotOnTarget) + stats.firstHalfCount(EventTypes.goal)}',
          '__generacion__' => '${stats.firstHalfGeneracion}',
          _ => '${stats.firstHalfCount(key)}',
        };

    String secondVal(String key) => switch (key) {
          '__totalRemates__' => '${stats.secondHalfTotalRemates}',
          '__rematesAlArco__' => '${stats.secondHalfCount(EventTypes.shotOnTarget) + stats.secondHalfCount(EventTypes.goal)}',
          '__generacion__' => '${stats.secondHalfGeneracion}',
          _ => '${stats.secondHalfCount(key)}',
        };

    // Lectura automática
    String? lectura;
    if (stats.firstHalfTotalRemates + stats.secondHalfTotalRemates > 0) {
      final f1 = stats.firstHalfTotalRemates;
      final f2 = stats.secondHalfTotalRemates;
      final g1 = stats.firstHalfCount(EventTypes.goal);
      final g2 = stats.secondHalfCount(EventTypes.goal);

      if (f1 > f2 && g2 > g1) {
        lectura =
            'El equipo remató más en el primer tiempo, pero convirtió en el segundo.';
      } else if (f2 > f1 && g1 > g2) {
        lectura =
            'El equipo remató más en el segundo tiempo, pero convirtió en el primero.';
      } else if (f1 > f2) {
        lectura = 'El primer tiempo concentró más acciones ofensivas.';
      } else if (f2 > f1) {
        lectura = 'El segundo tiempo concentró más acciones ofensivas.';
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Comparativa ofensiva por tiempos'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            _headerRow(['Métrica', '1T (0-45 min)', '2T (46+ min)']),
            ...metrics.asMap().entries.map((entry) => _dataRow(
                  [
                    entry.value[0],
                    firstVal(entry.value[1]),
                    secondVal(entry.value[1]),
                  ],
                  alt: entry.key.isOdd,
                )),
          ],
        ),
        if (lectura != null) ...[
          pw.SizedBox(height: 5),
          _insightLine(lectura),
        ],
      ],
    );
  }

  // ── 9. Comparativa defensiva por tiempos ─────────────────────────────────
  static pw.Widget _buildComparativaDefensivaTiempos(_MatchStats stats) {
    final metrics = [
      ['Recuperaciones', EventTypes.recovery],
      ['Intercepciones', EventTypes.interception],
      ['Atajadas', EventTypes.save],
      ['Pérdidas', EventTypes.loss],
      ['Faltas', EventTypes.foul],
    ];

    final f1def = stats.firstHalfDefensivePositive;
    final f2def = stats.secondHalfDefensivePositive;
    final f1loss = stats.firstHalfCount(EventTypes.loss);
    final f2loss = stats.secondHalfCount(EventTypes.loss);

    String? lectura;
    if (f1def + f2def > 0) {
      if (f2def > f1def) {
        lectura =
            'La actividad defensiva positiva se concentró en el segundo tiempo ($f2def vs $f1def acciones).';
      } else if (f1def > f2def) {
        lectura =
            'La actividad defensiva positiva se concentró en el primer tiempo ($f1def vs $f2def acciones).';
      }
    }
    if (lectura == null && f1loss + f2loss > 0) {
      if (f1loss > f2loss) {
        lectura = 'El equipo perdió más balones en el primer tiempo ($f1loss vs $f2loss).';
      } else if (f2loss > f1loss) {
        lectura = 'El equipo perdió más balones en el segundo tiempo ($f2loss vs $f1loss).';
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Comparativa defensiva por tiempos'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            _headerRow(['Métrica', '1T (0-45 min)', '2T (46+ min)']),
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
        if (lectura != null) ...[
          pw.SizedBox(height: 5),
          _insightLine(lectura),
        ],
      ],
    );
  }

  // ── 10. Participación ofensiva individual ────────────────────────────────
  static pw.Widget _buildParticipacionOfensiva(_MatchStats stats) {
    final offensiveTypes = [
      EventTypes.goal,
      EventTypes.assist,
      EventTypes.shot,
      EventTypes.shotOnTarget,
      EventTypes.passKey,
    ];
    final players = stats.playerStats.entries
        .where((e) => offensiveTypes.any((t) => (e.value[t] ?? 0) > 0))
        .toList()
      ..sort((a, b) {
        final aPartG = (a.value[EventTypes.goal] ?? 0) + (a.value[EventTypes.assist] ?? 0);
        final bPartG = (b.value[EventTypes.goal] ?? 0) + (b.value[EventTypes.assist] ?? 0);
        if (bPartG != aPartG) return bPartG - aPartG;
        return (b.value[EventTypes.goal] ?? 0) - (a.value[EventTypes.goal] ?? 0);
      });

    if (players.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Participación ofensiva individual'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.8),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(1.2),
          },
          children: [
            _headerRow(['Jugador', 'Part.G', 'Goles', 'Asist.', 'Rem.', 'P.Clave']),
            ...players.asMap().entries.map((entry) {
              final name = entry.value.key;
              final partG = stats.playerCount(name, EventTypes.goal) +
                  stats.playerCount(name, EventTypes.assist);
              return _dataRow(
                [
                  name,
                  '$partG',
                  '${stats.playerCount(name, EventTypes.goal)}',
                  '${stats.playerCount(name, EventTypes.assist)}',
                  '${stats.playerTotalRemates(name)}',
                  '${stats.playerCount(name, EventTypes.passKey)}',
                ],
                alt: entry.key.isOdd,
              );
            }),
          ],
        ),
      ],
    );
  }

  // ── 11. Participación defensiva individual ───────────────────────────────
  static pw.Widget _buildParticipacionDefensiva(_MatchStats stats) {
    final defensiveTypes = [
      EventTypes.recovery,
      EventTypes.interception,
      EventTypes.save,
      EventTypes.loss,
      EventTypes.foul,
    ];
    final players = stats.playerStats.entries
        .where((e) => defensiveTypes.any((t) => (e.value[t] ?? 0) > 0))
        .toList()
      ..sort((a, b) {
        final ar = stats.playerADPPos(a.key);
        final br = stats.playerADPPos(b.key);
        return br - ar;
      });

    if (players.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Participación defensiva individual'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.8),
            1: const pw.FlexColumnWidth(1.2),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
            5: const pw.FlexColumnWidth(1),
          },
          children: [
            _headerRow(['Jugador', 'Recup.', 'Intercep.', 'Ataj.', 'Pérd.', 'Faltas']),
            ...players.asMap().entries.map((entry) => _dataRow(
                  [
                    entry.value.key,
                    '${stats.playerCount(entry.value.key, EventTypes.recovery)}',
                    '${stats.playerCount(entry.value.key, EventTypes.interception)}',
                    '${stats.playerCount(entry.value.key, EventTypes.save)}',
                    '${stats.playerCount(entry.value.key, EventTypes.loss)}',
                    '${stats.playerCount(entry.value.key, EventTypes.foul)}',
                  ],
                  alt: entry.key.isOdd,
                )),
          ],
        ),
      ],
    );
  }

  // ── 12. Disciplina individual ────────────────────────────────────────────
  static pw.Widget _buildDisciplinaIndividual(_MatchStats stats) {
    final discTypes = [EventTypes.foul, EventTypes.yellowCard, EventTypes.redCard];
    final players = stats.playerStats.entries
        .where((e) => discTypes.any((t) => (e.value[t] ?? 0) > 0))
        .toList()
      ..sort((a, b) {
        return stats.playerIndiceDisciplinario(b.key) -
            stats.playerIndiceDisciplinario(a.key);
      });

    if (players.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Disciplina individual'),
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
            _headerRow(['Jugador', 'Faltas', 'Amarillas', 'Rojas', 'Índice']),
            ...players.asMap().entries.map((entry) => _dataRow(
                  [
                    entry.value.key,
                    '${stats.playerCount(entry.value.key, EventTypes.foul)}',
                    '${stats.playerCount(entry.value.key, EventTypes.yellowCard)}',
                    '${stats.playerCount(entry.value.key, EventTypes.redCard)}',
                    '${stats.playerIndiceDisciplinario(entry.value.key)}',
                  ],
                  alt: entry.key.isOdd,
                )),
          ],
        ),
      ],
    );
  }

  // ── 13. Timeline ─────────────────────────────────────────────────────────
  static const _timelinePeriodOrder = [
    MatchPeriod.primerTiempo,
    MatchPeriod.segundoTiempo,
    MatchPeriod.primerTiempoAlargue,
    MatchPeriod.segundoTiempoAlargue,
  ];

  static const _timelinePeriodLabels = {
    MatchPeriod.primerTiempo: 'Primer tiempo',
    MatchPeriod.segundoTiempo: 'Segundo tiempo',
    MatchPeriod.primerTiempoAlargue: 'Alargue — 1T',
    MatchPeriod.segundoTiempoAlargue: 'Alargue — 2T',
  };

  static pw.Widget _buildTimeline(List<EventoPartidoModel> sortedEvents) {
    if (sortedEvents.isEmpty) return pw.SizedBox();

    // Group by explicit periodo field
    final Map<String, List<EventoPartidoModel>> byPeriod = {};
    final List<EventoPartidoModel> noPeriod = [];
    for (final e in sortedEvents) {
      if (e.periodo != null && e.periodo!.isNotEmpty) {
        byPeriod.putIfAbsent(e.periodo!, () => []).add(e);
      } else {
        noPeriod.add(e);
      }
    }

    // Build ordered list of (periodLabel, events) pairs
    final sections = <(String, List<EventoPartidoModel>)>[];
    for (final p in _timelinePeriodOrder) {
      final evs = byPeriod.remove(p);
      if (evs != null && evs.isNotEmpty) {
        sections.add((_timelinePeriodLabels[p] ?? p, evs));
      }
    }
    for (final entry in byPeriod.entries) {
      if (entry.value.isNotEmpty) sections.add((entry.key, entry.value));
    }
    if (noPeriod.isNotEmpty) {
      sections.add(('Sin período', noPeriod));
    }

    // Build table rows from sections
    final rows = <pw.TableRow>[_headerRow(["Min'", 'Evento'])];
    int rowIndex = 0;
    for (final section in sections) {
      final (label, evs) = section;
      // Period separator row
      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: _slate),
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: pw.Text('',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ));

      final byMinute = <int, List<EventoPartidoModel>>{};
      for (final e in evs) {
        byMinute.putIfAbsent(e.minuto, () => []).add(e);
      }
      final minutes = byMinute.keys.toList()..sort();

      for (final minute in minutes) {
        final minuteEvts = byMinute[minute]!;
        for (int i = 0; i < minuteEvts.length; i++) {
          final ev = minuteEvts[i];
          rows.add(_dataRow(
            [
              i == 0 ? "$minute'" : '',
              '${ev.tipoEventoNombre}'
                  '${ev.nombreJugador != null ? " - ${ev.nombreJugador}" : ""}',
            ],
            alt: rowIndex.isOdd,
          ));
          rowIndex++;
        }
      }
    }

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
          children: rows,
        ),
      ],
    );
  }

  // ── 14. Aspectos destacados ──────────────────────────────────────────────
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
                          pw.Text('- ',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  color: _green,
                                  fontWeight: pw.FontWeight.bold)),
                          pw.Expanded(
                            child: pw.Text(insight,
                                style: const pw.TextStyle(
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

  static pw.Widget _insightLine(String text) => pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(
          color: _rowAlt,
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        ),
        child: pw.Row(
          children: [
            pw.Text('> ',
                style: pw.TextStyle(
                    fontSize: 8, color: _green, fontWeight: pw.FontWeight.bold)),
            pw.Expanded(
              child: pw.Text(text,
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: _navy,
                      fontWeight: pw.FontWeight.bold)),
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
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.black)),
                ))
            .toList(),
      );

  // ── 15. Definición por penales ───────────────────────────────────────────
  static pw.Widget _buildDefinicionPenales(PartidoModel match) {
    const teamName = 'Kancha';
    final eq = match.resultadoPenalesEquipo ?? 0;
    final rv = match.resultadoPenalesRival ?? 0;
    final ganador = eq > rv
        ? 'Ganador: $teamName'
        : rv > eq
            ? 'Ganador: ${match.rival}'
            : 'Empate en penales';
    final ganadorColor = eq > rv ? _green : rv > eq ? _red : _muted;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('Definición por penales'),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: pw.BoxDecoration(
            color: _rowAlt,
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            children: [
              // Scoreboard
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      teamName,
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: _navy,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: const pw.BoxDecoration(color: _navy),
                    child: pw.Text(
                      '$eq  –  $rv',
                      style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      'Rival',
                      textAlign: pw.TextAlign.left,
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: _navy,
                          fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              // Winner label
              pw.Text(
                ganador,
                style: pw.TextStyle(
                    fontSize: 9,
                    color: ganadorColor,
                    fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _pct(int num, int den) {
    if (den == 0) return '-';
    return '${(num / den * 100).round()}%';
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

// =============================================================================
//  Data classes
// =============================================================================
class _Indicator {
  final String value;
  final String label;
  final String sub;
  const _Indicator({required this.value, required this.label, required this.sub});
}

class _FunnelItem {
  final String label;
  final String value;
  final String sub;
  const _FunnelItem({required this.label, required this.value, required this.sub});
}

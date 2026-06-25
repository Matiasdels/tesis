import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../models/models.dart';

class MatchReportPdfExporter {
  const MatchReportPdfExporter._();

  static Future<void> export({
    required PartidoModel match,
    required List<EventoPartidoModel> events,
  }) async {
    final doc = pw.Document();
    final golesOwn = match.golesEquipo ?? 0;
    final golesRival = match.golesRival ?? 0;
    const teamName = 'Kancha';

    final countByType = <String, int>{};
    for (final event in events) {
      countByType[event.tipoEventoNombre] =
          (countByType[event.tipoEventoNombre] ?? 0) + 1;
    }

    final goals = events
        .where((event) => event.tipoEventoNombre == EventTypes.goal)
        .toList();
    final yellowCards = events
        .where((event) => event.tipoEventoNombre == EventTypes.yellowCard)
        .toList();
    final redCards = events
        .where((event) => event.tipoEventoNombre == EventTypes.redCard)
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Text(
            'Kancha - Resumen del partido',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            match.esLocal
                ? '$teamName $golesOwn - $golesRival ${match.rival}'
                : '${match.rival} $golesRival - $golesOwn $teamName',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Fecha: ${_formatDate(match.fecha)}'),
          pw.Text('Tipo: ${match.tipoCompeticion}'),
          if (match.categoriaNombre != null)
            pw.Text('Categoria: ${match.categoriaNombre}'),
          if (match.lugar != null && match.lugar!.isNotEmpty)
            pw.Text('Lugar: ${match.lugar}'),
          pw.Text('Condicion: ${match.esLocal ? "Local" : "Visitante"}'),
          pw.SizedBox(height: 16),
          if (countByType.isNotEmpty) ...[
            pw.Text(
              'Estadisticas',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Evento',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        'Cantidad',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ...countByType.entries.map(
                  (entry) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(entry.key),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${entry.value}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
          if (goals.isNotEmpty) ...[
            pw.Text(
              'Goles',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            ...goals.map(
              (event) => pw.Text(
                "  ${event.minuto}' - ${event.nombreJugador ?? "Sin jugador"}",
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          if (yellowCards.isNotEmpty || redCards.isNotEmpty) ...[
            pw.Text(
              'Tarjetas',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            ...yellowCards.map(
              (event) => pw.Text(
                "  Amarilla - ${event.minuto}' - ${event.nombreJugador ?? "Sin jugador"}",
              ),
            ),
            ...redCards.map(
              (event) => pw.Text(
                "  Roja - ${event.minuto}' - ${event.nombreJugador ?? "Sin jugador"}",
              ),
            ),
            pw.SizedBox(height: 12),
          ],
          pw.Text(
            'Todos los eventos',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          if (events.isEmpty)
            pw.Text('No se registraron eventos.')
          else
            ...events.map(
              (event) => pw.Text(
                "  ${event.minuto}' - ${event.tipoEventoNombre}"
                '${event.nombreJugador != null ? " - ${event.nombreJugador}" : ""}',
              ),
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

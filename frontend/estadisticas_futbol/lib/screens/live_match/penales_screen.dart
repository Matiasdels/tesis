import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/event_api.dart';
import '../../data/remote/match_api.dart';
import '../../data/remote/penal_api.dart';
import '../../models/models.dart';

// =============================================================================
//  PENALES SCREEN
// =============================================================================

class PenalesScreen extends StatefulWidget {
  final int matchId;
  const PenalesScreen({super.key, required this.matchId});

  @override
  State<PenalesScreen> createState() => _PenalesScreenState();
}

class _PenalesScreenState extends State<PenalesScreen> {
  final _matchApi = MatchApi();
  final _penalApi = PenalApi();
  final _eventApi = EventApi();

  PartidoModel? _partido;
  Set<int> _expulsados = {};
  List<AlineacionEntradaModel> _jugadoresHabilitados = [];

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  final _equipoCtrl = TextEditingController();
  final _rivalCtrl = TextEditingController();

  final List<_EntradaDetalle> _detalles = [];
  bool _mostrarDetalle = false;
  List<String> _erroresDetalle = [];

  String get _token => context.read<AuthState>().session!.accessToken;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _equipoCtrl.dispose();
    _rivalCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _matchApi.getMatch(widget.matchId, _token),
        _matchApi.getLineup(widget.matchId, _token),
        _eventApi.getEventos(widget.matchId, _token, syncPending: false),
      ]);
      if (!mounted) return;
      final eventos = results[2] as List<EventoPartidoModel>;
      final expulsados = eventos
          .where((e) =>
              e.jugadorId != null &&
              e.tipoEventoNombre == EventTypes.redCard)
          .map((e) => e.jugadorId!)
          .toSet();
      final lineup = results[1] as List<AlineacionEntradaModel>;
      setState(() {
        _partido = results[0] as PartidoModel;
        _expulsados = expulsados;
        _jugadoresHabilitados =
            lineup.where((j) => !expulsados.contains(j.jugadorId)).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'No se pudo cargar el partido. Intentá nuevamente.';
        _loading = false;
      });
    }
  }

  // ── Resultado ──────────────────────────────────────────────────────────────

  int? get _equipoScore => int.tryParse(_equipoCtrl.text.trim());
  int? get _rivalScore => int.tryParse(_rivalCtrl.text.trim());

  String? get _errorResultado {
    final e = _equipoScore;
    final r = _rivalScore;
    if (e == null || r == null) return null;
    if (e < 0 || r < 0) return 'Los valores no pueden ser negativos.';
    if (e == r) return 'El resultado en penales no puede terminar en empate.';
    final maxVal = e > r ? e : r;
    final diff = (e - r).abs();
    if (maxVal > 5 && diff != 1) {
      return 'Resultado imposible: cuando algún equipo supera 5 goles '
          'la diferencia debe ser exactamente 1.';
    }
    final minVal = e < r ? e : r;
    if (maxVal == 5 && minVal < 3) {
      return 'Resultado imposible: con 5 goles, el rival debe haber convertido al menos 3.';
    }
    if (maxVal == 4 && minVal == 0) {
      return 'Resultado imposible: con 4 goles, el rival debe haber convertido al menos 1.';
    }
    return null;
  }

  String? get _ganador {
    final e = _equipoScore;
    final r = _rivalScore;
    if (e == null || r == null || _errorResultado != null) return null;
    if (e > r) return 'Kancha';
    if (r > e) return _partido?.rival ?? 'Rival';
    return null;
  }

  bool get _puedeGuardar {
    final e = _equipoScore;
    final r = _rivalScore;
    return e != null &&
        r != null &&
        e >= 0 &&
        r >= 0 &&
        e != r &&
        _errorResultado == null;
  }

  // ── Detalle: jugadores disponibles por fila ────────────────────────────────

  // Jugadores que pueden seleccionarse en la posición [index], respetando la
  // rotación por vueltas. El jugador ya seleccionado en esa fila siempre aparece.
  List<AlineacionEntradaModel> _jugadoresDisponiblesEn(int index) {
    final hab = _jugadoresHabilitados;
    if (hab.isEmpty) return hab;

    final usadosEnVuelta = <int>{};
    for (var i = 0; i < index; i++) {
      final d = _detalles[i];
      if (d.equipo != 'Propio' || d.jugadorId == null) continue;
      if (usadosEnVuelta.length == hab.length) usadosEnVuelta.clear();
      usadosEnVuelta.add(d.jugadorId!);
    }

    final seleccionActual =
        index < _detalles.length ? _detalles[index].jugadorId : null;
    return hab
        .where((j) =>
            !usadosEnVuelta.contains(j.jugadorId) ||
            j.jugadorId == seleccionActual)
        .toList();
  }

  // ── Detalle: validaciones ──────────────────────────────────────────────────

  List<String> _calcularErroresDetalle() {
    if (!_mostrarDetalle || _detalles.isEmpty) return [];
    final errores = <String>[];
    final hab = _jugadoresHabilitados;
    final habIds = hab.map((j) => j.jugadorId).toSet();

    // 1. Sin expulsados ni jugadores ajenos al plantel
    for (var i = 0; i < _detalles.length; i++) {
      final d = _detalles[i];
      if (d.equipo != 'Propio' || d.jugadorId == null) continue;
      if (_expulsados.contains(d.jugadorId)) {
        errores.add(
            'Ejecución #${i + 1}: el jugador fue expulsado y no puede ejecutar.');
      } else if (hab.isNotEmpty && !habIds.contains(d.jugadorId)) {
        errores.add(
            'Ejecución #${i + 1}: el jugador no pertenece al plantel habilitado.');
      }
    }
    if (errores.isNotEmpty) return errores;

    // 3. Alternancia
    for (var i = 1; i < _detalles.length; i++) {
      if (_detalles[i].equipo == _detalles[i - 1].equipo) {
        errores.add(
            'Los equipos deben alternar sus ejecuciones (error en ejecución #${i + 1}).');
        return errores;
      }
    }

    // 4. Rotación de ejecutantes
    if (hab.isNotEmpty) {
      final usadosEnVuelta = <int>{};
      for (var i = 0; i < _detalles.length; i++) {
        final d = _detalles[i];
        if (d.equipo != 'Propio' || d.jugadorId == null) continue;
        if (usadosEnVuelta.length == hab.length) usadosEnVuelta.clear();
        if (usadosEnVuelta.contains(d.jugadorId)) {
          errores.add(
              'Ejecución #${i + 1}: este jugador ya ejecutó en esta vuelta.');
          return errores;
        }
        usadosEnVuelta.add(d.jugadorId!);
      }
    }

    // 5. Goles del detalle coinciden con el resultado
    final golesEquipo = _detalles
        .where((d) => d.equipo == 'Propio' && d.resultado == 'Gol')
        .length;
    final golesRival = _detalles
        .where((d) => d.equipo == 'Rival' && d.resultado == 'Gol')
        .length;
    if (_equipoScore != null && golesEquipo != _equipoScore) {
      errores.add(
          'Los goles del equipo en el detalle ($golesEquipo) no coinciden con el resultado ($_equipoScore).');
    }
    if (_rivalScore != null && golesRival != _rivalScore) {
      errores.add(
          'Los goles del rival en el detalle ($golesRival) no coinciden con el resultado ($_rivalScore).');
    }
    if (errores.isNotEmpty) return errores;

    // 6. Progresión reglamentaria de la serie
    final serieError = _validarProgresionSerie();
    if (serieError != null) errores.add(serieError);

    return errores;
  }

  String? _validarProgresionSerie() {
    if (_detalles.isEmpty) return null; // L4: 1 entrada cae al chequeo de incompleta

    int gA = 0, gB = 0, sA = 0, sB = 0;
    var ultimaEjecucionDefineLaTanda = false;
    final primerEquipo = _detalles[0].equipo; // L3: quién inicia define quién cierra cada pareja

    for (var i = 0; i < _detalles.length; i++) {
      final esA = _detalles[i].equipo == 'Propio'; // L3: basado en dato, no en paridad
      final esUltimoDePar = _detalles[i].equipo != primerEquipo; // L3: cierra pareja quien no inició
      final gol = _detalles[i].resultado == 'Gol';

      if (esA) {
        sA++;
        if (gol) gA++;
      } else {
        sB++;
        if (gol) gB++;
      }

      bool terminada = false;

      if (sA <= 5 && sB <= 5) {
        // Serie inicial: detección anticipada
        final rA = 5 - sA;
        final rB = 5 - sB;
        terminada = gA > gB + rB || gB > gA + rA;
      } else if (sA > 5 && sB > 5 && sA == sB && esUltimoDePar) {
        // Muerte súbita: termina al completar una pareja con diferencia
        terminada = gA != gB;
      }

      if (terminada && i < _detalles.length - 1) {
        return 'La tanda ya estaba definida en la ejecución #${i + 1}. Las posteriores son inválidas.'; // L2
      }

      ultimaEjecucionDefineLaTanda = terminada;
    }

    if (!ultimaEjecucionDefineLaTanda) {
      return 'La serie está incompleta: la última ejecución no define al ganador.';
    }

    return null;
  }

  // ── Guardar ────────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_puedeGuardar) return;

    if (_mostrarDetalle && _detalles.isNotEmpty) {
      final errores = _calcularErroresDetalle();
      if (errores.isNotEmpty) {
        setState(() => _erroresDetalle = errores);
        return;
      }
    }

    setState(() {
      _saving = true;
      _erroresDetalle = [];
    });

    final detallePayload = _mostrarDetalle
        ? _detalles
            .asMap()
            .entries
            .map((e) => {
                  'equipo': e.value.equipo,
                  if (e.value.jugadorId != null) 'jugadorId': e.value.jugadorId,
                  'resultado': e.value.resultado,
                  'orden': e.key + 1,
                })
            .toList()
        : <Map<String, dynamic>>[];

    final payload = {
      'resultadoPenalesEquipo': _equipoScore!,
      'resultadoPenalesRival': _rivalScore!,
      'detalle': detallePayload,
    };

    try {
      final partido = await _penalApi.guardarPenales(
        partidoId: widget.matchId,
        resultadoPenalesEquipo: _equipoScore!,
        resultadoPenalesRival: _rivalScore!,
        detalle: _mostrarDetalle
            ? _detalles
                .asMap()
                .entries
                .map((e) => PenalDetalleModel(
                      partidoId: widget.matchId,
                      equipo: e.value.equipo,
                      jugadorId: e.value.jugadorId,
                      resultado: e.value.resultado,
                      orden: e.key + 1,
                    ))
                .toList()
            : [],
        accessToken: _token,
      );
      await DatabaseHelper.instance.saveJson(
        'matches:item:${widget.matchId}',
        partido.toApiJson()
          ..['huboPenales'] = true
          ..['resultadoPenalesEquipo'] = _equipoScore
          ..['resultadoPenalesRival'] = _rivalScore
          ..['estado'] = 'Finalizado',
      );
    } catch (_) {
      await DatabaseHelper.instance
          .saveJson('match:${widget.matchId}:penal_result', payload);
      await DatabaseHelper.instance.deletePendingMatchEstado(widget.matchId);
      await DatabaseHelper.instance.enqueueSyncAction(
        entity: 'penal_resultado',
        action: 'guardar',
        method: 'POST',
        endpoint: '/api/Partidos/${widget.matchId}/penales',
        payload: payload,
      );
    }

    if (mounted) {
      context.go('/matches/${widget.matchId}/summary');
    }
  }

  void _agregarDetalle() {
    setState(() {
      _detalles.add(_EntradaDetalle(equipo: 'Propio', resultado: 'Gol'));
      _erroresDetalle = [];
    });
  }

  void _eliminarDetalle(int index) {
    setState(() {
      _detalles.removeAt(index);
      _erroresDetalle = [];
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null || _partido == null) {
      return Scaffold(
        backgroundColor: AppColors.bgDeep,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                _loadError ?? 'Partido no encontrado',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final partido = _partido!;
    final homeScore = partido.esLocal
        ? partido.golesEquipo ?? 0
        : partido.golesRival ?? 0;
    final awayScore = partido.esLocal
        ? partido.golesRival ?? 0
        : partido.golesEquipo ?? 0;

    final golesDetalleEquipo = _detalles
        .where((d) => d.equipo == 'Propio' && d.resultado == 'Gol')
        .length;
    final golesDetalleRival = _detalles
        .where((d) => d.equipo == 'Rival' && d.resultado == 'Gol')
        .length;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Definición por penales',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Marcador reglamentario ──────────────────────────────────────
          _Card(
            child: Column(
              children: [
                Text(
                  'RESULTADO REGLAMENTARIO',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TeamLabel(
                        name: partido.esLocal ? 'Kancha' : partido.rival),
                    Text(
                      partido.esLocal
                          ? '$homeScore  —  $awayScore'
                          : '$awayScore  —  $homeScore',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    _TeamLabel(
                        name: partido.esLocal ? partido.rival : 'Kancha'),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.4),
                        width: 0.5),
                  ),
                  child: const Text(
                    'Empate — definición por penales',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Resultado en penales ────────────────────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resultado en penales',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresá los goles convertidos en la tanda.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _ScoreInput(
                        label: 'Kancha',
                        controller: _equipoCtrl,
                        onChanged: (_) =>
                            setState(() => _erroresDetalle = []),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '—',
                        style: TextStyle(
                            fontSize: 28,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w300),
                      ),
                    ),
                    Expanded(
                      child: _ScoreInput(
                        label: partido.rival,
                        controller: _rivalCtrl,
                        onChanged: (_) =>
                            setState(() => _erroresDetalle = []),
                      ),
                    ),
                  ],
                ),
                if (_ganador != null) ...[
                  const SizedBox(height: 16),
                  _InfoBadge(
                    icon: Icons.emoji_events_rounded,
                    text: 'Ganador: $_ganador',
                    color: AppColors.accent,
                  ),
                ],
                if (_errorResultado != null) ...[
                  const SizedBox(height: 12),
                  _InfoBadge(
                    icon: Icons.error_outline_rounded,
                    text: _errorResultado!,
                    color: AppColors.danger,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Detalle de ejecuciones (opcional) ──────────────────────────
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _mostrarDetalle = !_mostrarDetalle;
                    _erroresDetalle = [];
                  }),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Registrar detalle de la tanda',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Opcional — registrá quién pateó cada penal.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _mostrarDetalle
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
                if (_mostrarDetalle) ...[
                  const SizedBox(height: 14),

                  // Counters
                  if (_detalles.isNotEmpty) ...[
                    _CounterRow(
                      propios: _detalles
                          .where((d) => d.equipo == 'Propio')
                          .length,
                      rivales: _detalles
                          .where((d) => d.equipo == 'Rival')
                          .length,
                      golesEquipo: golesDetalleEquipo,
                      golesRival: golesDetalleRival,
                      resultadoEquipo: _equipoScore,
                      resultadoRival: _rivalScore,
                    ),
                    const SizedBox(height: 10),
                  ],

                  ..._detalles.asMap().entries.map(
                        (e) => _DetalleRow(
                          index: e.key,
                          entry: e.value,
                          jugadoresDisponibles:
                              _jugadoresDisponiblesEn(e.key),
                          expulsados: _expulsados,
                          tieneLineup: _jugadoresHabilitados.isNotEmpty,
                          onChanged: () =>
                              setState(() => _erroresDetalle = []),
                          onDelete: () => _eliminarDetalle(e.key),
                        ),
                      ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _agregarDetalle,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Agregar ejecución'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: BorderSide(
                            color: AppColors.borderDefault, width: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Errores de detalle ──────────────────────────────────────────
          if (_erroresDetalle.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.4),
                    width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: AppColors.danger, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Correcciones necesarias',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._erroresDetalle.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $e',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Guardar ────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _puedeGuardar && !_saving ? _guardar : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.sports_score_rounded),
              label: Text(_saving ? 'Guardando...' : 'Guardar y finalizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// =============================================================================
//  WIDGETS
// =============================================================================

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault, width: 0.5),
      ),
      child: child,
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoBadge(
      {required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _CounterRow extends StatelessWidget {
  final int propios;
  final int rivales;
  final int golesEquipo;
  final int golesRival;
  final int? resultadoEquipo;
  final int? resultadoRival;

  const _CounterRow({
    required this.propios,
    required this.rivales,
    required this.golesEquipo,
    required this.golesRival,
    this.resultadoEquipo,
    this.resultadoRival,
  });

  @override
  Widget build(BuildContext context) {
    final equipoOk =
        resultadoEquipo == null || golesEquipo == resultadoEquipo;
    final rivalOk = resultadoRival == null || golesRival == resultadoRival;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgMuted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ejecuciones  —  Propio: $propios  |  Rival: $rivales',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Goles registrados  —  Kancha: $golesEquipo  |  Rival: $golesRival',
                style: TextStyle(
                  fontSize: 11,
                  color: (equipoOk && rivalOk)
                      ? AppColors.textMuted
                      : AppColors.warning,
                ),
              ),
              if (!equipoOk || !rivalOk) ...[
                const SizedBox(width: 4),
                const Icon(Icons.warning_amber_rounded,
                    size: 13, color: AppColors.warning),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamLabel extends StatelessWidget {
  final String name;
  const _TeamLabel({required this.name});

  @override
  Widget build(BuildContext context) {
    final abbr = name.length >= 3
        ? name.substring(0, 3).toUpperCase()
        : name.toUpperCase();
    return Column(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.bgMuted,
          child: Text(abbr,
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Text(name,
            style:
                TextStyle(fontSize: 11, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _ScoreInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _ScoreInput({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style:
                TextStyle(fontSize: 12, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(
                fontSize: 32,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w300),
            filled: true,
            fillColor: AppColors.bgMuted,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: AppColors.borderDefault, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: AppColors.borderDefault, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _DetalleRow extends StatelessWidget {
  final int index;
  final _EntradaDetalle entry;
  final List<AlineacionEntradaModel> jugadoresDisponibles;
  final Set<int> expulsados;
  final bool tieneLineup;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _DetalleRow({
    required this.index,
    required this.entry,
    required this.jugadoresDisponibles,
    required this.expulsados,
    required this.tieneLineup,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final esExpulsado =
        entry.jugadorId != null && expulsados.contains(entry.jugadorId);
    final tieneError = esExpulsado;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tieneError
              ? AppColors.danger.withValues(alpha: 0.5)
              : AppColors.borderSubtle,
          width: tieneError ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close_rounded,
                    size: 16, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Equipo
          Row(
            children: [
              Text('Equipo:',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              _ToggleChip(
                label: 'Kancha',
                selected: entry.equipo == 'Propio',
                color: AppColors.accent,
                onTap: () {
                  entry.equipo = 'Propio';
                  onChanged();
                },
              ),
              const SizedBox(width: 6),
              _ToggleChip(
                label: 'Rival',
                selected: entry.equipo == 'Rival',
                color: AppColors.info,
                onTap: () {
                  entry.equipo = 'Rival';
                  entry.jugadorId = null;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Resultado
          Row(
            children: [
              Text('Resultado:',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              _ToggleChip(
                label: 'Gol',
                selected: entry.resultado == 'Gol',
                color: AppColors.accent,
                onTap: () {
                  entry.resultado = 'Gol';
                  onChanged();
                },
              ),
              const SizedBox(width: 6),
              _ToggleChip(
                label: 'Errado',
                selected: entry.resultado == 'Errado',
                color: AppColors.danger,
                onTap: () {
                  entry.resultado = 'Errado';
                  onChanged();
                },
              ),
            ],
          ),
          // Pateador — opcional, solo visible cuando la ejecución es Propio
          if (entry.equipo == 'Propio') ...[
            const SizedBox(height: 8),
            if (!tieneLineup)
              Text(
                'No hay jugadores asociados al partido.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              )
            else ...[
              DropdownButtonFormField<int?>(
                initialValue: entry.jugadorId,
                decoration: InputDecoration(
                  labelText: 'Pateador (opcional)',
                  labelStyle: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.borderSubtle, width: 0.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                dropdownColor: AppColors.bgSurface,
                style: TextStyle(
                    fontSize: 13, color: AppColors.textPrimary),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      '— Sin especificar —',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  ...jugadoresDisponibles.map((j) =>
                      DropdownMenuItem<int?>(
                        value: j.jugadorId,
                        child: Text(j.nombreJugador),
                      )),
                  if (esExpulsado)
                    DropdownMenuItem<int?>(
                      value: entry.jugadorId,
                      child: const Text(
                        'Jugador expulsado',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                ],
                onChanged: (val) {
                  entry.jugadorId = val;
                  onChanged();
                },
              ),
              if (esExpulsado) ...[
                const SizedBox(height: 4),
                const Text(
                  'Este jugador fue expulsado y no puede ejecutar.',
                  style: TextStyle(fontSize: 11, color: AppColors.danger),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.18)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : AppColors.borderDefault,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? color : AppColors.textMuted,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _EntradaDetalle {
  String equipo;
  int? jugadorId;
  String resultado;

  _EntradaDetalle({required this.equipo, required this.resultado});
}

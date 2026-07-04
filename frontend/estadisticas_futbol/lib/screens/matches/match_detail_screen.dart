import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/match_api.dart';
import '../../models/models.dart';
import '../../widgets/common/app_widgets.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;
  final PlayerMatchModel? playerContext;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
    this.playerContext,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final _api = MatchApi();

  PartidoModel? _match;
  List<AlineacionEntradaModel> _lineup = [];
  bool _loading = true;
  bool _changed = false;
  bool _starting = false;
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
      final match = await _api.getMatch(widget.matchId, token);
      final lineup = await _api.getLineup(widget.matchId, token);
      if (!mounted) return;
      setState(() {
        _match = match;
        _lineup = lineup;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar el partido. Intente nuevamente.';
        _loading = false;
      });
    }
  }

  Future<void> _startMatch() async {
    final match = _match!;
    setState(() => _starting = true);
    try {
      final token = context.read<AuthState>().session!.accessToken;
      if (match.isProgramado) {
        try {
          await _api.patchEstado(match.id, 'EnJuego', token);
          _changed = true;
        } catch (_) {
          // El endpoint puede no estar disponible aún; igual navegamos
        }
      }
      if (!mounted) return;
      await context.push('/matches/live/${match.id}');
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Eliminar partido',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          '¿Estás seguro de que querés eliminar este partido? Esta acción no se puede deshacer.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final token = context.read<AuthState>().session!.accessToken;
      await _api.deleteMatch(widget.matchId, token);
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos eliminar el partido.')),
        );
      }
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
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.bgSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop(_changed);
              } else {
                context.go(AppConstants.routeMatches);
              }
            },
          ),
          title: Text(
            match.rival,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar partido',
              onPressed: () async {
                final updated =
                    await context.push<bool>('/matches/${match.id}/edit');
                if (updated == true) {
                  _changed = true;
                  _load();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar partido',
              onPressed: _delete,
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppConstants.pagePadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (widget.playerContext != null) ...[
                _PlayerParticipationCard(playerMatch: widget.playerContext!),
                const SizedBox(height: AppConstants.sectionSpacing),
              ],
              _MatchInfoCard(match: match),
              const SizedBox(height: AppConstants.sectionSpacing),
              _LineupCard(
                lineup: _lineup,
                onManage: () async {
                  final updated =
                      await context.push<bool>('/matches/${match.id}/lineup');
                  if (updated == true) {
                    _changed = true;
                    _load();
                  }
                },
              ),
              const SizedBox(height: AppConstants.sectionSpacing),
              _MatchActionButton(
                match: match,
                loading: _starting,
                onStart: _startMatch,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MatchInfoCard extends StatelessWidget {
  final PartidoModel match;
  const _MatchInfoCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Datos del partido'),
          const SizedBox(height: 10),
          _DataRow('Rival', match.rival),
          _DataRow('Fecha', _formatDate(match.fecha)),
          _DataRow('Tipo', match.tipoCompeticion),
          _DataRow('Condición', match.esLocal ? 'Local' : 'Visitante'),
          _DataRow('Categoría', match.categoriaNombre ?? '-'),
          _DataRow('Lugar', match.lugar ?? '-'),
          _DataRow('Estado', match.estado),
          if (match.isFinished && match.golesEquipo != null) ...[
            _DataRow(
              'Resultado',
              '${match.golesEquipo} - ${match.golesRival}',
            ),
          ],
        ],
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

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  const _DataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineupCard extends StatelessWidget {
  final List<AlineacionEntradaModel> lineup;
  final VoidCallback onManage;

  const _LineupCard({required this.lineup, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final titulares = lineup.where((a) => a.esTitular).toList();
    final suplentes = lineup.where((a) => !a.esTitular).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Alineación',
            action: lineup.isEmpty ? 'Cargar' : 'Editar',
            onAction: onManage,
          ),
          const SizedBox(height: 10),
          if (lineup.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Todavía no se cargó la alineación.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          else ...[
            if (titulares.isNotEmpty) ...[
              _SectionLabel('Titulares (${titulares.length})'),
              ...titulares.map((a) => _PlayerTile(entry: a)),
            ],
            if (suplentes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SectionLabel('Suplentes (${suplentes.length})'),
              ...suplentes.map((a) => _PlayerTile(entry: a)),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MatchActionButton extends StatelessWidget {
  final PartidoModel match;
  final bool loading;
  final VoidCallback onStart;

  const _MatchActionButton({
    required this.match,
    required this.loading,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    if (match.isFinished) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/matches/${match.id}/summary'),
          icon: const Icon(Icons.bar_chart_rounded, size: 20),
          label: const Text('Ver resumen del partido'),
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
      );
    }

    final isEnJuego = match.isEnJuego;
    final label = isEnJuego ? 'Continuar partido en vivo' : 'Iniciar partido';
    final icon = isEnJuego ? Icons.sports_soccer : Icons.play_arrow_rounded;
    final color = isEnJuego ? AppColors.accent : AppColors.accent;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onStart,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          ),
        ),
      ),
    );
  }
}

class _PlayerParticipationCard extends StatelessWidget {
  final PlayerMatchModel playerMatch;

  const _PlayerParticipationCard({required this.playerMatch});

  @override
  Widget build(BuildContext context) {
    final s = playerMatch.estadisticas;
    final rol = playerMatch.esTitular
        ? (playerMatch.posicionAsignada != null &&
                playerMatch.posicionAsignada!.isNotEmpty
            ? 'Titular · ${playerMatch.posicionAsignada}'
            : 'Titular')
        : 'Suplente';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(title: 'Participacion del jugador'),
              ),
              _RolBadgeSmall(esTitular: playerMatch.esTitular, label: rol),
            ],
          ),
          const SizedBox(height: 10),
          if (!s.hasActivity)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No se registraron eventos para este jugador en este partido.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            )
          else ...[
            if (s.goles > 0)
              _StatRow(
                  'Goles', s.goles, Icons.sports_soccer_outlined),
            if (s.asistencias > 0)
              _StatRow(
                  'Asistencias', s.asistencias, Icons.assistant_outlined),
            if (s.remates > 0)
              _StatRow('Remates', s.remates, Icons.gps_fixed_outlined),
            if (s.faltas > 0)
              _StatRow('Faltas', s.faltas, Icons.warning_amber_outlined),
            if (s.amarillas > 0)
              _StatRow('Tarjetas amarillas', s.amarillas,
                  Icons.crop_square_outlined),
            if (s.rojas > 0)
              _StatRow(
                  'Tarjetas rojas', s.rojas, Icons.square_outlined),
          ],
        ],
      ),
    );
  }
}

class _RolBadgeSmall extends StatelessWidget {
  final bool esTitular;
  final String label;

  const _RolBadgeSmall({required this.esTitular, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = esTitular ? AppColors.accent : AppColors.textSecondary;
    final bg = esTitular ? AppColors.accentDim : AppColors.bgMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final AlineacionEntradaModel entry;
  const _PlayerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: entry.esTitular ? AppColors.accentDim : AppColors.infoDim,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                entry.esTitular ? 'T' : 'S',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      entry.esTitular ? AppColors.accent : AppColors.info,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.nombreJugador,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
          if (entry.posicionAsignada != null)
            Text(
              entry.posicionAsignada!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/remote/auth_state.dart';
import '../../data/remote/estadisticas_api.dart';
import '../../models/estadisticas_model.dart';
import '../../widgets/common/app_widgets.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final _api = EstadisticasApi();

  ResumenGlobalModel? _data;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = context.read<AuthState>().session!.accessToken;
      final data  = await _api.getResumenGlobal(token);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.signal_wifi_off_rounded,
                  title: 'No se pudieron cargar las estadísticas',
                  subtitle: _error ?? 'Error desconocido',
                  actionLabel: 'Reintentar',
                  onAction: _load,
                )
              : _buildContent(_data!),
    );
  }

  Widget _buildContent(ResumenGlobalModel data) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.bgSurface,
          title: Text('Estadísticas',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded,
                  size: 20, color: AppColors.textSecondary),
              onPressed: _load,
              tooltip: 'Actualizar',
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (data.partidosJugados == 0)
                _EmptyDashboard()
              else ...[
                _ResumenCard(data: data),
                const SizedBox(height: 14),
                _RendimientoCard(items: data.rendimientoReciente),
                const SizedBox(height: 14),
                _TopJugadoresCard(
                  title: 'Top goleadores',
                  icon: Icons.sports_soccer_rounded,
                  items: data.topGoleadores,
                  emptyText: 'No hay goles registrados',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 14),
                _TopJugadoresCard(
                  title: 'Top asistidores',
                  icon: Icons.assistant_rounded,
                  items: data.topAsistidores,
                  emptyText: 'No hay asistencias registradas',
                  color: AppColors.info,
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  RESUMEN GENERAL
// =============================================================================

class _ResumenCard extends StatelessWidget {
  final ResumenGlobalModel data;
  const _ResumenCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final diff = data.diferenciaGoles;
    final diffText = diff > 0 ? '+$diff' : '$diff';
    final pct = '${data.porcentajeVictorias.toStringAsFixed(1)} %';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Resumen general'),
          const SizedBox(height: 12),
          _StatRow('Partidos jugados', '${data.partidosJugados}'),
          _StatRow('Victorias',  '${data.victorias}',  color: AppColors.accent),
          _StatRow('Empates',    '${data.empates}'),
          _StatRow('Derrotas',   '${data.derrotas}',   color: AppColors.danger),
          const Divider(height: 16),
          _StatRow('Goles', '${data.golesFavor} – ${data.golesContra}'),
          _StatRow('Diferencia', diffText,
              color: diff > 0
                  ? AppColors.accent
                  : diff < 0 ? AppColors.danger : null),
          _StatRow('% victorias', pct,
              color: data.porcentajeVictorias >= 50 ? AppColors.accent : null),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}

// =============================================================================
//  RENDIMIENTO RECIENTE
// =============================================================================

class _RendimientoCard extends StatelessWidget {
  final List<RendimientoRecienteItem> items;
  const _RendimientoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Rendimiento reciente'),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text('Todavía no hay partidos finalizados.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
          else
            Row(
              children: items
                  .map<Widget>((item) => _ResultChip(item: item))
                  .expand((w) => [w, const SizedBox(width: 8)])
                  .toList()
                ..removeLast(),
            ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final RendimientoRecienteItem item;
  const _ResultChip({required this.item});

  Color get _color => switch (item.resultado) {
        'G' => AppColors.accent,
        'E' => AppColors.warning,
        _   => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${item.rival}  ${item.golesFavor}–${item.golesContra}',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withValues(alpha: 0.5)),
        ),
        alignment: Alignment.center,
        child: Text(
          item.resultado,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _color),
        ),
      ),
    );
  }
}

// =============================================================================
//  TOP JUGADORES
// =============================================================================

class _TopJugadoresCard extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<TopJugadorItem> items;
  final String       emptyText;
  final Color        color;

  const _TopJugadoresCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            trailing: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(emptyText,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary))
          else
            ...items.asMap().entries.map(
                  (entry) => _TopRow(
                    rank:  entry.key + 1,
                    item:  entry.value,
                    color: color,
                  ),
                ),
        ],
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  final int          rank;
  final TopJugadorItem item;
  final Color        color;

  const _TopRow({required this.rank, required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$rank.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.nombre,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${item.cantidad}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  ESTADO VACÍO
// =============================================================================

class _EmptyDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.sports_soccer_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Sin datos todavía',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            'Las estadísticas aparecen aquí\ncuando finalizan los partidos.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

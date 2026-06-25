import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/models.dart';

// ── Stat KPI card ──────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final StatCardData data;
  final Color? accentColor;

  const StatCard({super.key, required this.data, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(data.value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: color, height: 1)),
          if (data.delta != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                if (data.deltaPositive != null)
                  Icon(
                    data.deltaPositive! ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 11,
                    color: data.deltaPositive! ? AppColors.accent : AppColors.danger,
                  ),
                const SizedBox(width: 2),
                Text(data.delta!,
                    style: TextStyle(
                      fontSize: 10,
                      color: data.deltaPositive == null
                          ? AppColors.textMuted
                          : (data.deltaPositive! ? AppColors.accent : AppColors.danger),
                    )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (trailing != null) trailing!,
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.info,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(action!, style: const TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

// ── App card ───────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;

  const AppCard({super.key, required this.child, this.padding, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      ),
      child: child,
    );
  }
}

// ── Player avatar circle ───────────────────────────────────────────────────

class PlayerAvatar extends StatelessWidget {
  final PlayerModel player;
  final double radius;

  const PlayerAvatar({super.key, required this.player, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.infoDim,
      child: Text(
        player.initials,
        style: TextStyle(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.w500,
          color: AppColors.info,
        ),
      ),
    );
  }
}

// ── Status badge ───────────────────────────────────────────────────────────

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (status) {
      'available'  => ('Disponible', AppColors.accent,   AppColors.accentDim),
      'injured'    => ('Lesionado',  AppColors.danger,   AppColors.dangerDim),
      'suspended'  => ('Suspendido', AppColors.warning,  AppColors.warningDim),
      'live'       => ('En vivo',    AppColors.danger,   AppColors.dangerDim),
      'upcoming'   => ('Próximo',    AppColors.info,     AppColors.infoDim),
      'finished'   => ('Finalizado', AppColors.textMuted,AppColors.bgMuted),
      _            => (status,       AppColors.textMuted,AppColors.bgMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ── Form result indicator ──────────────────────────────────────────────────

class FormBadge extends StatelessWidget {
  final String result; // 'V' | 'E' | 'D'
  const FormBadge({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (result) {
      'V' => (AppColors.accent,   AppColors.accentDim),
      'E' => (AppColors.warning,  AppColors.warningDim),
      _   => (AppColors.danger,   AppColors.dangerDim),
    };

    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5)),
      alignment: Alignment.center,
      child: Text(result, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    );
  }
}

// ── Horizontal divider with label ──────────────────────────────────────────

class LabeledDivider extends StatelessWidget {
  final String label;
  const LabeledDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.borderSubtle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ),
        const Expanded(child: Divider(color: AppColors.borderSubtle)),
      ],
    );
  }
}

// ── Metric bar row ─────────────────────────────────────────────────────────

class MetricBarRow extends StatelessWidget {
  final String label;
  final double value; // 0.0–1.0
  final String displayValue;
  final Color color;

  const MetricBarRow({
    super.key,
    required this.label,
    required this.value,
    required this.displayValue,
    this.color = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 5,
                backgroundColor: AppColors.borderDefault,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(displayValue,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Page scaffold with consistent header ───────────────────────────────────

class PageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final bool showBack;

  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.body,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        toolbarHeight: subtitle == null ? 66 : 78,
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        leading: showBack ? const BackButton() : null,
        automaticallyImplyLeading: showBack,
        titleSpacing: showBack ? 0 : 16,
        title: Row(
          children: [
            Container(
              width: 4,
              height: subtitle == null ? 34 : 44,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.05,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: actions != null
            ? [...actions!, const SizedBox(width: 10)]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.borderSubtle,
                  AppColors.accent.withValues(alpha: 0.35),
                  AppColors.borderSubtle,
                ],
              ),
            ),
          ),
        ),
      ),
      body: body,
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';
import '../jobs/jobs_screen.dart';
import '../shell/home_shell.dart';

/// "Manufacturer Overview" — body of the DASH tab.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
        children: [
          _Header(active: app.activeJobs.length, delayed: app.atRiskJobs.length),
          const SizedBox(height: 16),
          const _QuickActions(),
          const SizedBox(height: 20),
          _StageMetrics(counts: [for (final m in _metrics) app.jobs.where((j) => m.stages.contains(j.stage)).length]),
          const SizedBox(height: 16),
          _PriorityOrders(jobs: app.priorityJobs()),
          const SizedBox(height: 16),
          _ActionQueue(items: List.of(app.actions)),
          const SizedBox(height: 16),
          _RecentActivity(items: app.activity.take(6).toList()),
        ],
      ),
    );
  }
}

void _goProduction() => homeTab.value = HomeTabs.production;

void _openJob(BuildContext context, String id) => Navigator.pushNamed(context, Routes.job, arguments: id);

class _Metric {
  const _Metric(this.label, this.stages);

  final String label;
  final List<JobStage> stages;
}

const _metrics = [
  _Metric('CAD Wait', [JobStage.cad]),
  _Metric('Approval Wait', [JobStage.approval, JobStage.pricing, JobStage.finalApproval]),
  _Metric('In Wax', [JobStage.wax]),
  _Metric('At Casting', [JobStage.casting]),
  _Metric('Assembly', [JobStage.assembly]),
  _Metric('Setting', [JobStage.setting]),
  _Metric('In QC', [JobStage.polishing, JobStage.qc]),
  _Metric('Certification', [JobStage.certification]),
];

class _Header extends StatelessWidget {
  const _Header({required this.active, required this.delayed});

  final int active;
  final int delayed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Manufacturer Overview', style: AppText.headlineLg),
        const SizedBox(height: 4),
        Text(
          'Current operational status across all production stages.',
          style: AppText.bodyMd.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 16),
        DhCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Total(
                    label: 'Total Active',
                    value: '$active',
                    onTap: () {
                      jobsFilter.value = JobsFilter.active;
                      homeTab.value = HomeTabs.orders;
                    },
                  ),
                ),
                VerticalDivider(width: 24, color: c.border),
                Expanded(
                  child: _Total(
                    label: 'Total Delayed',
                    value: '$delayed',
                    color: c.danger,
                    onTap: () {
                      jobsFilter.value = JobsFilter.atRisk;
                      homeTab.value = HomeTabs.orders;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.onTap, this.color});

  final String label;
  final String value;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: AppText.labelSm.copyWith(color: c.textMuted, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(value, style: AppText.headlineLg.copyWith(color: color ?? c.text)),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.edit_note,
              label: 'Create Inquiry',
              onTap: () => Navigator.pushNamed(context, Routes.inquiry),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAction(
              icon: Icons.local_fire_department_outlined,
              label: 'Caster View',
              onTap: () => Navigator.pushNamed(context, Routes.casting),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _QuickAction(
              icon: Icons.hub_outlined,
              label: 'Partners',
              onTap: () => Navigator.pushNamed(context, Routes.partners),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: c.accent),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelMd.copyWith(color: c.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageMetrics extends StatelessWidget {
  const _StageMetrics({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      color: c.isDark ? c.surfaceLow : c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Stage Metrics',
            icon: Icons.analytics_outlined,
            action: 'View All Stages',
            onAction: _goProduction,
          ),
          const SizedBox(height: 12),
          OptionLayout(
            columns: 2,
            spacing: 10,
            children: [
              for (var i = 0; i < _metrics.length; i++)
                MetricTile(
                  label: _metrics[i].label,
                  value: '${counts[i]}',
                  color: _metrics[i].stages.first.color,
                  onTap: _goProduction,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityOrders extends StatelessWidget {
  const _PriorityOrders({required this.jobs});

  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = c.isDark ? c.surfaceHigh : c.action;
    final fg = c.isDark ? c.text : c.onAction;
    final glow = c.isDark ? c.gold : c.onAction;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: c.isDark ? Border.all(color: c.gold.withValues(alpha: 0.35)) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -48,
            top: -48,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [glow.withValues(alpha: 0.14), glow.withValues(alpha: 0)]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.priority_high, color: c.isDark ? c.gold : fg),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Priority Orders', style: AppText.headlineSm.copyWith(color: fg)),
                    ),
                    Text('≤ 48H', style: AppText.monoCaps.copyWith(color: fg.withValues(alpha: 0.6))),
                  ],
                ),
                const SizedBox(height: 14),
                if (jobs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nothing due in the next 48 hours.',
                      style: AppText.bodyMd.copyWith(color: fg.withValues(alpha: 0.7)),
                    ),
                  ),
                for (final j in jobs) ...[
                  _PriorityTile(job: j, fg: fg),
                  if (j != jobs.last) const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityTile extends StatelessWidget {
  const _PriorityTile({required this.job, required this.fg});

  final Job job;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = job.daysUntilDue;
    final Color due;
    if (d <= 0) {
      due = c.isDark ? c.danger : c.dangerSoft;
    } else if (d == 1) {
      due = c.isDark ? c.gold : c.goldSoft;
    } else {
      due = c.isDark ? c.info : c.accentSoft;
    }
    return Material(
      color: fg.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _openJob(context, job.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(job.id, style: AppText.monoLg.copyWith(color: fg)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: due.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(Fmt.dueTag(d), style: AppText.monoSm.copyWith(color: due, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                job.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: fg.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: job.progress.clamp(0.04, 1.0).toDouble(),
                        child: Container(
                          decoration: BoxDecoration(color: due, borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(job.stage.short.toUpperCase(), style: AppText.monoSm.copyWith(color: fg.withValues(alpha: 0.7))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionQueue extends StatelessWidget {
  const _ActionQueue({required this.items});

  final List<ActionItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      color: c.isDark ? c.surfaceLow : c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_late_outlined, size: 20, color: c.danger),
              const SizedBox(width: 8),
              Expanded(child: Text('Action Queue', style: AppText.headlineSm)),
              if (items.isNotEmpty) StatusChip('${items.length} open', color: c.danger),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const EmptyState(icon: Icons.task_alt, message: 'All caught up — nothing needs your action.'),
          for (final a in items) ...[_ActionTile(item: a), if (a != items.last) const SizedBox(height: 10)],
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.item});

  final ActionItem item;

  (IconData, Color) _style(DhColors c) => switch (item.kind) {
    ActionKind.cadReview => (Icons.draw_outlined, c.info),
    ActionKind.pricing => (Icons.payments_outlined, c.gold),
    ActionKind.delay => (Icons.warning_amber_rounded, c.danger),
    ActionKind.missing => (Icons.diamond_outlined, c.danger),
    ActionKind.certification => (Icons.verified_outlined, c.accent),
  };

  void _run(BuildContext context) {
    switch (item.kind) {
      case ActionKind.cadReview:
        Navigator.pushNamed(context, Routes.cadReview, arguments: item.jobId);
      case ActionKind.pricing:
        Navigator.pushNamed(context, Routes.pricing, arguments: item.jobId);
      case ActionKind.delay:
        _openJob(context, item.jobId);
      case ActionKind.missing:
        _resolve(context);
      case ActionKind.certification:
        Navigator.pushNamed(context, Routes.shipping, arguments: item.jobId);
    }
  }

  Future<void> _resolve(BuildContext context) async {
    const options = ['Stones located in vault', 'Re-ordered from supplier', 'Customer to resupply'];
    var choice = options.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Resolve Issue'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.title, style: AppText.titleMd.copyWith(color: ctx.c.text)),
                const SizedBox(height: 4),
                Text(item.subtitle),
                const SizedBox(height: 16),
                const SectionLabel('Resolution'),
                const SizedBox(height: 8),
                ChoiceGroup<String>(
                  options: options,
                  selected: choice,
                  columns: 1,
                  dense: true,
                  onChanged: (v) => setDialog(() => choice = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: ctx.c.textMuted)),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark Resolved')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final job = app.jobById(item.jobId);
    if (job != null) app.addEvent(job, title: 'Issue resolved', text: '${item.title}: $choice.');
    app.dismissAction(item);
    showSnack(context, 'Resolved for ${item.jobId} — $choice', icon: Icons.check_circle_outline);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, color) = _style(c);
    return Material(
      color: c.isDark ? c.surface : c.surfaceLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openJob(context, item.jobId),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
                            child: Icon(icon, size: 20, color: color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(item.subtitle, style: AppText.bodySm.copyWith(color: c.textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(width: 52),
                          Expanded(
                            child: Text(item.jobId, style: AppText.monoMd.copyWith(color: c.accent)),
                          ),
                          FilledButton(
                            onPressed: () => _run(context),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              textStyle: AppText.labelMd.copyWith(fontSize: 13),
                            ),
                            child: Text(item.cta),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.items});

  final List<ActivityItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      color: c.isDark ? c.surfaceLow : c.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Recent Activity', style: AppText.headlineSm),
          const SizedBox(height: 16),
          if (items.isEmpty) const EmptyState(icon: Icons.history, message: 'No activity yet.'),
          for (var i = 0; i < items.length; i++)
            _ActivityTile(
              item: items[i],
              dot: i == 0 ? c.accent : (i == 1 ? c.accent.withValues(alpha: 0.35) : c.borderStrong),
              isLast: i == items.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.dot, required this.isLast});

  final ActivityItem item;
  final Color dot;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: () => _openJob(context, item.jobId),
      borderRadius: BorderRadius.circular(6),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 12,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 1, margin: const EdgeInsets.only(top: 4), color: c.border),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${item.text} '),
                          TextSpan(
                            text: item.jobId,
                            style: AppText.monoMd.copyWith(color: c.accent),
                          ),
                        ],
                      ),
                      style: AppText.bodyMd.copyWith(color: c.text),
                    ),
                    const SizedBox(height: 2),
                    Text('${Fmt.ago(item.time)} • ${item.by}', style: AppText.bodySm.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

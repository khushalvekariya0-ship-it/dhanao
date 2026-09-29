import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _fullDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${Fmt.dateLong(d)}';

/// Whole calendar days from [a] to [b] (DST-safe).
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

class DeliveryRequirementsScreen extends StatefulWidget {
  const DeliveryRequirementsScreen({super.key});

  @override
  State<DeliveryRequirementsScreen> createState() => _DeliveryRequirementsScreenState();
}

class _DeliveryRequirementsScreenState extends State<DeliveryRequirementsScreen> {
  JobDraft get d => app.draft;

  bool get _certified => d.certificate != 'No Certificate';

  int get _bufferDays => 2 + (_certified ? 3 : 0) + (d.hardDeadline ? 2 : 0);

  DateTime? get _completion {
    final r = d.requestedDelivery;
    return r == null ? null : DateTime(r.year, r.month, r.day - _bufferDays);
  }

  @override
  void initState() {
    super.initState();
    // Carry over a date captured in the quick-spec flow.
    d.requestedDelivery ??= d.deliveryDate;
  }

  void _continue() {
    if (d.requestedDelivery == null) {
      showSnack(context, 'Select a requested delivery date to continue', icon: Icons.event_outlined);
      return;
    }
    Navigator.pushNamed(context, Routes.quality);
  }

  void _setPriority(Priority p) => setState(() => d.priority = p);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final now = DateTime.now();
    final single = d.quantity <= 1;
    final requested = d.requestedDelivery;
    final completion = _completion;
    final daysLeft = completion == null ? null : _daysBetween(now, completion);
    return WizardScaffold(
      title: 'Step 3: Timeline',
      step: 3,
      totalSteps: 4,
      stepLabel: 'Delivery',
      badge: 'Draft',
      ctaLabel: 'Define Quality Requirements',
      onCta: _continue,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.surfaceLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(Icons.precision_manufacturing_outlined, size: 18, color: c.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'JOB TYPE: ${d.jobType.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelMd.copyWith(letterSpacing: 0.8, color: c.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              Text('QTY ${d.quantity}', style: AppText.monoCaps.copyWith(color: c.textFaint)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Requested Delivery Date', style: AppText.headlineSm),
        const SizedBox(height: 2),
        Text('When do you need the final parts on-site?', style: AppText.bodySm.copyWith(color: c.textMuted)),
        const SizedBox(height: 12),
        DateField(
          value: requested,
          hint: 'Select Date',
          firstDate: requested != null && requested.isBefore(now) ? requested : now,
          onChanged: (v) => setState(() => d.requestedDelivery = v),
        ),
        if (requested != null) ...[
          const SizedBox(height: 6),
          Text('${_daysBetween(now, requested)} days from today', style: AppText.monoSm.copyWith(color: c.textFaint)),
        ],
        const SizedBox(height: 16),
        DhCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ToggleRow(
            title: 'Hard Deadline',
            subtitle: 'Cannot accept delivery after requested date.',
            value: d.hardDeadline,
            onChanged: (v) => setState(() => d.hardDeadline = v),
          ),
        ),
        const SizedBox(height: 12),
        Opacity(
          opacity: single ? 0.55 : 1,
          child: IgnorePointer(
            ignoring: single,
            child: DhCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ToggleRow(
                title: 'Partial Delivery Allowed',
                subtitle: single ? 'Single-unit order — ships complete.' : 'Ship batches as they are ready.',
                value: !single && d.partialDelivery,
                onChanged: (v) => setState(() => d.partialDelivery = v),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Priority Level', style: AppText.headlineSm),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PriorityTile(
                  icon: Icons.local_shipping_outlined,
                  label: 'Standard',
                  caption: '4–6 WKS',
                  color: c.isDark ? c.gold : c.accent,
                  soft: c.accentSoft,
                  selected: d.priority == Priority.standard,
                  onTap: () => _setPriority(Priority.standard),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriorityTile(
                  icon: Icons.rocket_launch_outlined,
                  label: 'Rush',
                  caption: '2–3 WKS',
                  color: c.warning,
                  soft: c.warningSoft,
                  selected: d.priority == Priority.rush,
                  onTap: () => _setPriority(Priority.rush),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PriorityTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Critical',
                  caption: '< 2 WKS',
                  color: c.danger,
                  soft: c.dangerSoft,
                  selected: d.priority == Priority.critical,
                  onTap: () => _setPriority(Priority.critical),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _timelinePreview(c, requested, completion, daysLeft),
        if (daysLeft != null && daysLeft < 14) ...[const SizedBox(height: 16), _warning(c, daysLeft)],
      ],
    );
  }

  Widget _timelinePreview(DhColors c, DateTime? requested, DateTime? completion, int? daysLeft) {
    final accent = c.isDark ? c.gold : c.accent;
    return DhCard(
      color: c.isDark ? c.surface : c.surfaceLow,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 20, color: accent),
              const SizedBox(width: 8),
              Text('Timeline Preview', style: AppText.headlineSm),
            ],
          ),
          const SizedBox(height: 18),
          _Node(
            dot: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: c.surface,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REQUESTED DELIVERY', style: AppText.labelSm.copyWith(color: c.textMuted)),
                const SizedBox(height: 2),
                Text(
                  requested == null ? 'Select date' : _fullDate(requested),
                  style: requested == null ? AppText.titleMd : AppText.monoLg.copyWith(color: c.text),
                ),
              ],
            ),
          ),
          _Node(
            child: Column(
              children: [
                const _BufferRow(icon: Icons.local_shipping_outlined, label: 'Dispatch Buffer', days: 2),
                if (_certified) ...[
                  const SizedBox(height: 8),
                  const _BufferRow(icon: Icons.verified_outlined, label: 'Certification Buffer', days: 3),
                ],
                if (d.hardDeadline) ...[
                  const SizedBox(height: 8),
                  const _BufferRow(icon: Icons.event_busy_outlined, label: 'Hard Deadline Safety', days: 2),
                ],
              ],
            ),
          ),
          _Node(
            isLast: true,
            dot: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: c.text, shape: BoxShape.circle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.isDark ? c.goldSoft : c.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RECOMMENDED COMPLETION',
                              style: AppText.labelSm.copyWith(color: c.isDark ? c.gold : c.text),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              completion == null ? 'Pending' : _fullDate(completion),
                              style: completion == null
                                  ? AppText.titleMd
                                  : AppText.monoLg.copyWith(color: c.text, fontWeight: FontWeight.w700),
                            ),
                            if (daysLeft != null)
                              Text(
                                daysLeft < 0 ? '${-daysLeft} days ago' : 'in $daysLeft days',
                                style: AppText.monoSm.copyWith(color: c.textMuted),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.flag_outlined, color: c.isDark ? c.gold : c.text),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Target production completion to meet requested delivery date.',
                  style: AppText.bodySm.copyWith(color: c.textFaint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _warning(DhColors c, int daysLeft) {
    final past = daysLeft < 0;
    final color = past ? c.danger : c.warning;
    final suggestion = past ? Priority.critical : Priority.rush;
    return DhCard(
      color: past ? c.dangerSoft : c.warningSoft,
      borderColor: color.withValues(alpha: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(past ? 'Timeline not feasible' : 'Tight production window', style: AppText.titleMd),
                const SizedBox(height: 4),
                Text(
                  past
                      ? 'Recommended completion has already passed. Choose a later delivery date or escalate to '
                            'Critical.'
                      : 'Only $daysLeft day${daysLeft == 1 ? '' : 's'} to complete production — standard lead time '
                            'is 14+ days. Consider Rush priority.',
                  style: AppText.bodySm.copyWith(color: c.textMuted),
                ),
                if (d.priority.index < suggestion.index) ...[
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () {
                      _setPriority(suggestion);
                      showSnack(context, 'Priority set to ${suggestion.label}', icon: Icons.rocket_launch_outlined);
                    },
                    icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                    label: Text(past ? 'Mark as Critical' : 'Switch to Rush'),
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
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
  const _PriorityTile({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.soft,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final Color soft;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? soft : (c.isDark ? c.surface : c.surfaceLow),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? color : c.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: selected ? color : c.textMuted),
              const SizedBox(height: 8),
              Text(label, style: AppText.labelMd.copyWith(fontSize: 13, color: c.text)),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoSm.copyWith(fontSize: 10, color: c.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the timeline rail. Without a [dot] the rail runs straight through.
class _Node extends StatelessWidget {
  const _Node({required this.child, this.dot, this.isLast = false});

  final Widget child;
  final Widget? dot;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                if (dot != null) Padding(padding: const EdgeInsets.only(top: 3), child: dot),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: c.border),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _BufferRow extends StatelessWidget {
  const _BufferRow({required this.icon, required this.label, required this.days});

  final IconData icon;
  final String label;
  final int days;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(icon, size: 16, color: c.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: AppText.bodySm.copyWith(color: c.textMuted)),
        ),
        Text('− $days Days', style: AppText.monoMd.copyWith(color: c.text)),
      ],
    );
  }
}

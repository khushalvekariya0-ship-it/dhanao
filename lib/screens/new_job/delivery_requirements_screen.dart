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
      actions: const [_ProfileButton()],
      ctaLabel: 'Define Quality Requirements',
      onCta: _continue,
      padding: EdgeInsets.zero,
      children: [
        // Full-bleed job context strip.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: c.isDark ? c.surface : c.surfaceLow,
            border: Border(bottom: BorderSide(color: c.border)),
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
                  style: AppText.labelMd.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8, color: c.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'Draft',
                  style: AppText.labelSm.copyWith(fontWeight: FontWeight.w700, color: c.isDark ? c.gold : c.text),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Requested Delivery Date', style: AppText.headlineSm),
              const SizedBox(height: 2),
              Text('When do you need the final parts on-site?', style: AppText.bodySm.copyWith(color: c.textMuted)),
              const SizedBox(height: 16),
              _DateButton(value: requested, onChanged: (v) => setState(() => d.requestedDelivery = v)),
              if (requested != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${_daysBetween(now, requested)} days from today',
                  style: AppText.monoSm.copyWith(color: c.textFaint),
                ),
              ],
              const SizedBox(height: 24),
              _ToggleCard(
                title: 'Hard Deadline',
                subtitle: 'Cannot accept delivery after requested date.',
                value: d.hardDeadline,
                onChanged: (v) => setState(() => d.hardDeadline = v),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: single ? 0.55 : 1,
                child: IgnorePointer(
                  ignoring: single,
                  child: _ToggleCard(
                    title: 'Partial Delivery Allowed',
                    subtitle: single ? 'Single-unit order — ships complete.' : 'Ship batches as they are ready.',
                    value: !single && d.partialDelivery,
                    onChanged: (v) => setState(() => d.partialDelivery = v),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text('Priority Level', style: AppText.headlineSm),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _PriorityTile(
                        icon: Icons.local_shipping_outlined,
                        label: 'Standard',
                        caption: '4–6 WKS',
                        color: c.isDark ? c.gold : c.text,
                        soft: c.accentSoft,
                        selected: d.priority == Priority.standard,
                        onTap: () => _setPriority(Priority.standard),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PriorityTile(
                        icon: Icons.rocket_launch_outlined,
                        label: 'Rush',
                        caption: '2–3 WKS',
                        color: c.isDark ? c.warning : c.accent,
                        soft: c.isDark ? c.warningSoft : c.accentSoft,
                        selected: d.priority == Priority.rush,
                        onTap: () => _setPriority(Priority.rush),
                      ),
                    ),
                    const SizedBox(width: 12),
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
              if (daysLeft != null && daysLeft < 14) ...[const SizedBox(height: 16), _warning(c, daysLeft)],
            ],
          ),
        ),
        _timelinePreview(c, requested, completion, daysLeft),
      ],
    );
  }

  /// Full-bleed recessed "Timeline Preview" section.
  Widget _timelinePreview(DhColors c, DateTime? requested, DateTime? completion, int? daysLeft) {
    final accent = c.isDark ? c.gold : c.accent;
    final value = AppText.bodyLg.copyWith(fontWeight: FontWeight.w600, color: c.text);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceLow : c.surfaceLow,
        border: Border(top: BorderSide(color: c.border)),
      ),
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
          const SizedBox(height: 20),
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
                Text(
                  'REQUESTED DELIVERY',
                  style: AppText.bodySm.copyWith(fontWeight: FontWeight.w500, letterSpacing: 1, color: c.textMuted),
                ),
                Text(requested == null ? 'Select date' : _fullDate(requested), style: value),
              ],
            ),
          ),
          _Node(
            child: Column(
              children: [
                const _BufferRow(icon: Icons.local_shipping_outlined, label: 'Dispatch Buffer', days: 2),
                if (_certified) ...[
                  const SizedBox(height: 12),
                  const _BufferRow(icon: Icons.verified_outlined, label: 'Certification Buffer', days: 3),
                ],
                if (d.hardDeadline) ...[
                  const SizedBox(height: 12),
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
              decoration: BoxDecoration(color: c.isDark ? c.gold : c.text, shape: BoxShape.circle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: c.isDark ? c.goldSoft : c.accentSoft,
                    borderRadius: BorderRadius.circular(8),
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
                              style: AppText.bodySm.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                                color: c.isDark ? c.gold : c.text,
                              ),
                            ),
                            Text(
                              completion == null ? 'Pending' : _fullDate(completion),
                              style: value.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (daysLeft != null)
                              Text(
                                daysLeft < 0 ? '${-daysLeft} days ago' : 'in $daysLeft days',
                                style: AppText.monoSm.copyWith(color: c.textMuted),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.flag_outlined, color: c.isDark ? c.gold : c.text),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: Text(
                    'Target production completion to meet requested delivery date.',
                    style: AppText.labelSm.copyWith(fontWeight: FontWeight.w500, color: c.textMuted),
                  ),
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

/// Resting fill of the design's tonal cards (surface-container).
Color _fill(DhColors c) => c.isDark ? c.surface : c.surfaceHigh.withValues(alpha: 0.7);

List<BoxShadow>? _shadow(DhColors c, {bool raised = false}) => c.isDark
    ? null
    : [
        BoxShadow(
          color: c.text.withValues(alpha: raised ? 0.12 : 0.06),
          blurRadius: raised ? 8 : 3,
          offset: Offset(0, raised ? 3 : 1),
        ),
      ];

/// The design's black "profile" button at the right of the step header.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'Profile & settings',
        child: Material(
          color: c.action,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.settings),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(dimension: 34, child: Icon(Icons.person_outline, size: 20, color: c.onAction)),
          ),
        ),
      ),
    );
  }
}

/// Large tonal "Select Date" button that opens a date picker.
class _DateButton extends StatelessWidget {
  const _DateButton({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final v = value;
    // showDatePicker asserts first <= initial <= last; widen the range for old/far values.
    var first = v != null && v.isBefore(now) ? v : now;
    var last = now.add(const Duration(days: 730));
    final initial = v ?? now.add(const Duration(days: 30));
    if (initial.isBefore(first)) first = initial;
    if (initial.isAfter(last)) last = initial;
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = value;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: _shadow(c)),
      child: Material(
        color: _fill(c),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: c.isDark ? c.gold : c.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      v == null ? 'Select Date' : _fullDate(v),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w500, color: c.text),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: c.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tonal card with title/subtitle and a primary-coloured switch.
class _ToggleCard extends StatelessWidget {
  const _ToggleCard({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: _shadow(c)),
      child: Material(
        color: _fill(c),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppText.bodyLg.copyWith(fontWeight: FontWeight.w500, color: c.text),
                      ),
                      Text(subtitle, style: AppText.bodySm.copyWith(color: c.textMuted)),
                    ],
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  trackColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected) ? c.action : c.borderStrong,
                  ),
                  trackOutlineColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected) ? c.action : c.borderStrong,
                  ),
                  thumbColor: WidgetStateProperty.resolveWith(
                    (s) => s.contains(WidgetState.selected) ? c.onAction : (c.isDark ? c.textFaint : c.surface),
                  ),
                ),
              ],
            ),
          ),
        ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: _shadow(c, raised: selected),
      ),
      child: Material(
        color: selected ? soft : _fill(c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: c.isDark && selected ? BorderSide(color: color.withValues(alpha: 0.6)) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: selected ? color : c.textMuted),
                const SizedBox(height: 8),
                Text(label, style: AppText.labelMd.copyWith(fontSize: 13, color: selected ? c.text : c.textMuted)),
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
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: c.borderStrong.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
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
        Text(
          '- $days Days',
          style: AppText.bodySm.copyWith(fontWeight: FontWeight.w500, color: c.text),
        ),
      ],
    );
  }
}

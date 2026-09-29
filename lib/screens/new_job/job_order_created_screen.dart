import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';
import '../shell/home_shell.dart';

const _lifecycle = ['Requirements Definition', 'CAD Development', 'Design Approval', 'Manufacturing', 'Delivered'];

/// Index of the current lifecycle phase for [s] (all phases done when delivered).
int _phaseOf(JobStage s) {
  if (s == JobStage.delivered) return _lifecycle.length;
  if (!s.isBefore(JobStage.wax)) return 3;
  if (!s.isBefore(JobStage.approval)) return 2;
  return 1;
}

class JobOrderCreatedScreen extends StatefulWidget {
  const JobOrderCreatedScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobOrderCreatedScreen> createState() => _JobOrderCreatedScreenState();
}

class _JobOrderCreatedScreenState extends State<JobOrderCreatedScreen> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final AnimationController _ping = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..repeat();
  late final CurvedAnimation _scale = CurvedAnimation(parent: _enter, curve: Curves.elasticOut);
  late final CurvedAnimation _fade = CurvedAnimation(parent: _enter, curve: const Interval(0, 0.4));

  @override
  void dispose() {
    _scale.dispose();
    _fade.dispose();
    _enter.dispose();
    _ping.dispose();
    super.dispose();
  }

  DateTime _cadDue(Job job) {
    final now = DateTime.now();
    final minDue = DateTime(now.year, now.month, now.day + 7);
    final byDelivery = DateTime(job.dueDate.year, job.dueDate.month, job.dueDate.day - 21);
    return byDelivery.isBefore(minDue) ? minDue : byDelivery;
  }

  void _toDashboard() {
    Navigator.popUntil(context, (r) => r.isFirst);
    homeTab.value = HomeTabs.dashboard;
  }

  Future<void> _assign(Job job) async {
    final designers = app.partners.where((p) {
      final role = p.role.toLowerCase();
      return role.contains('cad') || role.contains('designer');
    }).toList();
    final picked = await showModalBottomSheet<Partner>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DesignerSheet(designers: designers, current: job.assignee),
    );
    if (picked == null || !mounted) return;
    final note = 'Assigned to ${picked.name} for CAD development.';
    job.assignee = picked.name;
    if (job.stage == JobStage.inquiry) {
      app.setStage(job, JobStage.cad, note: note);
    } else {
      app.addEvent(job, title: 'CAD designer assigned', text: note);
    }
    showSnack(context, 'Assigned to ${picked.name}', icon: Icons.check_circle_outline);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final job = app.jobOrDefault(widget.jobId);
        final phase = _phaseOf(job.stage);
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: Text('Confirmation', style: AppText.headlineSm),
            actions: [
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _header(c, job),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _nextStepCard(c, job),
                    const SizedBox(height: 28),
                    const SectionLabel('Production Lifecycle'),
                    const SizedBox(height: 14),
                    for (var i = 0; i < _lifecycle.length; i++)
                      PipelineTile(
                        title: _lifecycle[i],
                        subtitle: i == 1 && phase <= 1
                            ? (job.assignee == null ? 'Awaiting Assignment' : 'Assigned to ${job.assignee}')
                            : null,
                        state: i < phase
                            ? PipelineState.done
                            : (i == phase ? PipelineState.current : PipelineState.pending),
                        isLast: i == _lifecycle.length - 1,
                      ),
                    const SizedBox(height: 28),
                    SecondaryButton(
                      'View Job',
                      icon: Icons.open_in_new,
                      onPressed: () => Navigator.pushReplacementNamed(context, Routes.job, arguments: job.id),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 24),
                    TextButton(
                      onPressed: _toDashboard,
                      style: TextButton.styleFrom(foregroundColor: c.text, minimumSize: const Size(0, 48)),
                      child: Text(
                        'RETURN TO DASHBOARD',
                        style: AppText.labelMd.copyWith(fontSize: 13, letterSpacing: 1.0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(DhColors c, Job job) {
    final accent = c.isDark ? c.gold : c.accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      decoration: BoxDecoration(
        color: c.surfaceLow,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _ping,
                  builder: (_, _) => Opacity(
                    opacity: (1 - _ping.value) * 0.7,
                    child: Transform.scale(
                      scale: 1 + _ping.value * 0.45,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
                FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: c.accentSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
                      ),
                      child: Icon(Icons.check_circle, size: 36, color: accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                Text('Job Order Created', textAlign: TextAlign.center, style: AppText.headlineMd),
                const SizedBox(height: 6),
                SelectableText(
                  job.id,
                  textAlign: TextAlign.center,
                  style: AppText.monoLg.copyWith(fontSize: 18, color: c.textMuted, letterSpacing: 1),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('APPROVED • READY', style: AppText.labelMd.copyWith(letterSpacing: 1.0, color: accent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextStepCard(DhColors c, Job job) {
    final assignee = job.assignee;
    final partner = assignee == null ? null : app.partnerByName(assignee);
    return DhCard(
      color: c.isDark ? c.surface : c.surfaceLow,
      accentTop: c.isDark,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline, size: 20, color: c.isDark ? c.gold : c.accent),
              const SizedBox(width: 8),
              Text('Next Step', style: AppText.headlineSm),
            ],
          ),
          const SizedBox(height: 14),
          Text('CAD Development', style: AppText.titleMd),
          const SizedBox(height: 8),
          Row(
            children: [
              if (assignee == null) ...[
                Icon(Icons.person_off_outlined, size: 16, color: c.warning),
                const SizedBox(width: 4),
                Text('Unassigned', style: AppText.bodySm.copyWith(color: c.warning)),
              ] else ...[
                DhAvatar(asset: partner?.avatar, name: assignee, size: 22),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    assignee,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm.copyWith(color: c.text, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const Spacer(),
              Icon(Icons.event_outlined, size: 16, color: c.textMuted),
              const SizedBox(width: 4),
              Text('Due ${Fmt.date(_cadDue(job))}', style: AppText.monoSm.copyWith(color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 16),
          if (assignee == null)
            PrimaryButton('ASSIGN CAD DESIGNER', icon: Icons.person_add_outlined, onPressed: () => _assign(job))
          else
            SecondaryButton('Change Designer', icon: Icons.swap_horiz, onPressed: () => _assign(job)),
        ],
      ),
    );
  }
}

class _DesignerSheet extends StatelessWidget {
  const _DesignerSheet({required this.designers, required this.current});

  final List<Partner> designers;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Assign CAD Designer', style: AppText.headlineSm),
            const SizedBox(height: 4),
            Text(
              'Routes the specs to the designer and moves the job into CAD development.',
              style: AppText.bodySm.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 12),
            if (designers.isEmpty)
              const EmptyState(
                icon: Icons.person_search_outlined,
                message: 'No CAD designers in your partner network.',
              ),
            for (final p in designers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DhCard(
                  onTap: () => Navigator.pop(context, p),
                  borderColor: p.name == current ? c.accent : null,
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      DhAvatar(asset: p.avatar, name: p.name, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
                            Text(
                              [p.role, ?p.company].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodySm.copyWith(color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${p.activeJobs}', style: AppText.monoLg.copyWith(color: c.text)),
                          Text('ACTIVE', style: AppText.monoCaps.copyWith(fontSize: 9, color: c.textFaint)),
                        ],
                      ),
                      if (p.name == current) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle, size: 20, color: c.accent),
                      ],
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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Order workflow tracker: hero render, key specs and the six-step
/// manufacturing pipeline with "Mark Complete" on the active step.
class WorkflowTrackerScreen extends StatefulWidget {
  const WorkflowTrackerScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<WorkflowTrackerScreen> createState() => _WorkflowTrackerScreenState();
}

class _Step {
  const _Step(this.label, this.activity, this.defaultBy, this.defaultDate);

  final String label;
  final String activity;
  final String defaultBy;
  final String defaultDate;
}

class _WorkflowTrackerScreenState extends State<WorkflowTrackerScreen> with SingleTickerProviderStateMixin {
  static const _steps = [
    _Step('CAD Design', 'Designer refining the 3D model for client approval.', 'JD', 'Oct 12'),
    _Step('3D Printing', 'Resin wax model printing on PR-02.', 'PR-02', 'Oct 13'),
    _Step('Casting', 'Casting house pouring metal into the investment flask.', 'Forge-A', 'Oct 14'),
    _Step('Stone Setting', 'Bench jeweler currently mounting main diamond.', 'Bench 4', 'Oct 15'),
    _Step('Polishing', 'Final polish and surface finishing in progress.', 'Polish-1', 'Oct 16'),
    _Step('Final QC & Hallmarking', 'Inspection against CAD, weight check and hallmark stamping.', 'QC-1', 'Oct 17'),
  ];

  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  /// Pipeline step index for a stage; 6 = every step complete.
  static int _stepOf(JobStage s) => switch (s) {
    JobStage.inquiry || JobStage.cad || JobStage.approval || JobStage.pricing || JobStage.finalApproval => 0,
    JobStage.wax => 1,
    JobStage.casting => 2,
    JobStage.assembly || JobStage.setting => 3,
    JobStage.polishing => 4,
    JobStage.qc || JobStage.certification => 5,
    JobStage.dispatch || JobStage.delivered => 6,
  };

  /// "Completed by X • Oct 12" from the job history, else the design default.
  static String _completedLine(Job job, int step) {
    StageEvent? entry;
    StageEvent? exit;
    for (final e in job.history) {
      final s = _stepOf(e.stage);
      if (s == step && e.stage != JobStage.inquiry && entry == null) entry = e;
      if (s > step && exit == null) exit = e;
    }
    final d = _steps[step];
    final by = entry?.by ?? d.defaultBy;
    final at = exit?.at ?? entry?.at;
    return 'Completed by $by • ${at == null ? d.defaultDate : Fmt.date(at)}';
  }

  void _replay() {
    _spin.forward(from: 0);
    showSnack(context, 'Replaying 360° turntable view', icon: Icons.threesixty);
  }

  void _markComplete(Job job) {
    final next = app.advance(job);
    showSnack(
      context,
      next == null ? '${job.id} is already complete' : '${job.id} moved to ${next.label}',
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final job = app.jobOrDefault(widget.jobId);
        final image = job.image ?? Img.ringGoldRender;
        final w = job.weightGrams;
        return DetailScaffold(
          title: 'Workflow',
          subtitle: job.id,
          actions: [
            IconButton(
              tooltip: 'Open job',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => Navigator.pushNamed(context, Routes.job, arguments: job.id),
            ),
          ],
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORDER #${job.id}',
                          style: AppText.monoCaps.copyWith(color: c.textFaint, fontSize: 13, letterSpacing: 2),
                        ),
                        const SizedBox(height: 4),
                        Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.headlineMd),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusChip(
                    job.stage == JobStage.delivered ? 'Delivered' : 'In ${job.stage.short}',
                    color: c.accent,
                    dot: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _hero(image),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SpecTile(
                      icon: Icons.drive_file_rename_outline,
                      label: 'Metal',
                      value: Text(job.metal, style: AppText.monoLg.copyWith(color: c.text)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SpecTile(
                      icon: Icons.scale_outlined,
                      label: 'Weight',
                      value: Text.rich(
                        TextSpan(
                          text: w == null ? '—' : '${w.toStringAsFixed(1)}g',
                          style: AppText.monoLg.copyWith(color: c.text),
                          children: [
                            if (w != null)
                              TextSpan(
                                text: ' (Est.)',
                                style: AppText.monoSm.copyWith(color: c.gold),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _SpecTile(
                icon: Icons.diamond_outlined,
                label: 'Main Stone',
                value: Text(job.centerStone, style: AppText.monoLg.copyWith(color: c.text)),
                onTap: () => Navigator.pushNamed(context, Routes.orderDetails, arguments: job.id),
              ),
              const SizedBox(height: 20),
              _pipeline(job),
            ],
          ),
        );
      },
    );
  }

  Widget _hero(String image) {
    final c = context.c;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceLow : c.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GridPainter(c.gold.withValues(alpha: 0.18))),
            AnimatedBuilder(
              animation: _spin,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(Curves.easeInOut.transform(_spin.value) * 2 * math.pi),
                child: child,
              ),
              child: GestureDetector(
                onTap: () => _openViewer(context, image),
                child: Image.asset(image, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _RoundButton(icon: Icons.view_in_ar, tooltip: '3D view', onTap: () => _openViewer(context, image)),
                  const SizedBox(height: 8),
                  _RoundButton(icon: Icons.threesixty, tooltip: 'Replay turntable', onTap: _replay),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pipeline(Job job) {
    final c = context.c;
    final current = _stepOf(job.stage);
    return DhCard(
      color: c.isDark ? c.surfaceHigh : c.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.route, color: c.accent),
              const SizedBox(width: 8),
              const Expanded(child: Text('Manufacturing Pipeline', style: AppText.titleMd)),
            ],
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _steps.length; i++)
            if (i < current)
              PipelineTile(
                title: _steps[i].label,
                subtitle: _completedLine(job, i),
                mono: true,
                isLast: i == _steps.length - 1,
              )
            else if (i == current)
              PipelineTile(
                title: _steps[i].label,
                mono: true,
                state: PipelineState.current,
                isLast: i == _steps.length - 1,
                trailing: StatusChip('In Progress', color: c.accent),
                child: _CurrentStepBox(
                  activity: _steps[i].activity,
                  stage: job.stage,
                  onComplete: () => _markComplete(job),
                ),
              )
            else
              Opacity(
                opacity: 0.6,
                child: PipelineTile(
                  title: _steps[i].label,
                  subtitle: 'Pending',
                  mono: true,
                  state: PipelineState.pending,
                  isLast: i == _steps.length - 1,
                ),
              ),
          if (current >= _steps.length) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.successSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.success.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, color: c.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All manufacturing steps complete. ${job.stage.label}.',
                      style: AppText.bodySm.copyWith(color: c.text),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, Routes.shipping, arguments: job.id),
                    child: const Text('Shipping'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Pieces ----------------------------------------------------------------

class _CurrentStepBox extends StatelessWidget {
  const _CurrentStepBox({required this.activity, required this.stage, required this.onComplete});

  final String activity;
  final JobStage stage;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(activity, style: AppText.bodySm.copyWith(color: c.textMuted)),
          const SizedBox(height: 6),
          Text('STAGE: ${stage.label.toUpperCase()}', style: AppText.monoCaps.copyWith(color: c.textFaint)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.touch_app_outlined, size: 18),
            label: Text('MARK COMPLETE', style: AppText.monoCaps.copyWith(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.accent,
              backgroundColor: c.isDark ? c.bg : c.surface,
              minimumSize: const Size(0, 44),
              side: BorderSide(color: c.accent.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.icon, required this.label, required this.value, this.onTap});

  final IconData icon;
  final String label;
  final Widget value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.isDark ? c.surfaceHighest : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: c.textFaint),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(label.toUpperCase(), style: AppText.monoCaps.copyWith(color: c.textFaint)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    value,
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right, color: c.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.surface.withValues(alpha: 0.85),
        shape: CircleBorder(side: BorderSide(color: c.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: c.text)),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

Future<void> _openViewer(BuildContext context, String image) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (ctx) {
      final c = ctx.c;
      return Dialog.fullscreen(
        backgroundColor: c.bg,
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text('3D PREVIEW', style: AppText.monoCaps.copyWith(color: c.textMuted)),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(child: Image.asset(image, fit: BoxFit.contain)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Pinch to zoom · drag to pan', style: AppText.bodySm.copyWith(color: c.textFaint)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

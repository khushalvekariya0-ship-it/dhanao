import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';

/// Scaffold for New Job wizard steps: back arrow + step title, optional
/// badge, thin progress bar, scrolling body, sticky bottom CTA.
class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.title,
    required this.children,
    this.step,
    this.totalSteps,
    this.stepLabel,
    this.badge,
    this.onBadgeTap,
    this.ctaLabel,
    this.onCta,
    this.ctaIcon = Icons.arrow_forward,
    this.secondaryLabel,
    this.onSecondary,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final String title;
  final List<Widget> children;

  /// 1-based current step for the progress bar.
  final int? step;
  final int? totalSteps;

  /// Right side of the progress header ("MEDIA CAPTURE").
  final String? stepLabel;

  /// Pill in the app bar ("BESPOKE RING", "DRAFT").
  final String? badge;
  final VoidCallback? onBadgeTap;

  final String? ctaLabel;
  final VoidCallback? onCta;
  final IconData? ctaIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.maybePop(context)),
        // Shrink long step titles (next to a badge) instead of truncating them.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title, style: AppText.headlineSm),
        ),
        actions: [
          if (badge != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: onBadgeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.borderStrong),
                  ),
                  child: Text(badge!.toUpperCase(), style: AppText.labelSm.copyWith(color: c.textMuted)),
                ),
              ),
            ),
          ...?actions,
        ],
        bottom: step == null || totalSteps == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(34),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Column(children: [
                    Row(children: [
                      Text('STEP $step/$totalSteps', style: AppText.monoCaps.copyWith(color: c.isDark ? c.gold : c.textMuted)),
                      const Spacer(),
                      if (stepLabel != null)
                        Text(stepLabel!.toUpperCase(), style: AppText.monoCaps.copyWith(color: c.isDark ? c.gold : c.accent)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: step! / totalSteps!,
                        minHeight: 4,
                        color: c.isDark ? c.gold : c.accent,
                      ),
                    ),
                  ]),
                ),
              ),
      ),
      body: ListView(padding: padding, children: children),
      bottomNavigationBar: ctaLabel == null && secondaryLabel == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.border))),
                child: Row(children: [
                  if (secondaryLabel != null) ...[
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: onSecondary,
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                        child: Text(secondaryLabel!),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (ctaLabel != null)
                    Expanded(
                      flex: 3,
                      child: FilledButton(
                        onPressed: onCta,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          foregroundColor: c.isDark ? null : const Color(0xFFF2CA50),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(child: Text(ctaLabel!.toUpperCase(), overflow: TextOverflow.ellipsis, style: AppText.titleMd.copyWith(fontSize: 14, letterSpacing: 0.6))),
                          if (ctaIcon != null) ...[const SizedBox(width: 8), Icon(ctaIcon, size: 20)],
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
    );
  }
}

/// Scaffold for job/stage detail pages: title + mono job id subtitle.
class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.bottom,
    this.floatingActionButton,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;

  /// Sticky bottom bar (e.g. approve buttons). Wrapped in SafeArea.
  final Widget? bottom;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.maybePop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.headlineSm, overflow: TextOverflow.ellipsis),
            if (subtitle != null) Text(subtitle!, style: AppText.monoSm.copyWith(color: c.textFaint)),
          ],
        ),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.border))),
                child: bottom,
              ),
            ),
    );
  }
}

/// Horizontal scrolling pipeline: ✓ done — ● current — ○ upcoming.
class StageTimeline extends StatelessWidget {
  const StageTimeline({super.key, required this.current, this.stages = JobStage.values, this.onTap});

  final JobStage current;
  final List<JobStage> stages;
  final ValueChanged<JobStage>? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = c.isDark ? c.gold : c.text;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < stages.length; i++) ...[
            if (i > 0)
              Container(
                width: 20,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: stages[i].index <= current.index ? done : c.border,
              ),
            GestureDetector(
              onTap: onTap == null ? null : () => onTap!(stages[i]),
              child: _node(context, stages[i], done),
            ),
          ],
        ],
      ),
    );
  }

  Widget _node(BuildContext context, JobStage s, Color done) {
    final c = context.c;
    final isDone = s.index < current.index;
    final isCurrent = s == current;
    Widget dot;
    if (isDone) {
      dot = Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(color: done, shape: BoxShape.circle),
        child: Icon(Icons.check, size: 14, color: c.isDark ? c.onAction : Colors.white),
      );
    } else if (isCurrent) {
      final accent = c.isDark ? c.gold : const Color(0xFF6366F1);
      dot = Container(
        width: 26,
        height: 26,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 10)],
        ),
        child: Container(decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.6)))),
      );
    } else {
      dot = Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: c.surfaceHighest, shape: BoxShape.circle),
      );
    }
    final label = Text(
      s.short,
      style: AppText.labelMd.copyWith(
        color: isCurrent ? c.text : (isDone ? c.text : c.textFaint),
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
      ),
    );
    return Row(children: [
      dot,
      const SizedBox(width: 6),
      isCurrent
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(12)),
              child: label,
            )
          : label,
    ]);
  }
}

/// One row of a vertical pipeline / audit trail with a connector line.
class PipelineTile extends StatelessWidget {
  const PipelineTile({
    super.key,
    required this.title,
    this.subtitle,
    this.state = PipelineState.done,
    this.isLast = false,
    this.trailing,
    this.child,
    this.mono = false,
  });

  final String title;
  final String? subtitle;
  final PipelineState state;
  final bool isLast;
  final Widget? trailing;

  /// Extra content under the title (e.g. a "Mark Complete" button).
  final Widget? child;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final active = c.isDark ? c.gold : c.accent;
    final Color lineColor = state == PipelineState.done ? active : c.border;
    Widget dot;
    switch (state) {
      case PipelineState.done:
        dot = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active, width: 1.5)),
          child: Icon(Icons.check, size: 14, color: active),
        );
      case PipelineState.current:
        dot = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: active.withValues(alpha: 0.5), blurRadius: 10)],
          ),
          child: Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.isDark ? c.onAction : Colors.white, shape: BoxShape.circle))),
        );
      case PipelineState.pending:
        dot = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: c.surfaceHigh, shape: BoxShape.circle, border: Border.all(color: c.border)),
        );
    }
    final titleStyle = (mono ? AppText.monoLg : AppText.titleMd).copyWith(
      color: state == PipelineState.pending ? c.textFaint : c.text,
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(children: [
              dot,
              if (!isLast) Expanded(child: Container(width: 2, color: lineColor, margin: const EdgeInsets.symmetric(vertical: 4))),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(title, style: titleStyle)),
                    ?trailing,
                  ]),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: (mono ? AppText.monoMd : AppText.bodySm).copyWith(color: c.textFaint)),
                  ],
                  if (child != null) ...[const SizedBox(height: 10), child!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum PipelineState { done, current, pending }

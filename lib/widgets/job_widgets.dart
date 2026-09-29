import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'common.dart';

/// Color for a job's due tag: red when overdue/today, amber tomorrow, muted otherwise.
Color dueColor(BuildContext context, Job job) {
  final c = context.c;
  if (job.daysUntilDue <= 0) return c.danger;
  if (job.daysUntilDue == 1) return c.warning;
  return c.textMuted;
}

/// Chip showing the job's current stage in its status color.
class StageChip extends StatelessWidget {
  const StageChip(this.stage, {super.key});

  final JobStage stage;

  @override
  Widget build(BuildContext context) => StatusChip(stage.short, color: stage.color, dot: true);
}

/// Chip for non-standard priorities.
class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = switch (priority) {
      Priority.critical => c.danger,
      Priority.rush => c.warning,
      Priority.high => c.danger,
      Priority.standard => c.textFaint,
    };
    return StatusChip(priority.label, color: color, mono: false);
  }
}

/// Compact job card used by lists and the production board.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.onTap, this.showStage = true, this.compact = false});

  final Job job;
  final VoidCallback? onTap;
  final bool showStage;

  /// Smaller variant for kanban columns.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('#${job.id}', style: AppText.monoLg.copyWith(color: c.textMuted)),
            const Spacer(),
            if (job.priority != Priority.standard) PriorityChip(job.priority),
            if (job.priority == Priority.standard && job.atRisk) StatusChip('At Risk', color: c.danger, dot: true),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DhImage(asset: job.image, width: compact ? 44 : 52, height: compact ? 44 : 52, radius: 6),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.titleMd.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text('Client: ${job.customer}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodySm.copyWith(color: c.textMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          ThinProgress(value: job.progress, color: job.atRisk ? c.danger : null),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.schedule, size: 14, color: dueColor(context, job)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Due: ${Fmt.date(job.dueDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: dueColor(context, job)),
              ),
            ),
            if (showStage) ...[StageChip(job.stage), const SizedBox(width: 8)],
            Text('${job.daysInStage}d in stage', style: AppText.bodySm.copyWith(color: c.textFaint)),
          ]),
        ],
      ),
    );
  }
}

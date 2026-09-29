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
          Row(
            children: [
              Text('#${job.id}', style: AppText.monoLg.copyWith(color: c.textMuted)),
              const Spacer(),
              if (job.priority != Priority.standard) PriorityChip(job.priority),
              if (job.priority == Priority.standard && job.atRisk) StatusChip('At Risk', color: c.danger, dot: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DhImage(asset: job.image, width: compact ? 44 : 52, height: compact ? 44 : 52, radius: 6),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleMd.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Client: ${job.customer}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ThinProgress(value: job.progress, color: job.atRisk ? c.danger : null),
          const SizedBox(height: 10),
          Row(
            children: [
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
            ],
          ),
        ],
      ),
    );
  }
}

/// Everything captured by the Full Job Order wizard, grouped like the Review step.
class JobOrderSpecs extends StatelessWidget {
  const JobOrderSpecs({super.key, required this.order, this.initiallyExpanded = 0});

  final JobDraft order;

  /// Index of the section expanded at first (-1 for none).
  final int initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = order;
    final isRing = d.productCategory.contains('Ring');
    String yesNo(bool v) => v ? 'Yes' : 'No';
    String grams(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)} g';

    final groups = <(String, IconData, List<(String, String)>)>[
      (
        'Product & Design',
        Icons.design_services_outlined,
        [
          ('Job Type', d.jobType),
          ('Category', d.productCategory),
          if (isRing) ('Ring Size', '${d.sizeSystem} ${d.ringSize}'),
          if (isRing) ('Band Width', '${d.bandWidthMm.toStringAsFixed(1)} mm'),
          if (isRing) ('Band Profile', d.bandProfile),
          ('Setting Style', d.settingStyle),
          ('Metal Finish', d.metalFinish),
          ('Side Stones', d.sideStoneSetting),
          if (d.priorities.isNotEmpty) ('Priorities', d.priorities.join(', ')),
          if (d.notes.isNotEmpty) ('Notes', d.notes),
        ],
      ),
      (
        'Materials',
        Icons.hexagon_outlined,
        [
          ('Metal', d.metalLabel),
          ('Target Weight', '${grams(d.targetWeight)} ± ${grams(d.weightTolerance)}'),
          ('Customer Supplied', yesNo(d.customerSuppliedMetal)),
          ('Hallmark & Stamping', yesNo(d.hallmark)),
          if (d.alloyNotes.isNotEmpty) ('Alloy Notes', d.alloyNotes),
        ],
      ),
      (
        'Center Stone',
        Icons.diamond_outlined,
        [
          ('Stone', d.stoneLabel),
          ('Source', d.stoneSupplied ? 'Customer Supplied' : 'Needs to be Sourced'),
          ('Origin', d.stoneOrigin),
          if (d.stoneDims.isNotEmpty) ('Dimensions', '${d.stoneDims} mm'),
          if (d.stoneType == 'Diamond' || d.stoneType == 'Moissanite')
            ('Color / Clarity / Cut', '${d.stoneColor} / ${d.stoneClarity} / ${d.stoneCut}')
          else
            ('Color / Tone', d.stoneColor),
          ('Certificate', d.certificate),
          if (d.stoneNotes.isNotEmpty) ('Notes', d.stoneNotes),
        ],
      ),
      (
        'Melee & Accents',
        Icons.grain,
        [
          if (d.melee.isEmpty) ('Parcels', 'None'),
          for (final (i, p) in d.melee.indexed)
            (
              'Parcel ${i + 1} · ${p.shape} ${p.type}',
              '${p.summary}\n${p.supplied ? 'In Stock / Supplied' : 'Needs Sourcing'}',
            ),
        ],
      ),
      (
        'Commercial',
        Icons.request_quote_outlined,
        [
          ('Customer', d.customer),
          ('Quantity', '${d.quantity} unit${d.quantity == 1 ? '' : 's'}'),
          ('Pricing Basis', d.pricingBasis),
          ('Metal Market Rate (oz)', Fmt.money(d.metalMarketRate, cents: true)),
          if (d.stoneSupplied) ('Declared Stone Value', Fmt.money(d.declaredStoneValue, cents: true)),
          for (final l in d.costs) (l.label, Fmt.money(l.amount, cents: true)),
          ('Target Unit Price', Fmt.money(d.targetUnitPrice)),
          ('Max Approved', Fmt.money(d.maxApprovedPrice)),
          ('Order Value', Fmt.money(d.targetUnitPrice * d.quantity)),
        ],
      ),
      (
        'Delivery',
        Icons.event_outlined,
        [
          ('Requested Delivery', d.requestedDelivery == null ? '—' : Fmt.dateLong(d.requestedDelivery!)),
          ('Hard Deadline', yesNo(d.hardDeadline)),
          ('Partial Delivery', yesNo(d.partialDelivery)),
          ('Priority', d.priority.label),
        ],
      ),
      (
        'Quality Acceptance',
        Icons.verified_outlined,
        [
          ('Checks', d.qualityChecks.isEmpty ? 'None' : d.qualityChecks.join('\n')),
          ('Certification', d.qualityCertification),
          ('Final Authority', d.qualityAuthority),
          if (d.customerRequirements.isNotEmpty) ('Customer Requirements', d.customerRequirements),
        ],
      ),
    ];

    return DhCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(Icons.assignment_outlined, size: 20, color: c.accent),
                const SizedBox(width: 8),
                Expanded(child: Text('Job Order Specs', style: AppText.headlineSm)),
                StatusChip('Full Order', color: c.accent),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Captured in the New Job wizard. Tap a section to expand.',
              style: AppText.bodySm.copyWith(color: c.textMuted),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (final (i, g) in groups.indexed)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: i == initiallyExpanded,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      iconColor: c.textMuted,
                      collapsedIconColor: c.textFaint,
                      leading: Icon(g.$2, size: 20, color: c.textMuted),
                      title: Text(g.$1, style: AppText.titleMd.copyWith(fontSize: 15)),
                      children: [
                        for (final (j, r) in g.$3.indexed) KeyValueRow(r.$1, r.$2, divider: j < g.$3.length - 1),
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
}

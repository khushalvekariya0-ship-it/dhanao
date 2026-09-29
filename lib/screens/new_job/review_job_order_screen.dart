import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

String _yesNo(bool v) => v ? 'Yes' : 'No';

class _Line {
  const _Line(this.label, this.value, {this.mono = false});

  final String label;
  final String value;
  final bool mono;
}

class ReviewJobOrderScreen extends StatefulWidget {
  const ReviewJobOrderScreen({super.key});

  @override
  State<ReviewJobOrderScreen> createState() => _ReviewJobOrderScreenState();
}

class _ReviewJobOrderScreenState extends State<ReviewJobOrderScreen> {
  JobDraft get d => app.draft;

  final Set<String> _open = {};

  /// Returns to a wizard step already on the stack, or pushes it if missing.
  void _goTo(String route) {
    final nav = Navigator.of(context);
    var found = false;
    nav.popUntil((r) {
      if (r.settings.name == route) found = true;
      return found || r.isFirst;
    });
    if (!found) nav.pushNamed(route);
  }

  void _send() {
    final job = app.createJobFromDraft();
    app.resetDraft();
    Navigator.pushNamedAndRemoveUntil(context, Routes.created, (r) => r.isFirst, arguments: job.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isRing = d.productCategory.contains('Ring');
    final graded = d.stoneType == 'Diamond' || d.stoneType == 'Moissanite';
    final delivery = d.requestedDelivery ?? d.deliveryDate;
    final sections = [
      (
        Icons.design_services_outlined,
        c.accent,
        'Product & Design',
        Routes.designSpecs,
        '${d.productCategory} · ${d.settingStyle} setting',
        [
          _Line('Category', d.productCategory),
          _Line('Job Type', d.jobType),
          if (isRing) _Line('Ring Size', '${d.sizeSystem} ${d.ringSize}', mono: true),
          _Line('Band Width', '${d.bandWidthMm.toStringAsFixed(1)} mm', mono: true),
          _Line('Setting Style', d.settingStyle),
          _Line('Metal Finish', d.metalFinish),
          _Line('Band Profile', d.bandProfile),
          _Line('Side Stones', d.sideStoneSetting),
          _Line('Priorities', d.priorities.isEmpty ? '—' : d.priorities.join(', ')),
          _Line(
            'References',
            '${d.referenceImages.length} image${d.referenceImages.length == 1 ? '' : 's'}'
                '${d.hasVoiceNote ? ' + voice note' : ''}',
            mono: true,
          ),
        ],
      ),
      (
        Icons.hexagon_outlined,
        c.gold,
        'Materials',
        Routes.metal,
        d.metalLabel,
        [
          _Line('Metal', d.metalLabel),
          _Line(
            'Target Weight',
            d.targetWeight == null
                ? 'Not set'
                : '${Fmt.grams(d.targetWeight!, digits: 2)} ± ${(d.weightTolerance ?? 0).toStringAsFixed(2)} g',
            mono: true,
          ),
          _Line('Metal Source', d.customerSuppliedMetal ? 'Customer supplied' : 'House stock'),
          _Line('Hallmark', _yesNo(d.hallmark)),
          if (d.alloyNotes.trim().isNotEmpty) _Line('Alloy Notes', d.alloyNotes.trim()),
        ],
      ),
      (
        Icons.diamond_outlined,
        c.info,
        'Stones',
        Routes.stones,
        d.stoneLabel,
        [
          _Line('Center Stone', d.stoneLabel),
          _Line('Origin', d.stoneOrigin),
          _Line('Source', d.stoneSupplied ? 'Customer supplied' : 'To be sourced'),
          if (d.stoneDims.isNotEmpty) _Line('Dimensions', '${d.stoneDims} mm', mono: true),
          if (graded)
            _Line('Color / Clarity / Cut', '${d.stoneColor} / ${d.stoneClarity} / ${d.stoneCut}', mono: true)
          else
            _Line('Color / Tone', d.stoneColor.isEmpty ? '—' : d.stoneColor),
          _Line('Certificate', d.certificate),
          _Line('Stone Photo', d.stonePhoto == null ? 'None' : 'Attached'),
          if (d.stoneNotes.trim().isNotEmpty) _Line('Notes', d.stoneNotes.trim()),
          if (d.melee.isEmpty) const _Line('Melee', 'None'),
          for (final p in d.melee)
            _Line(
              'Melee · ${p.shape} ${p.type}',
              '${p.summary}\n${p.supplied ? 'Supplied' : 'Needs sourcing'}',
              mono: true,
            ),
        ],
      ),
      (
        Icons.attach_money,
        c.success,
        'Commercial',
        Routes.commercial,
        '${d.pricingBasis} · ${Fmt.money(d.targetUnitPrice)} target',
        [
          _Line('Customer', d.customer.isEmpty ? '—' : d.customer),
          _Line('Pricing Basis', d.pricingBasis),
          const _Line('Payment Terms', 'Net 30'),
          const _Line('Shipping', 'Insured courier'),
          _Line('Manufacturing', Fmt.money(d.manufacturingTotal, cents: true), mono: true),
          _Line('Target Unit Price', Fmt.money(d.targetUnitPrice, cents: true), mono: true),
          _Line('Max Approved', Fmt.money(d.maxApprovedPrice, cents: true), mono: true),
          _Line('Total Order Value', Fmt.money(d.targetUnitPrice * d.quantity, cents: true), mono: true),
        ],
      ),
      (
        Icons.local_shipping_outlined,
        c.warning,
        'Delivery',
        Routes.delivery,
        '${delivery == null ? 'No date' : Fmt.dateLong(delivery)} · ${d.priority.label}',
        [
          _Line('Requested Date', delivery == null ? 'Not set' : Fmt.dateLong(delivery), mono: true),
          _Line('Hard Deadline', _yesNo(d.hardDeadline)),
          _Line('Partial Delivery', d.quantity > 1 && d.partialDelivery ? 'Allowed' : 'Not allowed'),
          _Line('Priority', d.priority.label),
        ],
      ),
      (
        Icons.verified_outlined,
        c.accent,
        'Quality',
        Routes.quality,
        '${d.qualityChecks.length} checks · ${d.qualityAuthority}',
        [
          _Line('Acceptance Checks', d.qualityChecks.isEmpty ? 'None selected' : d.qualityChecks.join('\n')),
          _Line('Certification', d.qualityCertification),
          _Line('Final Authority', d.qualityAuthority),
          if (d.customerRequirements.trim().isNotEmpty) _Line('Customer Notes', d.customerRequirements.trim()),
        ],
      ),
    ];

    return WizardScaffold(
      title: 'Step 4: Final Review',
      step: 4,
      totalSteps: 4,
      stepLabel: 'Review',
      badge: 'Draft',
      secondaryLabel: 'Save Draft',
      onSecondary: () => showSnack(context, 'Draft saved — resume anytime from New Job', icon: Icons.save_outlined),
      ctaLabel: 'Send for Approval',
      ctaIcon: Icons.send_outlined,
      onCta: _send,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#DRAFT', style: AppText.monoLg.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Review Job Order', style: AppText.bodyMd.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('Draft', style: AppText.labelMd),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _summaryCard(c, delivery),
        const SizedBox(height: 20),
        for (final (icon, color, title, route, summary, lines) in sections) ...[
          _Section(
            icon: icon,
            iconColor: color,
            title: title,
            summary: summary,
            lines: lines,
            open: _open.contains(title),
            onToggle: () => setState(() => _open.contains(title) ? _open.remove(title) : _open.add(title)),
            onEdit: () => _goTo(route),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        _approvalCard(c),
      ],
    );
  }

  Widget _summaryCard(DhColors c, DateTime? delivery) {
    final refs = d.referenceImages;
    final units = '${d.quantity} Unit${d.quantity == 1 ? '' : 's'}';
    return DhCard(
      color: c.isDark ? c.surface : c.surfaceLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DhImage(
                file: refs.isEmpty ? null : refs.first,
                asset: refs.isEmpty ? Img.ringGoldSolitaire2 : null,
                width: 56,
                height: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.customer.isEmpty ? 'No customer' : d.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.headlineSm,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.metalLabel} ${d.productCategory}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyMd.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: LabelValue('Quantity', units, mono: true)),
              const SizedBox(width: 12),
              Expanded(
                child: LabelValue('Delivery Date', delivery == null ? 'Not set' : Fmt.dateLong(delivery), mono: true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: LabelValue('Max Unit Cost', Fmt.money(d.maxApprovedPrice, cents: true), mono: true)),
              const SizedBox(width: 12),
              Expanded(child: LabelValue('Priority', d.priority.label)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _approvalCard(DhColors c) {
    final fg = c.onNavActive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.navActive,
        borderRadius: BorderRadius.circular(12),
        border: c.isDark ? Border.all(color: c.gold.withValues(alpha: 0.35)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.rule_folder_outlined, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Approval Requirements', style: AppText.headlineSm.copyWith(color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final step in const ['Design Review', 'Cost Analysis', 'Vendor Allocation'])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(step, style: AppText.bodyMd.copyWith(color: fg.withValues(alpha: 0.8))),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      'PENDING',
                      style: AppText.monoCaps.copyWith(fontSize: 10, color: c.isDark ? c.gold : c.accent),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Sending notifies approvers and routes the specs to CAD engineering.',
            style: AppText.bodySm.copyWith(color: fg.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

/// Collapsible review section with an "Edit" jump back to its wizard step.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.summary,
    required this.lines,
    required this.open,
    required this.onToggle,
    required this.onEdit,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String summary;
  final List<_Line> lines;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: iconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.titleMd),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Edit'),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < lines.length; i++)
                    KeyValueRow(lines[i].label, lines[i].value, mono: lines[i].mono, divider: i < lines.length - 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

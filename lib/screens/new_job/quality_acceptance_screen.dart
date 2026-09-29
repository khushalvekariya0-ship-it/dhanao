import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

const _matchCad = 'Match CAD / Reference';

const _groups = [
  (Icons.visibility_outlined, 'Appearance', [_matchCad, 'High-Polish Surface Finish']),
  (Icons.straighten, 'Dimensions', ['Size & Weight Conformance', 'Strict Dimensional Tolerance (±0.05mm)']),
  (Icons.all_out, 'Stone Setting', ['Security & Prongs Flush', 'Symmetry & Table Orientation']),
];

const _certifications = ['IGI', 'GIA', 'Other', 'None'];

const _authorities = [
  ('Customer', Icons.face_outlined),
  ('Jeweler', Icons.storefront_outlined),
  ('Manufacturer', Icons.precision_manufacturing_outlined),
  ('Internal QC', Icons.verified_user_outlined),
];

class QualityAcceptanceScreen extends StatefulWidget {
  const QualityAcceptanceScreen({super.key});

  @override
  State<QualityAcceptanceScreen> createState() => _QualityAcceptanceScreenState();
}

class _QualityAcceptanceScreenState extends State<QualityAcceptanceScreen> {
  JobDraft get d => app.draft;

  void _toggle(String check) => setState(() {
    if (!d.qualityChecks.remove(check)) d.qualityChecks.add(check);
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return WizardScaffold(
      title: 'Step 3: Quality Acceptance',
      step: 3,
      totalSteps: 4,
      stepLabel: 'Quality',
      ctaLabel: 'Review Job Order',
      onCta: () => Navigator.pushNamed(context, Routes.review),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: c.isDark ? c.surface : c.surfaceLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond_outlined, size: 16, color: c.accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'JOB TYPE: ${d.jobType} ${d.productCategory}'.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.monoCaps.copyWith(color: c.text),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('What does an acceptable finished piece look like?', style: AppText.headlineMd),
        const SizedBox(height: 6),
        Text(
          'Define the precision standards and acceptance criteria for final delivery.',
          style: AppText.bodyMd.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 20),
        for (final (icon, title, checks) in _groups) ...[
          _CheckGroup(
            icon: icon,
            title: title,
            children: [
              for (final check in checks)
                _CheckRow(
                  label: check,
                  checked: d.qualityChecks.contains(check),
                  onTap: () => _toggle(check),
                  extra: check == _matchCad ? _referenceStrip() : null,
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 14),
        Field(
          label: 'Independent Certification',
          hint: d.certificate == 'No Certificate' ? null : 'Center stone certificate requested: ${d.certificate}',
          child: ChoiceGroup<String>(
            options: _certifications,
            selected: d.qualityCertification,
            columns: 4,
            dense: true,
            onChanged: (v) => setState(() => d.qualityCertification = v),
          ),
        ),
        const SizedBox(height: 24),
        Field(
          label: 'Customer-Specific Requirements',
          child: DhTextField(
            value: d.customerRequirements,
            maxLines: 4,
            hint: 'Enter any bespoke requests, unique polishing instructions, or critical constraints...',
            onChanged: (v) => setState(() => d.customerRequirements = v),
          ),
        ),
        const SizedBox(height: 24),
        Field(
          label: 'Final Quality Authority',
          child: OptionLayout(
            columns: 2,
            spacing: 12,
            children: [
              for (final (name, icon) in _authorities)
                IconOptionCard(
                  icon: icon,
                  title: name,
                  selected: d.qualityAuthority == name,
                  onTap: () => setState(() => d.qualityAuthority = name),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 12, color: c.textFaint),
            const SizedBox(width: 6),
            Text('SECURE LOGISTICS PROTOCOL', style: AppText.monoCaps.copyWith(fontSize: 10, color: c.textFaint)),
          ],
        ),
      ],
    );
  }

  Widget _referenceStrip() {
    final refs = d.referenceImages.take(3).toList();
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < refs.length; i++) _RefThumb(file: refs[i], caption: 'CLIENT ${i + 1}'),
          const _RefThumb(asset: Img.ringSolitaireDark, caption: 'REFERENCE'),
          const _RefThumb(asset: Img.cadSpecSheet, caption: 'CAD SPEC'),
        ],
      ),
    );
  }
}

class _CheckGroup extends StatelessWidget {
  const _CheckGroup({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: c.isDark ? c.surfaceHigh : c.surfaceLow,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: c.isDark ? c.surfaceHighest : c.surfaceHigh, shape: BoxShape.circle),
                  child: Icon(icon, size: 18, color: c.text),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppText.titleMd)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.checked, required this.onTap, this.extra});

  final String label;
  final bool checked;
  final VoidCallback onTap;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(value: checked, onChanged: (_) => onTap()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: checked ? c.text : c.textMuted),
                  ),
                  if (extra != null) ...[const SizedBox(height: 10), extra!],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable reference thumbnail; opens a zoomable preview.
class _RefThumb extends StatelessWidget {
  const _RefThumb({required this.caption, this.asset, this.file});

  final String caption;
  final String? asset;
  final String? file;

  void _preview(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: DhImage(asset: asset, file: file, radius: 0, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: () => _preview(context),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              DhImage(asset: asset, file: file, width: 64, height: 64, radius: 8),
              const SizedBox(height: 6),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoSm.copyWith(fontSize: 9, color: c.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

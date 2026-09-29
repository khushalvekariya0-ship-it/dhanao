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
      actions: const [_ProfileButton()],
      ctaLabel: 'Review Job Order',
      onCta: () => Navigator.pushNamed(context, Routes.review),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.isDark ? c.surface : c.surfaceLow,
              borderRadius: BorderRadius.circular(20),
              border: c.isDark ? Border.all(color: c.border) : null,
              boxShadow: _shadow(c),
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
                    style: AppText.labelSm.copyWith(color: c.text),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'What does an acceptable finished piece look like?',
          style: AppText.headlineMd.copyWith(fontSize: 24, height: 32 / 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Define the precision standards and acceptance criteria for final delivery.',
          style: AppText.bodyMd.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 24),
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
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        Field(
          label: 'Independent Certification',
          hint: d.certificate == 'No Certificate' ? null : 'Center stone certificate requested: ${d.certificate}',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final cert in _certifications)
                _CertPill(
                  label: cert,
                  selected: d.qualityCertification == cert,
                  onTap: () => setState(() => d.qualityCertification = cert),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Field(
          label: 'Customer-Specific Requirements',
          child: _RequirementsField(
            value: d.customerRequirements,
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
                _AuthorityTile(
                  icon: icon,
                  label: name,
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
      height: 64,
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: _shadow(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
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
          Checkbox(
            value: checked,
            onChanged: (_) => onTap(),
            fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.action : c.surface),
            checkColor: c.onAction,
            side: BorderSide(color: c.isDark ? c.borderStrong : c.textFaint, width: 1.5),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.bodyMd.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.text),
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
    showImageViewer(context, asset: asset, file: file, caption: caption);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _preview(context),
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: caption,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), boxShadow: _shadow(c)),
            child: DhImage(asset: asset, file: file, width: 64, height: 64, radius: 6),
          ),
        ),
      ),
    );
  }
}

List<BoxShadow>? _shadow(DhColors c) =>
    c.isDark ? null : [BoxShadow(color: c.text.withValues(alpha: 0.07), blurRadius: 3, offset: const Offset(0, 1))];

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

/// Rounded certification pill: solid accent when selected.
class _CertPill extends StatelessWidget {
  const _CertPill({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: _shadow(c)),
      child: Material(
        color: selected ? c.accent : c.surfaceHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Text(label, style: AppText.labelMd.copyWith(fontSize: 13, color: selected ? c.onAccent : c.text)),
          ),
        ),
      ),
    );
  }
}

/// Final-authority option: tonal tile, solid accent when selected.
class _AuthorityTile extends StatelessWidget {
  const _AuthorityTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = selected ? c.onAccent : c.text;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: _shadow(c)),
      child: Material(
        color: selected ? c.accent : c.surfaceHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, size: 24, color: fg),
                const SizedBox(height: 8),
                Text(label, style: AppText.labelMd.copyWith(fontSize: 13, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Borderless white text area with a soft shadow.
class _RequirementsField extends StatefulWidget {
  const _RequirementsField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_RequirementsField> createState() => _RequirementsFieldState();
}

class _RequirementsFieldState extends State<_RequirementsField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final none = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: _shadow(c)),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        maxLines: 4,
        style: AppText.bodyMd.copyWith(color: c.text),
        decoration: InputDecoration(
          hintText: 'Enter any bespoke requests, unique polishing instructions, or critical constraints...',
          hintMaxLines: 4,
          hintStyle: AppText.bodyMd.copyWith(color: c.textMuted.withValues(alpha: 0.6)),
          filled: true,
          fillColor: c.surface,
          contentPadding: const EdgeInsets.all(16),
          border: none,
          enabledBorder: c.isDark
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: c.border),
                )
              : none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.accent, width: 1.5),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Full job order — Step 1 (Metal): base metal, purity, colour, target weight and metal handling.
class MetalMaterialsScreen extends StatefulWidget {
  const MetalMaterialsScreen({super.key});

  @override
  State<MetalMaterialsScreen> createState() => _MetalMaterialsScreenState();
}

const _bases = ['Gold', 'Platinum', 'Silver', 'Other'];
const _purities = {
  'Gold': ['18K', '14K', '22K', '24K'],
  'Platinum': ['950 Plat'],
  'Silver': ['925 Silver'],
};
const _colors = ['Yellow', 'White', 'Rose', 'Two Tone'];

class _MetalMaterialsScreenState extends State<MetalMaterialsScreen> {
  late final TextEditingController _weight = TextEditingController(text: _fmt(app.draft.targetWeight));
  late final TextEditingController _tolerance = TextEditingController(text: _fmt(app.draft.weightTolerance));

  static String _fmt(double? v) => v == null ? '' : v.toString();

  @override
  void initState() {
    super.initState();
    final d = app.draft;
    if (!_bases.contains(d.baseMetal)) d.baseMetal = 'Other';
    final opts = _purities[d.baseMetal];
    if (opts != null && !opts.contains(d.purity)) d.purity = opts.first;
    if (!_colors.contains(d.metalColor)) d.metalColor = 'Yellow';
  }

  @override
  void dispose() {
    _weight.dispose();
    _tolerance.dispose();
    super.dispose();
  }

  void _setBase(String base) {
    final d = app.draft;
    setState(() {
      d.baseMetal = base;
      final opts = _purities[base];
      if (opts != null) {
        if (!opts.contains(d.purity)) d.purity = opts.first;
      } else if (_purities.values.any((l) => l.contains(d.purity))) {
        d.purity = '';
      }
    });
  }

  String get _stamp {
    final d = app.draft;
    return switch (d.baseMetal) {
      'Platinum' => 'PT950',
      'Silver' => '925',
      'Gold' => d.purity,
      _ => d.purity.trim().isEmpty ? 'custom mark' : d.purity.trim(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = app.draft;
    final purities = _purities[d.baseMetal];
    const gap = SizedBox(height: 24);
    return WizardScaffold(
      title: 'Step 1: Specifications',
      step: 1,
      totalSteps: 4,
      stepLabel: 'Metal',
      actions: const [_ProfileButton()],
      ctaLabel: 'Continue to Stones',
      onCta: () => Navigator.pushNamed(context, Routes.stones),
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.isDark ? c.accentSoft : c.accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Custom ${d.productCategory}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelSm.copyWith(fontSize: 12, color: c.isDark ? c.gold : c.onAccent),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('DRAFT ORDER', style: AppText.labelSm.copyWith(color: c.textFaint, letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 6),
        Text('Metal Requirements', style: AppText.headlineMd.copyWith(fontSize: 24, height: 32 / 24)),
        const SizedBox(height: 4),
        Text('Specify core materials and alloy details.', style: AppText.bodyMd.copyWith(color: c.textMuted)),
        gap,
        _Labeled(
          label: 'Base Metal',
          child: OptionLayout(
            columns: 2,
            spacing: 12,
            children: [
              for (final b in _bases) _BaseTile(label: b, selected: d.baseMetal == b, onTap: () => _setBase(b)),
            ],
          ),
        ),
        gap,
        if (purities == null)
          _Labeled(
            label: 'Purity / Alloy',
            child: _FilledTextField(
              key: const ValueKey('other-purity'),
              value: d.purity,
              hint: 'e.g. Palladium 950, 10K',
              onChanged: (v) => setState(() => d.purity = v),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Labeled(
                  label: 'Purity',
                  child: _Dropdown(
                    key: ValueKey('purity-${d.baseMetal}'),
                    value: d.purity,
                    items: purities,
                    onChanged: (v) => setState(() => d.purity = v),
                  ),
                ),
              ),
              if (d.baseMetal == 'Gold') ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _Labeled(
                    label: 'Color',
                    child: _Dropdown(
                      value: d.metalColor,
                      items: _colors,
                      onChanged: (v) => setState(() => d.metalColor = v),
                    ),
                  ),
                ),
              ],
            ],
          ),
        gap,
        _WeightCard(
          weight: _weight,
          tolerance: _tolerance,
          onWeight: (v) => d.targetWeight = double.tryParse(v),
          onTolerance: (v) => d.weightTolerance = double.tryParse(v),
        ),
        const SizedBox(height: 32),
        _SwitchCard(
          title: 'Customer Supplied Metal',
          subtitle: 'Client providing scrap or raw material',
          value: d.customerSuppliedMetal,
          onChanged: (v) => setState(() => d.customerSuppliedMetal = v),
          footer: d.customerSuppliedMetal
              ? Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: c.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Metal will be weighed and logged at intake before casting.',
                        style: AppText.bodySm.copyWith(color: c.textMuted),
                      ),
                    ),
                  ],
                )
              : null,
        ),
        const SizedBox(height: 16),
        _Labeled(
          label: 'Hallmark & Stamping',
          child: _SwitchCard(
            title: d.hallmark ? "Stamp $_stamp + maker's mark" : "No purity stamp or maker's mark",
            titleStyle: AppText.bodyMd.copyWith(color: d.hallmark ? c.text : c.textMuted),
            value: d.hallmark,
            onChanged: (v) => setState(() => d.hallmark = v),
          ),
        ),
        const SizedBox(height: 16),
        _Labeled(
          label: 'Special Alloy Notes',
          child: _FilledTextField(
            value: d.alloyNotes,
            maxLines: 2,
            hint: 'Any specific mix requirements...',
            onChanged: (v) => d.alloyNotes = v,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Resting fill of fields and tiles (the design's surface-container).
Color _fill(DhColors c) => c.isDark ? c.surface : c.surfaceHigh.withValues(alpha: 0.7);

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

/// Title-case field label above its control.
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.labelMd.copyWith(fontSize: 14, color: context.c.text)),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// Base metal option: tonal tile, solid primary when selected.
class _BaseTile extends StatelessWidget {
  const _BaseTile({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.action : _fill(c),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(label, style: AppText.labelMd.copyWith(fontSize: 14, color: selected ? c.onAction : c.text)),
          ),
        ),
      ),
    );
  }
}

/// Tonal card with a title/subtitle and a primary-coloured switch.
class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.titleStyle,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: _fill(c),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, subtitle == null ? 4 : 12, 8, subtitle == null ? 4 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: titleStyle ?? AppText.labelMd.copyWith(fontSize: 14, color: c.text)),
                        if (subtitle != null) Text(subtitle!, style: AppText.bodySm.copyWith(color: c.textMuted)),
                      ],
                    ),
                  ),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    trackColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected) ? c.action : c.surfaceHighest,
                    ),
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected) ? c.action : c.surfaceHighest,
                    ),
                    thumbColor: WidgetStateProperty.resolveWith(
                      (s) => s.contains(WidgetState.selected) ? c.onAction : (c.isDark ? c.textFaint : c.surface),
                    ),
                  ),
                ],
              ),
              if (footer != null) ...[const SizedBox(height: 8), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Borderless tonal text field that keeps its own controller.
class _FilledTextField extends StatefulWidget {
  const _FilledTextField({super.key, required this.value, required this.onChanged, this.hint, this.maxLines = 1});

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;

  @override
  State<_FilledTextField> createState() => _FilledTextFieldState();
}

class _FilledTextFieldState extends State<_FilledTextField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: _ctrl,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      style: AppText.bodyMd.copyWith(color: c.text),
      decoration: _filledDecoration(c).copyWith(hintText: widget.hint, contentPadding: const EdgeInsets.all(16)),
    );
  }
}

InputDecoration _filledDecoration(DhColors c) {
  final none = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none);
  return InputDecoration(
    filled: true,
    fillColor: _fill(c),
    hintStyle: AppText.bodyMd.copyWith(color: c.textMuted.withValues(alpha: 0.6)),
    border: none,
    enabledBorder: none,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: c.action, width: 2),
    ),
  );
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.weight, required this.tolerance, required this.onWeight, required this.onTolerance});

  final TextEditingController weight;
  final TextEditingController tolerance;
  final ValueChanged<String> onWeight;
  final ValueChanged<String> onTolerance;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final label = AppText.labelSm.copyWith(fontSize: 12, color: c.textMuted, letterSpacing: 0.6);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceLow : c.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: c.isDark ? Border.all(color: c.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.scale_outlined, size: 20, color: c.textMuted),
              const SizedBox(width: 8),
              Text('Target Weight & Tolerance', style: AppText.labelMd.copyWith(fontSize: 14, color: c.text)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weight (g)', style: label),
                    const SizedBox(height: 6),
                    _NumField(controller: weight, onChanged: onWeight, hint: '0.0'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text('+/-', style: AppText.monoMd.copyWith(color: c.textMuted)),
              ),
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Range (g)', style: label),
                    const SizedBox(height: 6),
                    _NumField(controller: tolerance, onChanged: onTolerance, hint: '0.0'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({required this.controller, required this.onChanged, this.hint});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: AppText.monoLg.copyWith(fontSize: 15, color: c.text),
      decoration: _filledDecoration(c).copyWith(
        hintText: hint,
        fillColor: c.isDark ? c.surface : c.surfaceHigh.withValues(alpha: 0.8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({super.key, required this.value, required this.items, required this.onChanged});

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      isExpanded: true,
      borderRadius: BorderRadius.circular(8),
      dropdownColor: c.surface,
      icon: Icon(Icons.expand_more, color: c.textMuted),
      style: AppText.bodyMd.copyWith(color: c.text),
      decoration: _filledDecoration(c).copyWith(contentPadding: const EdgeInsets.fromLTRB(16, 14, 12, 14)),
      items: [
        for (final i in items)
          DropdownMenuItem(
            value: i,
            child: Text(i, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

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
      ctaLabel: 'Continue to Stones',
      onCta: () => Navigator.pushNamed(context, Routes.stones),
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'Custom ${d.productCategory}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelMd.copyWith(color: c.onAccent),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('DRAFT ORDER', style: AppText.monoCaps.copyWith(color: c.textFaint)),
          ],
        ),
        const SizedBox(height: 10),
        Text('Metal Requirements', style: AppText.headlineMd),
        const SizedBox(height: 4),
        Text('Specify core materials and alloy details.', style: AppText.bodyMd.copyWith(color: c.textMuted)),
        gap,
        Field(
          label: 'Base Metal',
          child: ChoiceGroup<String>(options: _bases, selected: d.baseMetal, columns: 2, onChanged: _setBase),
        ),
        gap,
        if (purities == null)
          Field(
            label: 'Purity / Alloy',
            child: DhTextField(
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
                child: Field(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Field(
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
        gap,
        DhCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              ToggleRow(
                title: 'Customer Supplied Metal',
                subtitle: 'Client providing scrap or raw material',
                value: d.customerSuppliedMetal,
                onChanged: (v) => setState(() => d.customerSuppliedMetal = v),
              ),
              if (d.customerSuppliedMetal)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
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
                  ),
                ),
              const Divider(),
              ToggleRow(
                title: 'Hallmark & Stamping',
                subtitle: d.hallmark ? "Stamp $_stamp + maker's mark" : "No purity stamp or maker's mark",
                value: d.hallmark,
                onChanged: (v) => setState(() => d.hallmark = v),
              ),
            ],
          ),
        ),
        gap,
        Field(
          label: 'Special Alloy Notes',
          child: DhTextField(
            value: d.alloyNotes,
            maxLines: 3,
            hint: 'Any specific mix requirements...',
            onChanged: (v) => d.alloyNotes = v,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
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
    final label = AppText.labelSm.copyWith(color: c.textMuted);
    return DhCard(
      color: c.isDark ? c.surface : c.surfaceLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.scale_outlined, size: 20, color: c.textMuted),
              const SizedBox(width: 8),
              Text('Target Weight & Tolerance', style: AppText.labelMd.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('WEIGHT (G)', style: label),
                    const SizedBox(height: 6),
                    _NumField(controller: weight, onChanged: onWeight, hint: '0.0'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Text('+/-', style: AppText.monoMd.copyWith(color: c.textMuted)),
              ),
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RANGE (G)', style: label),
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
      style: AppText.monoLg.copyWith(fontSize: 16, color: c.text),
      decoration: InputDecoration(hintText: hint),
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
      icon: Icon(Icons.expand_more, color: c.textFaint),
      style: AppText.bodyMd.copyWith(color: c.text),
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

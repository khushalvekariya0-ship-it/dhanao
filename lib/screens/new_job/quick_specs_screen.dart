import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Quick flow step 3/4: base metal, purity, gemstone, budget and delivery target.
class QuickSpecsScreen extends StatefulWidget {
  const QuickSpecsScreen({super.key});

  @override
  State<QuickSpecsScreen> createState() => _QuickSpecsScreenState();
}

class _Metal {
  const _Metal(this.code, this.light, this.deep);

  final String code;

  /// Physical metal swatch gradient — intentionally identical in both themes.
  final Color light;
  final Color deep;
}

const _metals = [
  _Metal('Y.GOLD', Color(0xFFFFE088), Color(0xFFD4AF37)),
  _Metal('W.METAL', Color(0xFFF8FAFC), Color(0xFFCBD5E1)),
  _Metal('R.GOLD', Color(0xFFE0BFB8), Color(0xFFB76E79)),
];

class _QuickSpecsScreenState extends State<QuickSpecsScreen> {
  late final TextEditingController _budget = TextEditingController(text: _fmtBudget(app.draft.budget));

  static String _fmtBudget(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: app.draft.deliveryDate ?? today.add(const Duration(days: 35)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Delivery target',
    );
    if (picked != null && mounted) setState(() => app.draft.deliveryDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = app.draft;
    const gap = SizedBox(height: 28);
    return WizardScaffold(
      title: 'New Job',
      step: 3,
      totalSteps: 4,
      stepLabel: 'Material Selection',
      actions: [
        IconButton(
          tooltip: 'Save draft',
          icon: const Icon(Icons.save_outlined),
          onPressed: () => showSnack(context, 'Draft saved', icon: Icons.save_outlined),
        ),
      ],
      ctaLabel: 'Continue to Review',
      onCta: () => Navigator.pushNamed(context, Routes.confirmOrder),
      children: [
        Text('Material Selection', style: AppText.headlineLg),
        const SizedBox(height: 6),
        Text(
          'Specify the foundational elements for your custom piece.',
          style: AppText.bodyLg.copyWith(color: c.textMuted),
        ),
        gap,
        Field(
          label: 'Base Metal',
          code: 'REQ-MAT-01',
          child: Row(
            children: [
              for (var i = 0; i < _metals.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _MetalSwatch(
                    metal: _metals[i],
                    selected: d.quickBaseMetal == _metals[i].code,
                    onTap: () => setState(() => d.quickBaseMetal = _metals[i].code),
                  ),
                ),
              ],
            ],
          ),
        ),
        gap,
        Field(
          label: 'Alloy Purity',
          code: 'REQ-PUR-02',
          child: ChoiceGroup<String>(
            options: const ['14K', '18K', '22K'],
            selected: d.quickPurity,
            columns: 3,
            mono: true,
            onChanged: (v) => setState(() => d.quickPurity = v),
          ),
        ),
        gap,
        Field(
          label: 'Gemstone Inset',
          code: 'REQ-GEM-03',
          child: _GemToggle(value: d.quickGemstone, onChanged: (v) => setState(() => d.quickGemstone = v)),
        ),
        gap,
        Field(
          label: 'Target Budget (USD)',
          code: 'REQ-FIN-04',
          child: _BudgetField(
            controller: _budget,
            onChanged: (v) => setState(() => d.budget = double.tryParse(v.replaceAll(',', ''))),
          ),
        ),
        gap,
        Field(
          label: 'Delivery Target',
          code: 'REQ-TML-05',
          child: _DeliveryTile(value: d.deliveryDate, onTap: _pickDate),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MetalSwatch extends StatelessWidget {
  const _MetalSwatch({required this.metal, required this.selected, required this.onTap});

  final _Metal metal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hi = c.gold;
    return Material(
      color: selected ? c.goldSoft : (c.isDark ? c.surfaceHigh : c.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? hi : c.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 112,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.isDark ? c.surface : c.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border),
                      ),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [metal.light, metal.deep],
                          ),
                          boxShadow: [BoxShadow(color: metal.deep.withValues(alpha: 0.4), blurRadius: 12)],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(metal.code, style: AppText.monoSm.copyWith(color: selected ? hi : c.textMuted)),
                  ],
                ),
              ),
              if (selected) Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, size: 16, color: hi)),
            ],
          ),
        ),
      ),
    );
  }
}

/// NO / YES segmented control with a sliding indicator.
class _GemToggle extends StatelessWidget {
  const _GemToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget option(bool v, IconData icon, String label) {
      final on = v == value;
      final fg = on ? c.text : c.textFaint;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(v),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(label, style: AppText.monoLg.copyWith(color: fg)),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.isDark ? c.bg : c.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: c.isDark
                      ? null
                      : [BoxShadow(color: c.text.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))],
                ),
              ),
            ),
          ),
          Row(children: [option(false, Icons.block, 'NO'), option(true, Icons.diamond_outlined, 'YES')]),
        ],
      ),
    );
  }
}

class _BudgetField extends StatelessWidget {
  const _BudgetField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final big = AppText.monoLg.copyWith(fontSize: 24, height: 1.3);
    return Stack(
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          textAlign: TextAlign.right,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          style: big.copyWith(color: c.text),
          decoration: InputDecoration(
            hintText: '0,000',
            hintStyle: big.copyWith(color: c.textFaint.withValues(alpha: 0.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            prefixIconConstraints: const BoxConstraints(),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Text(r'$', style: AppText.monoLg.copyWith(fontSize: 20, color: c.gold)),
            ),
          ),
        ),
        Positioned(right: 16, bottom: 0, child: Container(width: 32, height: 2, color: c.gold.withValues(alpha: 0.6))),
      ],
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = value;
    String sub = 'Est. 4-6 weeks standard';
    if (v != null) {
      final days = v.difference(DateTime.now()).inDays + 1;
      sub = days >= 14 ? '${(days / 7).round()} weeks from today' : '$days days from today · rush';
    }
    return Material(
      color: c.isDark ? c.surfaceHigh : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.isDark ? c.bg : c.surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Icon(Icons.calendar_month_outlined, color: c.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v == null ? 'Select Date' : Fmt.dateLong(v), style: AppText.monoLg.copyWith(color: c.text)),
                    const SizedBox(height: 2),
                    Text(sub, style: AppText.monoSm.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

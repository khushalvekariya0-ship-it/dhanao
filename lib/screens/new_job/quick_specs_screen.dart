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
    const gap = SizedBox(height: 32);
    // The design's bottom bar (square save button + CTA) isn't supported by WizardScaffold, so the step is
    // wrapped in an outer Scaffold that owns the bar.
    return Scaffold(
      bottomNavigationBar: _BottomBar(
        label: 'Continue to Review',
        onSave: () => showSnack(context, 'Draft saved', icon: Icons.save_outlined),
        onContinue: () => Navigator.pushNamed(context, Routes.confirmOrder),
      ),
      body: WizardScaffold(
        title: 'NEW JOB',
        step: 3,
        totalSteps: 4,
        stepLabel: 'Material Selection',
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Text('Material Selection', style: AppText.headlineLg.copyWith(fontSize: 24, height: 32 / 24)),
          const SizedBox(height: 8),
          Text(
            'Specify the foundational elements for your custom piece.',
            style: AppText.bodyLg.copyWith(color: c.textMuted),
          ),
          gap,
          _ReqField(
            label: 'Base Metal',
            code: 'REQ-MAT-01',
            child: Row(
              children: [
                for (var i = 0; i < _metals.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
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
          _ReqField(
            label: 'Alloy Purity',
            code: 'REQ-PUR-02',
            child: Row(
              children: [
                for (final p in const ['14K', '18K', '22K']) ...[
                  if (p != '14K') const SizedBox(width: 12),
                  Expanded(
                    child: _PurityBox(
                      label: p,
                      selected: d.quickPurity == p,
                      onTap: () => setState(() => d.quickPurity = p),
                    ),
                  ),
                ],
              ],
            ),
          ),
          gap,
          _ReqField(
            label: 'Gemstone Inset',
            code: 'REQ-GEM-03',
            child: _GemToggle(value: d.quickGemstone, onChanged: (v) => setState(() => d.quickGemstone = v)),
          ),
          gap,
          _ReqField(
            label: 'Target Budget (USD)',
            code: 'REQ-FIN-04',
            child: _BudgetField(
              controller: _budget,
              onChanged: (v) => setState(() => d.budget = double.tryParse(v.replaceAll(',', ''))),
            ),
          ),
          gap,
          _ReqField(
            label: 'Delivery Target',
            code: 'REQ-TML-05',
            child: _DeliveryTile(value: d.deliveryDate, onTap: _pickDate),
          ),
        ],
      ),
    );
  }
}

/// Mono caps label with the gold requirement code on the right.
class _ReqField extends StatelessWidget {
  const _ReqField({required this.label, required this.code, required this.child});

  final String label;
  final String code;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label.toUpperCase(), style: AppText.monoCaps.copyWith(fontSize: 12, color: c.text)),
            ),
            Text(code, style: AppText.monoLg.copyWith(fontSize: 13, color: c.gold)),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

/// Resting fill of the option tiles (surface-container-high in dark, white in light).
Color _tileColor(DhColors c) => c.isDark ? c.surfaceHigh : c.surface;

List<BoxShadow>? _tileShadow(DhColors c) =>
    c.isDark ? null : [BoxShadow(color: c.text.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))];

class _MetalSwatch extends StatelessWidget {
  const _MetalSwatch({required this.metal, required this.selected, required this.onTap});

  final _Metal metal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hi = c.gold;
    final radius = BorderRadius.circular(8);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: _tileShadow(c)),
      child: Material(
        color: _tileColor(c),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? hi.withValues(alpha: c.isDark ? 0.6 : 0.8) : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      metal.deep.withValues(alpha: c.isDark ? 0.2 : 0.12),
                      metal.deep.withValues(alpha: 0),
                    ],
                  )
                : null,
          ),
          child: InkWell(
            onTap: onTap,
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
                            border: Border.all(color: c.borderStrong.withValues(alpha: 0.5)),
                          ),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [metal.light, metal.deep],
                              ),
                              boxShadow: [BoxShadow(color: metal.deep.withValues(alpha: 0.4), blurRadius: 12)],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(metal.code, style: AppText.monoSm.copyWith(color: selected ? hi : c.textMuted)),
                      ],
                    ),
                  ),
                  if (selected) Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, size: 16, color: hi)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tall mono purity button (14K / 18K / 22K).
class _PurityBox extends StatelessWidget {
  const _PurityBox({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = BorderRadius.circular(4);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: _tileShadow(c)),
      child: Material(
        color: selected ? c.goldSoft : _tileColor(c),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? c.gold : c.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 64,
            child: Center(
              child: Text(
                label,
                style: AppText.monoLg.copyWith(
                  fontSize: 16,
                  letterSpacing: 1.2,
                  color: selected ? c.gold : c.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky footer from the design: square save button + primary CTA.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.label, required this.onSave, required this.onContinue});

  final String label;
  final VoidCallback onSave;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            Tooltip(
              message: 'Save draft',
              child: Material(
                color: c.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: c.borderStrong.withValues(alpha: c.isDark ? 0.8 : 0.6)),
                ),
                child: InkWell(
                  onTap: onSave,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(dimension: 56, child: Icon(Icons.save_outlined, color: c.text)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  backgroundColor: c.isDark ? c.action : c.gold,
                  foregroundColor: c.isDark ? c.onAction : c.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleMd.copyWith(fontSize: 16, letterSpacing: 0.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
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
      final fg = on ? c.text : c.textMuted;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(v),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Text(label, style: AppText.monoLg.copyWith(fontSize: 16, color: fg)),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceHigh : c.surfaceHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.isDark ? c.border : c.borderStrong.withValues(alpha: 0.5)),
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
                  borderRadius: BorderRadius.circular(4),
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
    final radius = BorderRadius.circular(8);
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
            hintStyle: big.copyWith(color: c.textMuted.withValues(alpha: c.isDark ? 0.3 : 0.5)),
            filled: true,
            fillColor: _tileColor(c),
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: c.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: c.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: c.gold, width: 2),
            ),
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
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: _tileShadow(c)),
      child: Material(
        color: _tileColor(c),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.isDark ? c.bg : c.surfaceLow,
                    borderRadius: BorderRadius.circular(4),
                    border: c.isDark ? null : Border.all(color: c.border),
                  ),
                  child: Icon(Icons.calendar_month_outlined, color: c.gold, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v == null ? 'Select Date' : Fmt.dateLong(v),
                        style: AppText.monoLg.copyWith(fontSize: 15, color: c.text),
                      ),
                      const SizedBox(height: 2),
                      Text(sub, style: AppText.monoSm.copyWith(fontSize: 10, color: c.textMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

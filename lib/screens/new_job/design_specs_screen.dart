import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Full job order — Step 1 (Design): size, setting, finish, profile, side stones and priorities.
class DesignSpecsScreen extends StatefulWidget {
  const DesignSpecsScreen({super.key});

  @override
  State<DesignSpecsScreen> createState() => _DesignSpecsScreenState();
}

const _settingStyles = <(String, IconData)>[
  ('Prong', Icons.diamond_outlined),
  ('Bezel', Icons.circle_outlined),
  ('Halo', Icons.blur_on),
  ('Tension', Icons.filter_center_focus),
  ('Other', Icons.more_horiz),
];
const _finishes = <(String, IconData)>[
  ('High Polish', Icons.flare),
  ('Matte/Satin', Icons.texture),
  ('Hammered', Icons.hardware_outlined),
  ('Brushed', Icons.format_line_spacing),
];
const _profiles = <(String, IconData)>[
  ('Round', Icons.circle_outlined),
  ('Flat', Icons.crop_7_5_outlined),
  ('Knife-Edge', Icons.change_history),
];
const _sideStones = <(String, IconData)>[
  ('None', Icons.block),
  ('Pavé', Icons.grain),
  ('Channel', Icons.view_column_outlined),
  ('Shared Prong', Icons.grid_view),
];
const _priorities = <(String, IconData)>[
  ('Match Exactly', Icons.compare_outlined),
  ('Show Off Stone', Icons.diamond_outlined),
  ('Strong & Safe', Icons.shield_outlined),
  ('Other Idea', Icons.add_circle_outline),
];

class _DesignSpecsScreenState extends State<DesignSpecsScreen> {
  final _length = TextEditingController();
  final _width = TextEditingController();

  bool get _isRing => app.draft.productCategory.contains('Ring');
  bool get _us => app.draft.sizeSystem != 'India';

  @override
  void initState() {
    super.initState();
    final m = RegExp(r'Dimensions: ([\d.—]+) × ([\d.—]+) mm').firstMatch(app.draft.notes);
    if (m != null) {
      _length.text = m.group(1)!.replaceAll('—', '');
      _width.text = m.group(2)!.replaceAll('—', '');
    }
  }

  @override
  void dispose() {
    _length.dispose();
    _width.dispose();
    super.dispose();
  }

  double get _size => double.tryParse(app.draft.ringSize) ?? (_us ? 6.5 : 14);

  String _fmtSize(double v) => _us ? v.toStringAsFixed(1) : v.toStringAsFixed(0);

  void _stepSize(int dir) {
    final (min, max, step) = _us ? (3.0, 13.0, 0.5) : (1.0, 30.0, 1.0);
    setState(() => app.draft.ringSize = _fmtSize((_size + dir * step).clamp(min, max).toDouble()));
  }

  /// Switches US ↔ India, converting the current size via inner circumference.
  void _setSystem(String system) {
    final d = app.draft;
    if (d.sizeSystem == system) return;
    final v = _size;
    setState(() {
      if (system == 'India') {
        d.ringSize = (2.55 * v - 2.5).round().clamp(1, 30).toString();
      } else {
        final us = (((v + 2.5) / 2.55) * 2).round() / 2;
        d.ringSize = us.clamp(3.0, 13.0).toStringAsFixed(1);
      }
      d.sizeSystem = system;
    });
  }

  void _stepBand(int dir) {
    setState(() => app.draft.bandWidthMm = (app.draft.bandWidthMm + dir * 0.5).clamp(1.5, 8.0).toDouble());
  }

  void _next() {
    if (!_isRing) {
      final d = app.draft;
      final l = _length.text.trim();
      final w = _width.text.trim();
      final lines = d.notes.split('\n').where((x) => x.trim().isNotEmpty && !x.startsWith('Dimensions:')).toList();
      if (l.isNotEmpty || w.isNotEmpty) {
        lines.add('Dimensions: ${l.isEmpty ? '—' : l} × ${w.isEmpty ? '—' : w} mm');
      }
      d.notes = lines.join('\n');
    }
    Navigator.pushNamed(context, Routes.metal);
  }

  Widget _single(List<(String, IconData)> options, String selected, int columns, ValueChanged<String> onChanged) {
    return OptionLayout(
      columns: columns,
      children: [
        for (final (name, icon) in options)
          _IconTile(icon: icon, label: name, selected: selected == name, onTap: () => setState(() => onChanged(name))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = app.draft;
    final ring = _isRing;
    return WizardScaffold(
      title: 'Step 1: Specifications',
      step: 1,
      totalSteps: 4,
      stepLabel: 'Design',
      ctaLabel: 'Next Step',
      onCta: _next,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.isDark ? c.surface : c.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Text('SELECTED TYPE', style: AppText.labelSm.copyWith(color: c.textMuted, letterSpacing: 1.2)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  d.productCategory,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.titleMd,
                ),
              ),
            ],
          ),
        ),
        if (ring) ...[
          _Title(
            'Size & Details',
            trailing: _MiniToggle(
              options: const ['US', 'India'],
              selected: _us ? 'US' : 'India',
              onChanged: _setSystem,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _StepperField(
                  label: 'Ring Size (${_us ? 'US' : 'India'})',
                  value: d.ringSize,
                  onMinus: _size > (_us ? 3 : 1) ? () => _stepSize(-1) : null,
                  onPlus: _size < (_us ? 13 : 30) ? () => _stepSize(1) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StepperField(
                  label: 'Band Width (mm)',
                  value: d.bandWidthMm.toStringAsFixed(1),
                  onMinus: d.bandWidthMm > 1.5 ? () => _stepBand(-1) : null,
                  onPlus: d.bandWidthMm < 8.0 ? () => _stepBand(1) : null,
                ),
              ),
            ],
          ),
        ] else ...[
          const _Title('Dimensions'),
          Row(
            children: [
              Expanded(
                child: _MmField(label: 'Length (mm)', controller: _length),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MmField(label: 'Width (mm)', controller: _width),
              ),
            ],
          ),
        ],
        const _Title('Setting Style'),
        _single(_settingStyles, d.settingStyle, 3, (v) => d.settingStyle = v),
        const _Title('Metal Finish'),
        _single(_finishes, d.metalFinish, 2, (v) => d.metalFinish = v),
        if (ring) ...[const _Title('Band Profile'), _single(_profiles, d.bandProfile, 3, (v) => d.bandProfile = v)],
        const _Title('Side Stone Setting'),
        _single(_sideStones, d.sideStoneSetting, 2, (v) => d.sideStoneSetting = v),
        _Title(
          'What matters most?',
          trailing: Text('SELECT ANY', style: AppText.monoCaps.copyWith(color: c.textFaint)),
        ),
        OptionLayout(
          columns: 2,
          children: [
            for (final (name, icon) in _priorities)
              _IconTile(
                icon: icon,
                label: name,
                accentIcon: true,
                multi: true,
                selected: d.priorities.contains(name),
                onTap: () =>
                    setState(() => d.priorities.contains(name) ? d.priorities.remove(name) : d.priorities.add(name)),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppText.titleMd)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Fixed-height selectable tile (icon over label) so grid rows line up.
class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentIcon = false,
    this.multi = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Always tint the icon (the "What matters most?" cards).
  final bool accentIcon;
  final bool multi;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = c.isDark ? c.gold : c.accent;
    return Material(
      color: selected ? c.accentSoft : (c.isDark ? c.surface : c.surfaceLow),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? on : c.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 96,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 30, color: selected || accentIcon ? on : c.text),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.labelMd.copyWith(
                          fontSize: 13,
                          color: selected ? on : c.text,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (multi && selected) Positioned(top: 6, right: 6, child: Icon(Icons.check_circle, size: 16, color: on)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({required this.label, required this.value, this.onMinus, this.onPlus});

  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodySm.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.isDark ? c.surfaceLow : c.surfaceHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              _StepButton(icon: Icons.remove, onTap: onMinus),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: AppText.monoLg.copyWith(fontSize: 16, color: c.text),
                ),
              ),
              _StepButton(icon: Icons.add, onTap: onPlus),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.isDark ? c.surfaceHigh : c.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(icon, size: 20, color: onTap == null ? c.textFaint : (c.isDark ? c.gold : c.accent)),
        ),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({required this.options, required this.selected, required this.onChanged});

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceLow : c.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: o == selected ? (c.isDark ? c.surfaceHighest : c.surface) : c.surface.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  o,
                  style: AppText.monoCaps.copyWith(color: o == selected ? (c.isDark ? c.gold : c.text) : c.textFaint),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MmField extends StatelessWidget {
  const _MmField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      style: AppText.monoLg.copyWith(color: c.text),
      decoration: InputDecoration(labelText: label, suffixText: 'mm', hintText: '0.0'),
    );
  }
}

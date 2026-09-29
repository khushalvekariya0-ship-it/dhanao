import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Single-select option boxes ("18K / 14K / 22K"). Lays out as a wrap, or as
/// an equal-width grid when [columns] is set.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelOf,
    this.columns,
    this.mono = false,
    this.dense = false,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;
  final int? columns;

  /// Use JetBrains Mono (for codes like "Y.GOLD", "VVS1").
  final bool mono;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return OptionLayout(
      columns: columns,
      children: [
        for (final o in options)
          OptionBox(
            label: labelOf?.call(o) ?? o.toString(),
            selected: o == selected,
            mono: mono,
            dense: dense,
            onTap: () => onChanged(o),
          ),
      ],
    );
  }
}

/// Multi-select variant of [ChoiceGroup].
class MultiChoiceGroup<T> extends StatelessWidget {
  const MultiChoiceGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelOf,
    this.columns,
    this.mono = false,
    this.dense = false,
  });

  final List<T> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final String Function(T)? labelOf;
  final int? columns;
  final bool mono;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return OptionLayout(
      columns: columns,
      children: [
        for (final o in options)
          OptionBox(
            label: labelOf?.call(o) ?? o.toString(),
            selected: selected.contains(o),
            mono: mono,
            dense: dense,
            showCheck: true,
            onTap: () {
              final next = {...selected};
              next.contains(o) ? next.remove(o) : next.add(o);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// Lays children out as a wrap, or a fixed-column grid.
class OptionLayout extends StatelessWidget {
  const OptionLayout({super.key, required this.children, this.columns, this.spacing = 8});

  final List<Widget> children;
  final int? columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (columns == null) {
      return Wrap(spacing: spacing, runSpacing: spacing, children: children);
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns!) {
      final slice = children.sublist(i, (i + columns!).clamp(0, children.length));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var j = 0; j < columns!; j++) ...[
              if (j > 0) SizedBox(width: spacing),
              Expanded(child: j < slice.length ? slice[j] : const SizedBox()),
            ],
          ],
        ),
      );
      if (i + columns! < children.length) rows.add(SizedBox(height: spacing));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// One selectable text box.
class OptionBox extends StatelessWidget {
  const OptionBox({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.mono = false,
    this.dense = false,
    this.showCheck = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;
  final bool dense;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final base = mono ? AppText.monoMd.copyWith(fontWeight: FontWeight.w500) : AppText.labelMd.copyWith(fontSize: 13);
    return Material(
      color: selected ? c.accentSoft : (c.isDark ? c.surfaceLow : c.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: selected ? c.accent : c.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 8 : 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showCheck && selected) ...[Icon(Icons.check, size: 16, color: c.accent), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: base.copyWith(color: selected ? (c.isDark ? c.gold : c.accent) : c.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selectable card with an icon, title and optional subtitle — used for
/// product categories, job types, sourcing options.
class IconOptionCard extends StatelessWidget {
  const IconOptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.horizontal = false,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Row layout (icon left, text right) instead of stacked.
  final bool horizontal;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ic = iconColor ?? (selected ? (c.isDark ? c.gold : c.accent) : c.text);
    final text = Column(
      crossAxisAlignment: horizontal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: horizontal ? TextAlign.start : TextAlign.center,
          style: AppText.titleMd.copyWith(fontSize: 15),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: horizontal ? TextAlign.start : TextAlign.center,
            style: AppText.bodySm.copyWith(color: c.textMuted),
          ),
        ],
      ],
    );
    return Material(
      color: selected ? c.accentSoft : (c.isDark ? c.surface : c.surfaceLow),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? c.accent : (c.isDark ? c.border : Colors.transparent),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: horizontal
              ? Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ic.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: ic.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icon, color: ic, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: text),
                    trailing ?? Icon(Icons.chevron_right, color: c.textFaint),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: ic, size: 28),
                    const SizedBox(height: 10),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Two-or-more segment toggle in a rounded well ("Needs Sourcing | In Stock").
class DhSegmented<T> extends StatelessWidget {
  const DhSegmented({super.key, required this.options, required this.selected, required this.onChanged, this.labelOf});

  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.isDark ? c.surfaceLow : c.surfaceHigh, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: o == selected ? (c.isDark ? c.surfaceHighest : c.surface) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: o == selected && !c.isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labelOf?.call(o) ?? o.toString(),
                    textAlign: TextAlign.center,
                    style: AppText.labelMd.copyWith(
                      fontSize: 13,
                      color: o == selected ? (c.isDark ? c.gold : c.text) : c.textFaint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A row with title/subtitle and a trailing switch.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: c.textMuted), const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleMd.copyWith(fontSize: 15)),
                  if (subtitle != null) Text(subtitle!, style: AppText.bodySm.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// Field label + child with consistent spacing.
class Field extends StatelessWidget {
  const Field({super.key, required this.label, required this.child, this.code, this.hint});

  final String label;
  final Widget child;

  /// Optional mono requirement code on the right ("REQ-MAT-01").
  final String? code;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label.toUpperCase(), style: AppText.labelSm.copyWith(color: c.textMuted)),
            ),
            if (code != null) Text(code!, style: AppText.monoSm.copyWith(color: c.textFaint)),
          ],
        ),
        const SizedBox(height: 8),
        child,
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(hint!, style: AppText.bodySm.copyWith(color: c.textFaint)),
        ],
      ],
    );
  }
}

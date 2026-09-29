import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Standard content card: surface fill, 1px hairline border, 8px radius.
class DhCard extends StatelessWidget {
  const DhCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.tag,
    this.accentTop = false,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  /// Small monospaced "technical header" ID shown top-right (e.g. "01/REQ").
  final String? tag;

  /// Draws a thin accent line along the top edge (dark-theme card header).
  final bool accentTop;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget body = Padding(padding: padding, child: child);
    if (tag != null) {
      body = Stack(
        children: [
          body,
          Positioned(
            top: 8,
            right: 10,
            child: Text(tag!, style: AppText.monoSm.copyWith(color: c.textFaint)),
          ),
        ],
      );
    }
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? c.border),
      ),
      foregroundDecoration: accentTop
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border(top: BorderSide(color: c.gold, width: 1.5)),
            )
          : null,
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// UPPERCASE tracked label used for section headers and field labels.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = EdgeInsets.zero, this.mono = false});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// Use the JetBrains Mono caps style instead of Hanken label.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = (mono ? AppText.monoCaps : AppText.labelSm).copyWith(color: c.textMuted);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(child: Text(text.toUpperCase(), style: style)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Section heading with optional action on the right ("View All").
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.icon, this.action, this.onAction, this.trailing});

  final String title;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: c.accent), const SizedBox(width: 8)],
        Expanded(child: Text(title, style: AppText.headlineSm)),
        ?trailing,
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

/// Rectangular status tag: 1px border + 10% tint of [color].
class StatusChip extends StatelessWidget {
  const StatusChip(
    this.label, {
    super.key,
    required this.color,
    this.icon,
    this.dot = false,
    this.filled = false,
    this.mono = true,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Show a small leading dot instead of an icon.
  final bool dot;

  /// Solid fill with white/dark text.
  final bool filled;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = filled ? (c.isDark ? const Color(0xFF041329) : Colors.white) : color;
    final style = (mono ? AppText.monoCaps.copyWith(fontSize: 10) : AppText.labelMd).copyWith(color: fg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: filled ? color : color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(mono ? label.toUpperCase() : label, style: style),
        ],
      ),
    );
  }
}

/// Label on top, value below — for spec grids ("MATERIAL / 18K Yellow Gold").
class LabelValue extends StatelessWidget {
  const LabelValue(this.label, this.value, {super.key, this.mono = false, this.valueStyle, this.icon});

  final String label;
  final String value;
  final bool mono;
  final TextStyle? valueStyle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: c.textFaint), const SizedBox(width: 6)],
            Flexible(
              child: Text(label.toUpperCase(), style: AppText.labelSm.copyWith(color: c.textFaint)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: valueStyle ?? (mono ? AppText.monoLg : AppText.titleMd)),
      ],
    );
  }
}

/// Horizontal "Label ........ value" row with an optional divider.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(
    this.label,
    this.value, {
    super.key,
    this.mono = true,
    this.bold = false,
    this.valueColor,
    this.divider = false,
  });

  final String label;
  final String value;
  final bool mono;
  final bool bold;
  final Color? valueColor;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final vs = (mono ? AppText.monoMd : AppText.bodyMd).copyWith(
      color: valueColor ?? c.text,
      fontWeight: bold ? FontWeight.w700 : null,
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: AppText.bodyMd.copyWith(color: c.textMuted, fontWeight: bold ? FontWeight.w600 : null),
            ),
          ),
          const SizedBox(width: 12),
          // Expanded so right-aligned values sit flush with the right edge.
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.right, style: vs),
          ),
        ],
      ),
    );
  }
}

/// Big number tile for dashboards ("AT CASTING / 12").
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.color, this.onTap, this.icon});

  final String label;
  final String value;
  final Color? color;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.isDark ? c.surfaceHigh : c.surfaceLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (color != null) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (icon != null) ...[Icon(icon, size: 14, color: c.textFaint), const SizedBox(width: 6)],
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSm.copyWith(color: c.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(value, style: AppText.headlineLg.copyWith(fontFamily: AppText.sans)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circle avatar that shows an asset image, a local file, or initials.
class DhAvatar extends StatelessWidget {
  const DhAvatar({super.key, this.asset, this.name, this.size = 36, this.dark = false});

  final String? asset;
  final String? name;
  final double size;

  /// Use the solid dark initials style (e.g. "SD" retailer badge).
  final bool dark;

  String get _initials {
    final n = (name ?? '?').trim();
    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (asset != null) {
      return ClipOval(
        child: Image.asset(asset!, width: size, height: size, fit: BoxFit.cover),
      );
    }
    final bg = dark ? (c.isDark ? c.gold : const Color(0xFF131B2E)) : c.surfaceHighest;
    final fg = dark ? (c.isDark ? c.onAction : Colors.white) : c.textMuted;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        _initials,
        style: AppText.labelMd.copyWith(color: fg, fontSize: size * 0.34),
      ),
    );
  }
}

/// Rounded image from an asset path, a local file path, or a placeholder.
class DhImage extends StatelessWidget {
  const DhImage({
    super.key,
    this.asset,
    this.file,
    this.width,
    this.height,
    this.radius = 8,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.diamond_outlined,
  });

  final String? asset;

  /// Local device path (from image picker).
  final String? file;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget img;
    if (file != null) {
      img = Image.file(File(file!), width: width, height: height, fit: fit);
    } else if (asset != null) {
      img = Image.asset(asset!, width: width, height: height, fit: fit);
    } else {
      img = Container(
        width: width,
        height: height,
        color: c.surfaceHigh,
        alignment: Alignment.center,
        child: Icon(placeholderIcon, color: c.textFaint, size: 24),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

/// Thin progress bar (4px) — completed part glows gold in dark theme.
class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, required this.value, this.color, this.height = 4});

  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = color ?? c.accent;
    return Container(
      height: height,
      decoration: BoxDecoration(color: c.surfaceHighest, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0, 1).toDouble(),
        child: Container(
          decoration: BoxDecoration(
            color: fg,
            borderRadius: BorderRadius.circular(height),
            boxShadow: c.isDark ? [BoxShadow(color: fg.withValues(alpha: 0.5), blurRadius: 6)] : null,
          ),
        ),
      ),
    );
  }
}

/// Full-width primary action (black in light theme, gold in dark theme).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.expanded = true,
    this.color,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool expanded;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final btn = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        minimumSize: Size(expanded ? double.infinity : 0, 52),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          // Flexible needs bounded width; a non-expanded button can sit in an unbounded Row slot.
          if (expanded) Flexible(child: Text(label, overflow: TextOverflow.ellipsis)) else Text(label),
          if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: 20)],
        ],
      ),
    );
    return btn;
  }
}

/// Outlined secondary action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, this.onPressed, this.icon, this.expanded = true, this.color});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  /// Tints text + border (e.g. danger red for "Report Issue").
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(expanded ? double.infinity : 0, 52),
        foregroundColor: color,
        side: color == null ? null : BorderSide(color: color!.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          // Flexible needs bounded width; a non-expanded button can sit in an unbounded Row slot.
          if (expanded) Flexible(child: Text(label, overflow: TextOverflow.ellipsis)) else Text(label),
        ],
      ),
    );
  }
}

/// Centered icon + message for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: c.textFaint.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(color: c.textFaint),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Floating snackbar helper.
void showSnack(BuildContext context, String message, {IconData? icon}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: context.c.gold), const SizedBox(width: 10)],
          Expanded(child: Text(message)),
        ],
      ),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// Yes/No confirmation dialog. Returns true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirm',
  String cancel = 'Cancel',
  bool destructive = false,
}) async {
  final c = context.c;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancel, style: TextStyle(color: c.textMuted)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive ? FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white) : null,
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

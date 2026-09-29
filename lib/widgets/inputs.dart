import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';
import 'sheets.dart';

/// Paints a dashed rounded-rect border around its child.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    this.color,
    this.radius = 8,
    this.dash = 6,
    this.gap = 4,
    this.strokeWidth = 1.2,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    // Foreground so filled children (e.g. UploadBox's Material) don't cover the dashes.
    return CustomPaint(
      foregroundPainter: _DashPainter(color ?? context.c.borderStrong, radius, dash, gap, strokeWidth),
      child: child,
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.radius, this.dash, this.gap, this.strokeWidth);

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect.deflate(strokeWidth / 2));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

/// Dashed drop-zone style upload target. Shows a preview when [imagePath] is set.
class UploadBox extends StatelessWidget {
  const UploadBox({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon = Icons.add_a_photo_outlined,
    this.imagePath,
    this.imageAsset,
    this.height = 140,
    this.filledIcon = false,
    this.onClear,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  /// Local file picked by the user.
  final String? imagePath;

  /// Bundled asset preview (for mock data).
  final String? imageAsset;
  final double height;

  /// Solid accent square behind the icon (product selection style).
  final bool filledIcon;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hasImage = imagePath != null || imageAsset != null;
    return DashedBorder(
      color: hasImage ? c.accent : c.borderStrong,
      child: Material(
        color: c.isDark ? c.surfaceLow.withValues(alpha: 0.6) : c.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: DhImage(file: imagePath, asset: imageAsset, radius: 6),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Row(
                          children: [
                            _pill(context, Icons.swap_horiz, 'Replace', onTap),
                            if (onClear != null) ...[
                              const SizedBox(width: 6),
                              _pill(context, Icons.close, null, onClear!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: filledIcon ? (c.isDark ? c.gold : const Color(0xFF6366F1)) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          size: 28,
                          color: filledIcon ? (c.isDark ? c.onAction : Colors.white) : c.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(title, textAlign: TextAlign.center, style: AppText.titleMd.copyWith(fontSize: 15)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          textAlign: TextAlign.center,
                          style: AppText.bodySm.copyWith(color: c.textFaint),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String? label, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(label, style: AppText.labelMd.copyWith(color: Colors.white)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks Camera vs Gallery, then returns the picked image path (or null).
Future<String?> pickImage(BuildContext context, {String title = 'Add Photo'}) async {
  final source = await showDhSheet<ImageSource>(
    context: context,
    builder: (ctx) {
      final c = ctx.c;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.headlineSm),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.photo_camera_outlined, color: c.accent),
                title: const Text('Take Photo'),
                subtitle: const Text('Use the camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: c.accent),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('JPEG, PNG up to 10MB'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (source == null) return null;
  try {
    final x = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 2000);
    return x?.path;
  } catch (e) {
    if (context.mounted) showSnack(context, 'Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}');
    return null;
  }
}

/// Tappable read-only field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint = 'Select Date',
    this.firstDate,
    this.lastDate,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.isDark ? c.surfaceLow : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () async {
          final now = DateTime.now();
          var first = firstDate ?? now.subtract(const Duration(days: 1));
          var last = lastDate ?? now.add(const Duration(days: 730));
          final initial = value ?? now.add(const Duration(days: 30));
          // showDatePicker asserts first <= initial <= last; widen the range for old/far values.
          if (initial.isBefore(first)) first = initial;
          if (initial.isAfter(last)) last = initial;
          final d = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
          if (d != null) onChanged(d);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 18, color: c.textFaint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value == null ? hint : Fmt.dateLong(value!),
                  style: (value == null ? AppText.bodyMd : AppText.monoMd).copyWith(
                    color: value == null ? c.textFaint : c.text,
                  ),
                ),
              ),
              Icon(Icons.expand_more, color: c.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field that keeps its own controller in sync with [value].
class DhTextField extends StatefulWidget {
  const DhTextField({
    super.key,
    this.value = '',
    this.onChanged,
    this.hint,
    this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.mono = false,
  });

  final String value;
  final ValueChanged<String>? onChanged;
  final String? hint;
  final String? label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? prefixText;
  final String? suffixText;
  final IconData? prefixIcon;
  final bool mono;

  @override
  State<DhTextField> createState() => _DhTextFieldState();
}

class _DhTextFieldState extends State<DhTextField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(DhTextField old) {
    super.didUpdateWidget(old);
    // Pick up values changed from outside (e.g. a stepper) without fighting the user's typing.
    if (widget.value != old.value && widget.value != _ctrl.text) _ctrl.text = widget.value;
  }

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
      keyboardType: widget.keyboardType,
      style: (widget.mono ? AppText.monoLg : AppText.bodyMd).copyWith(color: c.text),
      decoration: InputDecoration(
        hintText: widget.hint,
        labelText: widget.label,
        prefixText: widget.prefixText,
        suffixText: widget.suffixText,
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 20),
      ),
    );
  }
}

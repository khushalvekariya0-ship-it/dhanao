import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';

/// Modal bottom sheet with a drag handle and an explicit close (✕) button.
///
/// iOS has no system back button, so every sheet must be closable from the UI
/// — use this instead of `showModalBottomSheet`.
Future<T?> showDhSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    shape: shape,
    showDragHandle: false,
    builder: (ctx) => _SheetFrame(child: builder(ctx)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: c.borderStrong, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close, color: c.textMuted),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ],
          ),
        ),
        Flexible(child: child),
      ],
    );
  }
}

/// Full-screen zoomable image with a close (✕) button. Pass a bundled [asset]
/// or a local [file] path.
Future<void> showImageViewer(BuildContext context, {String? asset, String? file, String? caption}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    builder: (ctx) => ImageViewerFrame(
      caption: caption,
      child: DhImage(asset: asset, file: file, fit: BoxFit.contain, radius: 0),
    ),
  );
}

/// Chrome for full-screen viewers: zoomable [child], close button top-right, optional caption.
class ImageViewerFrame extends StatelessWidget {
  const ImageViewerFrame({super.key, required this.child, this.caption, this.zoom = true});

  final Widget child;
  final String? caption;

  /// Wrap [child] in an InteractiveViewer (turn off when the child is already a zoomable gallery).
  final bool zoom;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(child: zoom ? InteractiveViewer(maxScale: 5, child: Center(child: child)) : child),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  tooltip: 'Close',
                  style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
          ),
          if (caption != null)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(caption!, style: AppText.monoMd.copyWith(color: Colors.white70)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

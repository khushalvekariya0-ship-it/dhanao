import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';
import 'start_new_job_screen.dart' show BlueprintBackdrop;

/// Quick flow step 2/4: capture reference photos, a voice note or a file.
class CaptureDetailsScreen extends StatefulWidget {
  const CaptureDetailsScreen({super.key});

  @override
  State<CaptureDetailsScreen> createState() => _CaptureDetailsScreenState();
}

String _basename(String path) => path.split(RegExp(r'[\\/]')).last;

class _CaptureDetailsScreenState extends State<CaptureDetailsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 20))
    ..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _addImage({String title = 'Capture Reference'}) async {
    final path = await pickImage(context, title: title);
    if (path == null || !mounted) return;
    setState(() => app.draft.referenceImages.add(path));
    showSnack(context, 'Reference added: ${_basename(path)}', icon: Icons.check_circle_outline);
  }

  Future<void> _recordVoice() async {
    final length = await showDhSheet<Duration>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const _VoiceRecorderSheet(),
    );
    if (length == null || !mounted) return;
    setState(() {
      app.draft.hasVoiceNote = true;
      app.draft.voiceNoteLength = length;
    });
    showSnack(context, 'Voice note saved (${Fmt.duration(length)})', icon: Icons.mic);
  }

  void _deleteVoice() {
    setState(() {
      app.draft.hasVoiceNote = false;
      app.draft.voiceNoteLength = Duration.zero;
    });
    showSnack(context, 'Voice note deleted', icon: Icons.delete_outline);
  }

  void _next() => Navigator.pushNamed(context, Routes.quickSpecs);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = app.draft;
    final images = d.referenceImages;
    return BlueprintBackdrop(
      child: WizardScaffold(
        title: 'NEW JOB',
        step: 2,
        totalSteps: 4,
        stepLabel: 'Media Capture',
        secondaryLabel: 'Skip',
        onSecondary: _next,
        ctaLabel: 'Continue',
        onCta: _next,
        children: [
          const SizedBox(height: 8),
          Text('Show us what you want to make.', textAlign: TextAlign.center, style: AppText.headlineMd),
          const SizedBox(height: 8),
          Text(
            'Capture a sketch, an existing piece, or describe it in your own words.',
            textAlign: TextAlign.center,
            style: AppText.bodyLg.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 28),
          _CapturePanel(
            spin: _spin,
            captured: images.isEmpty ? null : _basename(images.last),
            count: images.length,
            onTap: _addImage,
          ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionLabel('Captured references · ${images.length}', mono: true),
            const SizedBox(height: 10),
            _ThumbStrip(paths: images, onRemove: (i) => setState(() => images.removeAt(i))),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _ActionTile(icon: Icons.mic, label: 'Voice Note', active: d.hasVoiceNote, onTap: _recordVoice),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionTile(
                  icon: Icons.image,
                  label: 'Upload File',
                  corner: true,
                  onTap: () => _addImage(title: 'Upload File'),
                ),
              ),
            ],
          ),
          if (d.hasVoiceNote) ...[
            const SizedBox(height: 12),
            _VoiceNoteRow(length: d.voiceNoteLength, onRerecord: _recordVoice, onDelete: _deleteVoice),
          ],
        ],
      ),
    );
  }
}

/// Big square "TAP TO CAPTURE" target with a slowly turning hexagon and a dashed ring.
class _CapturePanel extends StatelessWidget {
  const _CapturePanel({required this.spin, required this.onTap, this.captured, this.count = 0});

  final Animation<double> spin;
  final VoidCallback onTap;
  final String? captured;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hi = c.isDark ? c.gold : c.text;
    final line = c.isDark ? c.textFaint.withValues(alpha: 0.45) : c.borderStrong;
    final done = captured != null;
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(box.maxWidth - 40, 280.0);
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: Material(
              color: c.isDark ? c.surface.withValues(alpha: 0.75) : c.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: c.isDark ? c.gold.withValues(alpha: 0.2) : c.border),
              ),
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _RingPainter(line, hexagon: false)),
                    RotationTransition(
                      turns: spin,
                      child: CustomPaint(painter: _RingPainter(line, hexagon: true)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: c.isDark
                                  ? [BoxShadow(color: c.gold.withValues(alpha: 0.28), blurRadius: 28, spreadRadius: 2)]
                                  : null,
                            ),
                            child: Icon(
                              done ? Icons.check_circle : Icons.photo_camera,
                              size: 52,
                              color: done ? c.success : hi,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            done ? captured! : 'TAP TO CAPTURE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: done
                                ? AppText.monoLg.copyWith(color: hi)
                                : AppText.titleMd.copyWith(color: hi, fontSize: 17, letterSpacing: 1.4),
                          ),
                          if (done) ...[
                            const SizedBox(height: 4),
                            Text(
                              count > 1 ? '$count references · tap to add more' : 'Tap to add another',
                              textAlign: TextAlign.center,
                              style: AppText.bodySm.copyWith(color: c.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, {required this.hexagon});

  final Color color;
  final bool hexagon;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (hexagon) {
      final r = size.shortestSide * 0.48;
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final a = -math.pi / 2 + i * math.pi / 3;
        final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path..close(), paint);
    } else {
      final rect = Rect.fromCircle(center: center, radius: size.shortestSide * 0.46);
      const dashes = 56;
      const sweep = 2 * math.pi / dashes;
      for (var i = 0; i < dashes; i++) {
        canvas.drawArc(rect, i * sweep, sweep * 0.4, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color || old.hexagon != hexagon;
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.paths, required this.onRemove});

  final List<String> paths;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SizedBox(
          width: 76,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DhImage(file: paths[i], radius: 8),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove(i),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.corner = false,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Small technical corner bracket (top-right), as on the "Upload File" tile.
  final bool corner;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = c.isDark ? c.gold : c.accent;
    return Material(
      color: c.isDark ? c.surfaceHigh.withValues(alpha: 0.85) : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? on : (c.isDark ? c.borderStrong.withValues(alpha: 0.5) : c.border)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (corner)
              Positioned(
                top: 8,
                right: 8,
                child: SizedBox.square(
                  dimension: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: c.textFaint),
                        right: BorderSide(color: c.textFaint),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: active ? c.accentSoft : (c.isDark ? c.surfaceHighest : c.surfaceLow),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: active ? on : c.text),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.monoLg.copyWith(color: c.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceNoteRow extends StatelessWidget {
  const _VoiceNoteRow({required this.length, required this.onRerecord, required this.onDelete});

  final Duration length;
  final VoidCallback onRerecord;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = c.isDark ? c.gold : c.accent;
    return DhCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: Icon(Icons.graphic_eq, color: on, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Client_Instructions.wav', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.monoMd),
                Text(
                  'VOICE NOTE · ${Fmt.duration(length)}',
                  style: AppText.monoCaps.copyWith(fontSize: 10, color: c.success),
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Re-record', icon: const Icon(Icons.refresh), onPressed: onRerecord),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline, color: c.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Simulated recorder: pulsing mic, live mm:ss timer and waveform. Pops with the recorded length.
class _VoiceRecorderSheet extends StatefulWidget {
  const _VoiceRecorderSheet();

  @override
  State<_VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<_VoiceRecorderSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_paused) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _paused ? _pulse.stop() : _pulse.repeat(reverse: true);
  }

  void _save() {
    final length = _elapsed < const Duration(seconds: 1) ? const Duration(seconds: 1) : _elapsed;
    Navigator.pop(context, length);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rec = c.danger;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Voice Note', style: AppText.headlineSm)),
                StatusChip(_paused ? 'Paused' : 'Recording', color: _paused ? c.textFaint : rec, dot: true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Describe the piece in your own words. Tap Stop & Save when you are done.',
              style: AppText.bodySm.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 132,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _paused ? 0.0 : _pulse.value;
                  return Center(
                    child: Container(
                      width: 96 + 32 * t,
                      height: 96 + 32 * t,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rec.withValues(alpha: 0.10 + 0.08 * t),
                      ),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _paused ? c.surfaceHighest : rec,
                          boxShadow: _paused ? null : [BoxShadow(color: rec.withValues(alpha: 0.4), blurRadius: 18)],
                        ),
                        child: Icon(
                          _paused ? Icons.mic_off : Icons.mic,
                          size: 34,
                          color: _paused ? c.textMuted : (c.isDark ? c.bg : c.surface),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(Fmt.duration(_elapsed), style: AppText.monoLg.copyWith(fontSize: 34, height: 1.2)),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: _paused ? 'Resume' : 'Pause',
                  onPressed: _togglePause,
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: _LiveWave(animation: _pulse, active: !_paused, color: rec),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: SecondaryButton('Discard', onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton('Stop & Save', icon: Icons.stop, onPressed: _save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveWave extends StatelessWidget {
  const _LiveWave({required this.animation, required this.active, required this.color});

  final Animation<double> animation;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final count = (box.maxWidth / 8).floor().clamp(0, 40);
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                Container(
                  width: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: active ? 6 + 28 * (math.sin(animation.value * math.pi + i * 0.8).abs()) : 6,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: active ? 0.85 : 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

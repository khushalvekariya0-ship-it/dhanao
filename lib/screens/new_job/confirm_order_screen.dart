import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';
import '../shell/home_shell.dart';

/// Quick flow step 4/4: review the captured parameters and create the job.
class ConfirmOrderScreen extends StatefulWidget {
  const ConfirmOrderScreen({super.key});

  @override
  State<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

/// Physical metal swatch gradients (same in both themes), keyed by quick-spec code.
const _swatches = {
  'Y.GOLD': [Color(0xFFFFE088), Color(0xFFD4AF37)],
  'W.METAL': [Color(0xFFF8FAFC), Color(0xFF9CA3AF)],
  'R.GOLD': [Color(0xFFE0BFB8), Color(0xFFB76E79)],
};

class _ConfirmOrderScreenState extends State<ConfirmOrderScreen> with SingleTickerProviderStateMixin {
  late final String _draftId = _makeDraftId();
  late final AnimationController _audio;
  bool _busy = false;

  static String _makeDraftId() {
    final now = DateTime.now();
    return 'DRAFT-${now.millisecondsSinceEpoch % 900 + 100}${String.fromCharCode(65 + now.second % 6)}';
  }

  @override
  void initState() {
    super.initState();
    final len = app.draft.voiceNoteLength;
    _audio = AnimationController(vsync: this, duration: len > Duration.zero ? len : const Duration(seconds: 80))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _audio.reset();
      });
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  String get _metalName => switch (app.draft.quickBaseMetal) {
    'W.METAL' => 'White Gold',
    'R.GOLD' => 'Rose Gold',
    _ => 'Yellow Gold',
  };

  void _toggleAudio() {
    _audio.isAnimating ? _audio.stop() : _audio.forward();
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Discard this job?',
      message: 'Captured media and material selections will be lost.',
      confirm: 'Discard',
      cancel: 'Keep Editing',
      destructive: true,
    );
    if (!ok || !mounted) return;
    app.resetDraft();
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<void> _confirm() async {
    _audio.stop();
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final d = app.draft;
    d.baseMetal = 'Gold';
    d.metalColor = switch (d.quickBaseMetal) {
      'W.METAL' => 'White',
      'R.GOLD' => 'Rose',
      _ => 'Yellow',
    };
    d.purity = d.quickPurity;
    d.targetUnitPrice = d.budget ?? d.targetUnitPrice;
    d.requestedDelivery = d.deliveryDate;
    if (d.notes.trim().isEmpty) d.notes = 'Quick capture · ${d.jobType}.';
    final job = app.createJobFromDraft();
    if (!d.quickGemstone) job.centerStone = '—';
    if (d.hasVoiceNote) {
      app.addFile(
        job,
        ProjectFile(
          name: 'Client_Instructions.wav',
          kind: FileKind.audio,
          jobId: job.id,
          sizeLabel: '${(d.voiceNoteLength.inSeconds * 0.09).toStringAsFixed(1)} MB',
        ),
      );
    }
    setState(() => _busy = false);
    await _showSuccess(job);
  }

  Future<void> _showSuccess(Job job) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final c = ctx.c;
        return PopScope(
          canPop: false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SuccessBadge(),
                  const SizedBox(height: 20),
                  Text('Job Created Successfully', textAlign: TextAlign.center, style: AppText.headlineMd),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surfaceHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.success.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'ID: ${job.id}',
                      style: AppText.monoLg.copyWith(fontSize: 16, color: c.success, letterSpacing: 1.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Parameters saved. Routing specs to CAD engineering and preliminary production queue.',
                    textAlign: TextAlign.center,
                    style: AppText.bodyMd.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    'View Job',
                    icon: Icons.open_in_new,
                    onPressed: () =>
                        Navigator.pushNamedAndRemoveUntil(ctx, Routes.job, (r) => r.isFirst, arguments: job.id),
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    'Return to Dashboard',
                    icon: Icons.dashboard_outlined,
                    onPressed: () {
                      Navigator.popUntil(ctx, (r) => r.isFirst);
                      homeTab.value = HomeTabs.dashboard;
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = app.draft;
    final image = d.referenceImages.isEmpty ? null : d.referenceImages.first;
    final fileName = image == null ? 'IMG_8842.RAW' : image.split(RegExp(r'[\\/]')).last.toUpperCase();
    return WizardScaffold(
      title: 'New Job',
      step: 4,
      totalSteps: 4,
      stepLabel: 'Final Review',
      children: [
        Text('Review Details', style: AppText.headlineLg),
        const SizedBox(height: 6),
        Text(
          'Please confirm the parameters before sending to production.',
          style: AppText.bodyLg.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 24),
        Stack(
          children: [
            DhCard(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Reference Image', mono: true),
                  const SizedBox(height: 10),
                  _ReferenceImage(file: image, name: fileName, extra: math.max(0, d.referenceImages.length - 1)),
                  const SizedBox(height: 24),
                  const SectionLabel('Material Specifications', mono: true),
                  const SizedBox(height: 10),
                  _MaterialRow(
                    colors: _swatches[d.quickBaseMetal] ?? _swatches['Y.GOLD']!,
                    title: '${d.quickPurity} $_metalName',
                    subtitle: 'High Polish Finish',
                  ),
                  const SizedBox(height: 6),
                  KeyValueRow('Job Type', d.jobType, mono: false, divider: true),
                  KeyValueRow(
                    'Gemstone Inset',
                    d.quickGemstone ? 'Yes' : 'No',
                    divider: true,
                    valueColor: d.quickGemstone ? c.success : c.textMuted,
                  ),
                  KeyValueRow('Target Budget', d.budget == null ? 'Not set' : Fmt.money(d.budget!), divider: true),
                  KeyValueRow(
                    'Delivery Target',
                    d.deliveryDate == null ? 'Standard · 4-6 wks' : Fmt.dateLong(d.deliveryDate!),
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Design Notes (Audio)', mono: true),
                  const SizedBox(height: 10),
                  if (d.hasVoiceNote)
                    _AudioPlayerRow(progress: _audio, total: d.voiceNoteLength, onToggle: _toggleAudio)
                  else
                    const _NoVoiceNote(),
                ],
              ),
            ),
            Positioned(top: 0, right: 0, child: _DraftTag(_draftId)),
          ],
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          _busy ? 'Processing…' : 'Confirm & Create Job',
          icon: _busy ? Icons.sync : Icons.precision_manufacturing_outlined,
          onPressed: _busy ? null : _confirm,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : _cancel,
          style: TextButton.styleFrom(minimumSize: const Size(double.infinity, 48), foregroundColor: c.textMuted),
          child: Text('Cancel', style: AppText.titleMd.copyWith(fontSize: 15)),
        ),
      ],
    );
  }
}

class _DraftTag extends StatelessWidget {
  const _DraftTag(this.id);

  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.surfaceHighest.withValues(alpha: c.isDark ? 0.6 : 0.8),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomLeft: Radius.circular(8)),
        border: Border(
          left: BorderSide(color: c.gold.withValues(alpha: 0.3)),
          bottom: BorderSide(color: c.gold.withValues(alpha: 0.3)),
        ),
      ),
      child: Text(id, style: AppText.monoCaps.copyWith(color: c.text)),
    );
  }
}

class _ReferenceImage extends StatelessWidget {
  const _ReferenceImage({required this.file, required this.name, required this.extra});

  final String? file;
  final String name;
  final int extra;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 196,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DhImage(file: file, asset: file == null ? Img.ringDiamondProngs : null, radius: 0),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.center,
                  colors: [c.surfaceHighest.withValues(alpha: 0.8), c.surfaceHighest.withValues(alpha: 0)],
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 10,
              right: 10,
              child: Row(
                children: [
                  Flexible(
                    child: _ImageChip(icon: Icons.center_focus_strong, label: name),
                  ),
                  const Spacer(),
                  if (extra > 0) _ImageChip(label: '+$extra MORE'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageChip extends StatelessWidget {
  const _ImageChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.borderStrong.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: c.gold), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.monoCaps.copyWith(color: c.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.colors, required this.title, required this.subtitle});

  final List<Color> colors;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceHigh.withValues(alpha: 0.6) : c.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
              boxShadow: [
                BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.monoLg.copyWith(fontSize: 15, color: c.text)),
                const SizedBox(height: 2),
                Text(subtitle.toUpperCase(), style: AppText.monoCaps.copyWith(color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioPlayerRow extends StatelessWidget {
  const _AudioPlayerRow({required this.progress, required this.total, required this.onToggle});

  final AnimationController progress;
  final Duration total;
  final VoidCallback onToggle;

  static const _bars = [0.4, 0.7, 1.0, 0.3, 0.8, 0.5, 0.2];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final c = context.c;
        final v = progress.value;
        final playing = progress.isAnimating;
        return Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 12),
          decoration: BoxDecoration(
            color: c.isDark ? c.bg : c.surfaceLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Material(
                    color: c.gold,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onToggle,
                      child: SizedBox.square(
                        dimension: 44,
                        child: Icon(playing ? Icons.pause : Icons.play_arrow, color: c.onAction),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Client_Instructions.wav',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.monoMd.copyWith(color: c.text),
                        ),
                        Text(
                          '${Fmt.duration(total * v)} / ${Fmt.duration(total)}',
                          style: AppText.monoSm.copyWith(color: c.success),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < _bars.length; i++)
                          Container(
                            width: 4,
                            margin: const EdgeInsets.only(left: 2),
                            height: 24 * _bars[i] * (playing ? 0.55 + 0.45 * math.sin(v * 90 + i * 1.3).abs() : 1),
                            decoration: BoxDecoration(
                              color: c.success.withValues(alpha: v > 0 && i / _bars.length <= v ? 1 : 0.35),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(1)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ThinProgress(value: v, color: c.success, height: 3),
            ],
          ),
        );
      },
    );
  }
}

class _NoVoiceNote extends StatelessWidget {
  const _NoVoiceNote();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.isDark ? c.bg : c.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_off_outlined, color: c.textFaint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('No voice note', style: AppText.bodyMd.copyWith(color: c.textFaint)),
          ),
        ],
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox.square(
      dimension: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [c.success.withValues(alpha: 0.28), c.success.withValues(alpha: 0)]),
              ),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: c.success,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c.success.withValues(alpha: 0.5), blurRadius: 24)],
            ),
            child: Icon(Icons.check, size: 36, color: c.isDark ? c.bg : c.surface),
          ),
        ],
      ),
    );
  }
}

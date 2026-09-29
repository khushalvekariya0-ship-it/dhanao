import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Final inspection protocol: 5 verification parameters, photo evidence and
/// the QC authorization / send-back decision.
class QualityControlScreen extends StatefulWidget {
  const QualityControlScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<QualityControlScreen> createState() => _QualityControlScreenState();
}

class _QcItem {
  const _QcItem(this.title, this.detail);

  final String title;
  final String detail;
}

class _QualityControlScreenState extends State<QualityControlScreen> {
  static const _recommendedPhotos = 3;
  static const _references = [Img.cadWireframeHalo, Img.ringPlatinumBench];

  final Set<int> _checked = {};
  final List<String> _evidence = [];
  bool _passed = false;
  bool _sentBack = false;

  static String _alloyShort(String metal) {
    final m = metal.toLowerCase();
    if (m.contains('platinum')) return 'Pt950';
    if (m.contains('silver')) return 'Ag925';
    if (m.contains('14k')) return 'Au585';
    if (m.contains('22k')) return 'Au916';
    return 'Au750';
  }

  static String _alloySpec(String metal) {
    final short = _alloyShort(metal);
    return short == 'Pt950' ? 'Pt950/Ru' : short;
  }

  List<_QcItem> _items(Job job) {
    final w = (job.weightGrams ?? 4.8).toStringAsFixed(1);
    return [
      const _QcItem(
        'Design matches approved CAD',
        'Verify structural integrity and proportions against revision v3.2.',
      ),
      _QcItem(
        'Correct dimensions',
        'Ring size ${job.ringSize ?? 'US 6.5'}. Shank width 2.2mm. Center setting height 6.8mm.',
      ),
      _QcItem('Metal weight verified', 'Target: ${w}g ${_alloyShort(job.metal)}. Allowable variance: ±0.2g.'),
      const _QcItem(
        'Stones secure',
        'Microscope check on 12 halo prongs and 4 main prongs. No movement under pressure.',
      ),
      const _QcItem(
        'Surface finish approved',
        'High polish exterior, matte finish interior. No porosity or casting defects visible at 10x.',
      ),
    ];
  }

  (String, Color) _status(DhColors c) {
    if (_passed) return ('QC Approved', c.success);
    if (_sentBack) return ('Sent Back', c.danger);
    final n = _checked.length;
    if (n == 5) return ('Ready for Authorization', c.accent);
    if (n > 0) return ('Inspection in Progress', c.warning);
    return ('Pending Review', c.textFaint);
  }

  // ---- Actions ------------------------------------------------------------

  void _toggle(int i) {
    if (_passed) {
      showSnack(context, 'Inspection is locked after authorization', icon: Icons.lock_outline);
      return;
    }
    setState(() {
      _sentBack = false;
      _checked.contains(i) ? _checked.remove(i) : _checked.add(i);
    });
  }

  Future<void> _addPhoto() async {
    if (_passed) {
      showSnack(context, 'Inspection is locked after authorization', icon: Icons.lock_outline);
      return;
    }
    final path = await pickImage(context, title: 'Inspection Evidence');
    if (path == null || !mounted) return;
    setState(() => _evidence.add(path));
    showSnack(context, 'Evidence photo added (${_evidence.length})', icon: Icons.photo_camera_outlined);
  }

  void _removePhoto(int i) {
    setState(() => _evidence.removeAt(i));
    showSnack(context, 'Photo removed', icon: Icons.delete_outline);
  }

  void _saveEvidence(Job job) {
    for (final p in _evidence) {
      app.addFile(
        job,
        ProjectFile(
          name: 'qc_${p.split(RegExp(r'[\\/]')).last}',
          kind: FileKind.image,
          localPath: p,
          jobId: job.id,
          uploadedBy: 'E. Carter',
        ),
      );
    }
    _evidence.clear();
  }

  Future<void> _authorize(Job job) async {
    final ok = await confirmDialog(
      context,
      title: 'Authorize QC Approval?',
      message: 'All 5 parameters verified for ${job.id}. The piece moves on to Certification.',
      confirm: 'Authorize',
    );
    if (!ok || !mounted) return;
    _saveEvidence(job);
    if (job.stage.isBefore(JobStage.certification)) {
      app.setStage(job, JobStage.certification, note: 'QC passed final inspection.');
    } else {
      app.addEvent(job, title: 'QC passed', text: 'QC passed final inspection.');
    }
    setState(() {
      _passed = true;
      _sentBack = false;
    });
    showSnack(context, 'QC approved · ${job.id} released to Certification', icon: Icons.verified_outlined);
  }

  Future<void> _sendBack(Job job) async {
    final reason = await showDialog<String>(context: context, builder: (_) => const _SendBackDialog());
    if (reason == null || !mounted) return;
    _saveEvidence(job);
    if (job.stage == JobStage.polishing) {
      app.addEvent(job, title: 'QC failed', text: reason);
    } else {
      app.setStage(job, JobStage.polishing, note: reason);
    }
    setState(() {
      _checked.clear();
      _passed = false;
      _sentBack = true;
    });
    showSnack(context, '${job.id} sent back to Polishing', icon: Icons.undo);
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final job = app.jobOrDefault(widget.jobId);
        final items = _items(job);
        final (statusLabel, statusColor) = _status(c);
        return DetailScaffold(
          title: 'Quality Control',
          subtitle: job.id,
          bottom: _passed
              ? PrimaryButton(
                  'Continue to Certification',
                  icon: Icons.workspace_premium_outlined,
                  onPressed: () => Navigator.pushNamed(context, Routes.certification, arguments: job.id),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      'Authorize QC Approval',
                      icon: Icons.gavel,
                      onPressed: _checked.length == items.length ? () => _authorize(job) : null,
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                      'Fail / Send Back',
                      icon: Icons.undo,
                      color: c.danger,
                      onPressed: () => _sendBack(job),
                    ),
                  ],
                ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, size: 20, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'STAGE 4: FINAL INSPECTION',
                      style: AppText.labelSm.copyWith(color: c.textMuted, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('QC Protocol: ${job.id}', style: AppText.headlineLg),
              const SizedBox(height: 4),
              Text('${job.title}. Specialist: E. Carter.', style: AppText.bodyMd.copyWith(color: c.textMuted)),
              const SizedBox(height: 14),
              _StatusBadge(label: statusLabel, color: statusColor, done: _passed),
              const SizedBox(height: 20),
              _checklist(items),
              const SizedBox(height: 16),
              _evidenceCard(),
              const SizedBox(height: 16),
              _referenceCard(job),
            ],
          ),
        );
      },
    );
  }

  Widget _checklist(List<_QcItem> items) {
    final c = context.c;
    final n = _checked.length;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Verification Parameters', style: AppText.headlineSm)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: c.surfaceHighest, borderRadius: BorderRadius.circular(12)),
                child: Text('$n/${items.length} Completed', style: AppText.monoSm.copyWith(color: c.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ThinProgress(value: n / items.length, color: _passed ? c.success : null),
          const SizedBox(height: 12),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            _CheckItem(item: items[i], checked: _checked.contains(i), locked: _passed, onTap: () => _toggle(i)),
          ],
        ],
      ),
    );
  }

  Widget _evidenceCard() {
    final c = context.c;
    final pending = math.max(0, _recommendedPhotos - _evidence.length);
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Inspection Evidence', style: AppText.headlineSm)),
              IconButton(
                tooltip: 'Take photo',
                icon: Icon(Icons.photo_camera_outlined, color: c.textMuted),
                onPressed: _addPhoto,
              ),
            ],
          ),
          const SizedBox(height: 8),
          UploadBox(
            title: 'Click to upload or drag and drop',
            subtitle: 'SVG, PNG, JPG or GIF (max. 10MB)',
            icon: Icons.cloud_upload_outlined,
            height: 132,
            onTap: _addPhoto,
          ),
          if (_evidence.isNotEmpty || pending > 0) ...[
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < _evidence.length; i++)
                  _EvidenceThumb(
                    path: _evidence[i],
                    onTap: () => _openViewer(context, _evidence, initial: i, files: true),
                    onRemove: _passed ? null : () => _removePhoto(i),
                  ),
                if (pending > 0)
                  Material(
                    color: c.surfaceHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: c.borderStrong),
                    ),
                    child: InkWell(
                      onTap: _addPhoto,
                      borderRadius: BorderRadius.circular(8),
                      child: Center(
                        child: Text(
                          '+$pending PENDING',
                          textAlign: TextAlign.center,
                          style: AppText.labelSm.copyWith(color: c.textMuted),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _referenceCard(Job job) {
    final c = context.c;
    return DhCard(
      color: c.isDark ? c.surface : c.surfaceLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, size: 20, color: c.accent),
              const SizedBox(width: 8),
              const Expanded(child: Text('Reference CAD Data', style: AppText.headlineSm)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RefImage(
                  asset: _references[0],
                  label: 'CAD v3.2',
                  onTap: () => _openViewer(context, _references),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RefImage(
                  asset: _references[1],
                  label: 'BENCH',
                  onTap: () => _openViewer(context, _references, initial: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const KeyValueRow('Tolerance', '±0.05mm', divider: true),
          KeyValueRow('Alloy', _alloySpec(job.metal)),
        ],
      ),
    );
  }
}

// ---- Pieces ----------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color, required this.done});

  final String label;
  final Color color;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: done ? color.withValues(alpha: 0.12) : c.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: done ? color.withValues(alpha: 0.4) : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label, style: AppText.titleMd.copyWith(color: done ? color : c.text)),
            ),
            if (done) ...[const SizedBox(width: 6), Icon(Icons.done_all, size: 18, color: color)],
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  const _CheckItem({required this.item, required this.checked, required this.locked, required this.onTap});

  final _QcItem item;
  final bool checked;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: checked ? (c.isDark ? c.surfaceHigh : c.surfaceLow) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: checked,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: locked ? null : (_) => onTap(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: AppText.titleMd),
                      const SizedBox(height: 2),
                      Text(item.detail, style: AppText.bodySm.copyWith(color: c.textMuted)),
                    ],
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

class _EvidenceThumb extends StatelessWidget {
  const _EvidenceThumb({required this.path, required this.onTap, this.onRemove});

  final String path;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DhImage(file: path, radius: 0),
          Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap),
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: Material(
                color: c.surface.withValues(alpha: 0.9),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: c.text),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RefImage extends StatelessWidget {
  const _RefImage({required this.asset, required this.label, required this.onTap});

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(label, style: AppText.monoSm.copyWith(color: c.textMuted, fontSize: 10)),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendBackDialog extends StatefulWidget {
  const _SendBackDialog();

  @override
  State<_SendBackDialog> createState() => _SendBackDialogState();
}

class _SendBackDialogState extends State<_SendBackDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      title: const Text('Fail / Send Back'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('The piece returns to Polishing. Describe what failed inspection.'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.bodyMd.copyWith(color: c.text),
            decoration: const InputDecoration(hintText: 'e.g. Micro-scratches on shank interior'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textMuted)),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _ctrl,
          builder: (context, v, _) => FilledButton(
            onPressed: v.text.trim().isEmpty ? null : () => Navigator.pop(context, v.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: c.isDark ? c.bg : c.surface),
            child: const Text('Send Back'),
          ),
        ),
      ],
    );
  }
}

Future<void> _openViewer(BuildContext context, List<String> images, {int initial = 0, bool files = false}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (_) => _ImageViewer(images: List.of(images), initial: initial, files: files),
  );
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initial, required this.files});

  final List<String> images;
  final int initial;
  final bool files;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Dialog.fullscreen(
      backgroundColor: c.bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  Text('${_index + 1} / ${widget.images.length}', style: AppText.monoMd.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: DhImage(
                      asset: widget.files ? null : widget.images[i],
                      file: widget.files ? widget.images[i] : null,
                      fit: BoxFit.contain,
                      radius: 0,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Pinch to zoom · swipe for more', style: AppText.bodySm.copyWith(color: c.textFaint)),
            ),
          ],
        ),
      ),
    );
  }
}

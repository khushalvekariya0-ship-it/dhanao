import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// CAD design review: compare versions, read designer notes, approve or
/// request revisions.
class CadReviewScreen extends StatefulWidget {
  const CadReviewScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<CadReviewScreen> createState() => _CadReviewScreenState();
}

class _HistoryEntry {
  const _HistoryEntry(this.when, this.text);

  final String when;
  final String text;
}

class _CadReviewScreenState extends State<CadReviewScreen> {
  static const _views = [Img.cadSolitaireScreen, Img.cadHaloCloseup, Img.cadHandView];
  static const _annotation = 'Halo stones were too small, reducing overall sparkle.';

  final _comment = TextEditingController();
  final _historyKey = GlobalKey();
  final List<String> _attachments = [];
  final List<_HistoryEntry> _history = [
    const _HistoryEntry('Oct 14, 09:15', 'v2.0 uploaded by Elena Rostova.'),
    const _HistoryEntry(
      'Oct 12, 16:45',
      'Revision requested: "Halo stones look a bit lost, can we scale them up slightly?"',
    ),
    const _HistoryEntry('Oct 12, 14:30', 'v1.2 uploaded.'),
  ];

  bool _overlay = false;
  bool _showNote = true;
  double _blend = 0.5;
  bool _approved = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  // ---- Actions ------------------------------------------------------------

  Future<void> _approve(Job job) async {
    final ok = await confirmDialog(
      context,
      title: 'Approve Design v2.0?',
      message: 'Version 2.0 will be locked and ${job.id} moves on to pricing, 3D printing and casting.',
      confirm: 'Approve',
    );
    if (!ok || !mounted) return;
    final note = _comment.text.trim();
    if (job.stage.index <= JobStage.approval.index) {
      app.setStage(job, JobStage.pricing, note: 'Design v2.0 approved and locked.');
    } else {
      app.addEvent(job, title: 'Design v2.0 approved', text: 'Design v2.0 approved and locked.');
    }
    if (note.isNotEmpty) app.postMessage(job, note);
    setState(() {
      _approved = true;
      _comment.clear();
      _history.insert(0, _HistoryEntry(Fmt.dateTime(DateTime.now()), 'v2.0 approved and locked by ${app.userName}.'));
    });
    showSnack(context, 'Design v2.0 approved and locked', icon: Icons.check_circle_outline);
  }

  Future<void> _requestRevisions(Job job) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NoteSheet(
        title: 'Request Revisions',
        subtitle: 'Elena Rostova will be notified with your comments.',
        hint: 'Describe the changes needed...',
        action: 'Send Request',
        initial: _comment.text.trim(),
      ),
    );
    if (note == null || !mounted) return;
    app.addEvent(job, title: 'Revision requested', text: note);
    setState(() {
      _comment.clear();
      _history.insert(0, _HistoryEntry(Fmt.dateTime(DateTime.now()), 'Revision requested: "$note"'));
    });
    showSnack(context, 'Revision request sent to Elena Rostova', icon: Icons.send_outlined);
  }

  Future<void> _attach(Job job) async {
    final path = await pickImage(context, title: 'Attach Reference');
    if (path == null || !mounted) return;
    final name = path.split(RegExp(r'[\\/]')).last;
    app.addFile(job, ProjectFile(name: name, kind: FileKind.image, localPath: path, jobId: job.id));
    setState(() => _attachments.add(name));
    showSnack(context, 'Attached $name to ${job.id}', icon: Icons.attach_file);
  }

  void _linkAnnotation() {
    const tag = '[Pin 1]';
    if (!_comment.text.contains(tag)) {
      final text = '$tag ${_comment.text}';
      _comment.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    showSnack(context, 'Comment linked to annotation #1', icon: Icons.edit_location_alt_outlined);
  }

  void _showMeasurements(Job job) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Measurements · v2.0'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyValueRow('Ring Size', job.ringSize ?? 'US 6.5', divider: true),
            KeyValueRow('Center Stone', _centerStone(job), divider: true),
            const KeyValueRow('Halo melee', '1.5 mm (was 1.2 mm)', divider: true),
            const KeyValueRow('Halo weight', '0.45ct tw', divider: true),
            const KeyValueRow('Gallery wire', 'Lowered for flush band'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _viewTimeline() {
    final ctx = _historyKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  static String _centerStone(Job job) => job.centerStone == '—' ? '1.5ct Oval Cut' : job.centerStone;

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final job = app.jobOrDefault(widget.jobId);
        return DetailScaffold(
          title: 'CAD Review',
          subtitle: job.id,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(job: job),
                const SizedBox(height: 16),
                _MiniStepper(step: _approved ? 2 : 1),
                const SizedBox(height: 20),
                _comparisonCard(job),
                const SizedBox(height: 12),
                _viewsGrid(job),
                const SizedBox(height: 20),
                const _DesignerNote(),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _approved ? _successCard(job) : _decisionCard(job),
                ),
                const SizedBox(height: 28),
                KeyedSubtree(key: _historyKey, child: _historySection()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _comparisonCard(Job job) {
    final c = context.c;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.threesixty, color: c.accent, size: 22),
              const SizedBox(width: 8),
              const Expanded(child: Text('Visual Comparison', style: AppText.headlineSm)),
            ],
          ),
          const SizedBox(height: 12),
          DhSegmented<bool>(
            options: const [false, true],
            selected: _overlay,
            labelOf: (o) => o ? 'Overlay' : 'Split View',
            onChanged: (v) => setState(() => _overlay = v),
          ),
          const SizedBox(height: 16),
          if (_overlay) _overlayView() else ..._splitView(job),
          const SizedBox(height: 16),
          _SpecsPanel(job: job, centerStone: _centerStone(job)),
        ],
      ),
    );
  }

  List<Widget> _splitView(Job job) {
    final c = context.c;
    return [
      _VersionPane(
        label: 'v1.2 (Previous)',
        time: 'Oct 12, 14:30',
        image: Img.ringHaloV1,
        onTap: () => _openViewer(context, const [Img.ringHaloV1]),
        overlay: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final h = box.maxHeight;
            const bubbleW = 190.0;
            return Stack(
              children: [
                Positioned(
                  left: w * 0.6 - 13,
                  top: h * 0.4 - 13,
                  child: GestureDetector(
                    onTap: () => setState(() => _showNote = !_showNote),
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.surface, width: 2),
                        boxShadow: [BoxShadow(color: c.danger.withValues(alpha: 0.4), blurRadius: 8)],
                      ),
                      child: Text('1', style: AppText.labelSm.copyWith(color: c.isDark ? c.bg : c.surface)),
                    ),
                  ),
                ),
                if (_showNote)
                  Positioned(
                    left: (w * 0.6 - bubbleW / 2).clamp(8.0, math.max(8.0, w - bubbleW - 8)),
                    top: h * 0.4 + 20,
                    width: bubbleW,
                    child: GestureDetector(
                      onTap: () => setState(() => _showNote = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.border),
                          boxShadow: [BoxShadow(color: c.text.withValues(alpha: 0.12), blurRadius: 12)],
                        ),
                        child: Text(_annotation, style: AppText.bodySm.copyWith(color: c.text)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      const SizedBox(height: 16),
      _VersionPane(
        label: 'v2.0 (Current)',
        time: 'Oct 14, 09:15',
        image: Img.ringHaloV2,
        current: true,
        onTap: () => _openViewer(context, const [Img.ringHaloV2]),
        overlay: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ToolButton(
                    icon: Icons.zoom_in,
                    tooltip: 'Zoom',
                    onTap: () => _openViewer(context, const [Img.ringHaloV2]),
                  ),
                  _ToolButton(
                    icon: Icons.threesixty,
                    tooltip: 'All views',
                    onTap: () => _openViewer(context, const [Img.ringHaloV2, ..._views]),
                  ),
                  _ToolButton(icon: Icons.straighten, tooltip: 'Measurements', onTap: () => _showMeasurements(job)),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _overlayView() {
    final c = context.c;
    Widget tag(String t, bool strong) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? c.accent : c.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(t, style: AppText.monoSm.copyWith(color: strong ? c.onAccent : c.textMuted)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: GestureDetector(
            onTap: () => _openViewer(context, const [Img.ringHaloV1, Img.ringHaloV2]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(Img.ringHaloV1, fit: BoxFit.cover),
                  Opacity(
                    opacity: _blend,
                    child: Image.asset(Img.ringHaloV2, fit: BoxFit.cover),
                  ),
                  Positioned(left: 10, top: 10, child: tag('v1.2', _blend < 0.5)),
                  Positioned(right: 10, top: 10, child: tag('v2.0', _blend >= 0.5)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('v1.2', style: AppText.monoSm.copyWith(color: c.textMuted)),
            Expanded(
              child: Slider(
                value: _blend,
                activeColor: c.accent,
                inactiveColor: c.surfaceHighest,
                onChanged: (v) => setState(() => _blend = v),
              ),
            ),
            Text('v2.0', style: AppText.monoSm.copyWith(color: c.accent)),
          ],
        ),
        Text(
          'BLEND ${(_blend * 100).round()}% v2.0',
          textAlign: TextAlign.center,
          style: AppText.monoCaps.copyWith(color: c.textFaint),
        ),
      ],
    );
  }

  Widget _viewsGrid(Job job) {
    final c = context.c;
    Widget thumb(int i, {bool more = false}) => AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(_views[i], fit: BoxFit.cover),
            if (more)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: c.text.withValues(alpha: 0.15), blurRadius: 8)],
                  ),
                  child: Text('+3 Views', style: AppText.labelMd.copyWith(color: c.text)),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: () => _openViewer(context, _views, initial: i)),
            ),
          ],
        ),
      ),
    );

    final download = AspectRatio(
      aspectRatio: 4 / 3,
      child: Material(
        color: c.isDark ? c.surface : c.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => showSnack(context, 'Preparing ${job.id}_v2.0.stl and .step for download', icon: Icons.download),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download, size: 28, color: c.textMuted),
              const SizedBox(height: 6),
              Text(
                'Download\nSTL / STEP',
                textAlign: TextAlign.center,
                style: AppText.labelMd.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: thumb(0)),
            const SizedBox(width: 12),
            Expanded(child: thumb(1)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: thumb(2, more: true)),
            const SizedBox(width: 12),
            Expanded(child: download),
          ],
        ),
      ],
    );
  }

  Widget _decisionCard(Job job) {
    final c = context.c;
    return DhCard(
      key: const ValueKey('decision'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Your Decision', style: AppText.headlineSm),
          const SizedBox(height: 4),
          Text(
            'Approving will lock the design and move it to 3D printing and casting.',
            style: AppText.bodySm.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: c.isDark ? c.surfaceLow : c.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _comment,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.bodyMd.copyWith(color: c.text),
                  decoration: const InputDecoration(
                    hintText: 'Add comments for revisions or notes for production...',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(14, 14, 14, 0),
                  ),
                ),
                Row(
                  children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _attachments.isEmpty
                            ? ''
                            : '${_attachments.length} file${_attachments.length == 1 ? '' : 's'} attached',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.monoSm.copyWith(color: c.textFaint),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Attach file',
                      icon: Icon(Icons.attach_file, size: 20, color: c.textMuted),
                      onPressed: () => _attach(job),
                    ),
                    IconButton(
                      tooltip: 'Link to annotation',
                      icon: Icon(Icons.edit_location_alt_outlined, size: 20, color: c.textMuted),
                      onPressed: _linkAnnotation,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            'APPROVE DESIGN v2.0',
            icon: Icons.thumb_up_outlined,
            color: c.accent,
            foreground: c.onAccent,
            onPressed: () => _approve(job),
          ),
          const SizedBox(height: 10),
          SecondaryButton('Request Revisions', icon: Icons.edit_note, onPressed: () => _requestRevisions(job)),
        ],
      ),
    );
  }

  Widget _successCard(Job job) {
    final c = context.c;
    return DhCard(
      key: const ValueKey('success'),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: c.action,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: c.action.withValues(alpha: 0.3), blurRadius: 18, spreadRadius: 2)],
            ),
            child: Icon(Icons.check_circle, size: 40, color: c.onAction),
          ),
          const SizedBox(height: 16),
          const Text('Design Approved', style: AppText.headlineSm),
          const SizedBox(height: 6),
          Text(
            'Version 2.0 has been locked. The job is now moving to the ${job.stage.label} stage.',
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _viewTimeline,
            style: FilledButton.styleFrom(
              backgroundColor: c.surfaceHigh,
              foregroundColor: c.text,
              minimumSize: const Size(0, 40),
              shape: const StadiumBorder(),
              textStyle: AppText.labelMd.copyWith(fontSize: 13),
            ),
            child: const Text('View Timeline'),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('HISTORY', style: AppText.labelMd.copyWith(color: c.textMuted, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _history.length; i++)
          _HistoryTile(
            entry: _history[i],
            latest: i == 0,
            isLast: i == _history.length - 1,
            boxed: i == 0 || i < _history.length - 1,
          ),
      ],
    );
  }
}

// ---- Sections --------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusChip('Review Stage', color: c.accent, filled: true),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                job.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoMd.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('CAD Design Review', style: AppText.headlineLg),
        const SizedBox(height: 6),
        Text(
          'Review the latest 3D models from the design team. Compare versions and provide feedback to proceed '
          'to manufacturing.',
          style: AppText.bodyMd.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 8),
        Text('${job.title} · ${job.customer}', style: AppText.bodySm.copyWith(color: c.textFaint)),
      ],
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({required this.step});

  /// 0 = Briefing, 1 = CAD Review, 2 = Production.
  final int step;

  static const _labels = ['Briefing', 'CAD Review', 'Production'];
  static const _icons = [Icons.check, Icons.visibility_outlined, Icons.precision_manufacturing_outlined];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: c.isDark ? c.surface : c.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(top: 15),
                  color: i <= step ? c.action : c.borderStrong,
                ),
              ),
            _node(c, i),
          ],
        ],
      ),
    );
  }

  Widget _node(DhColors c, int i) {
    final done = i < step;
    final current = i == step;
    final Color bg = done ? c.action : (current ? c.accent : c.surfaceHigh);
    final Color fg = done ? c.onAction : (current ? c.onAccent : c.textFaint);
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: current ? [BoxShadow(color: c.accent.withValues(alpha: 0.25), spreadRadius: 4)] : null,
            ),
            child: Icon(done ? Icons.check : _icons[i], size: 16, color: fg),
          ),
          const SizedBox(height: 8),
          Text(
            _labels[i],
            textAlign: TextAlign.center,
            style: AppText.labelMd.copyWith(color: done || current ? c.text : c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _VersionPane extends StatelessWidget {
  const _VersionPane({
    required this.label,
    required this.time,
    required this.image,
    required this.onTap,
    this.current = false,
    this.overlay,
  });

  final String label;
  final String time;
  final String image;
  final VoidCallback onTap;
  final bool current;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text(label, style: AppText.labelMd.copyWith(color: current ? c.text : c.textMuted)),
              if (current) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                ),
              ],
              const Spacer(),
              Text(time, style: AppText.monoMd.copyWith(color: current ? c.accent : c.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: current ? c.accent.withValues(alpha: 0.45) : c.border, width: current ? 2 : 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: onTap,
                    child: Image.asset(image, fit: BoxFit.cover),
                  ),
                  ?overlay,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 20, color: context.c.textMuted),
      onPressed: onTap,
    );
  }
}

class _SpecsPanel extends StatelessWidget {
  const _SpecsPanel({required this.job, required this.centerStone});

  final Job job;
  final String centerStone;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = AppText.bodyMd.copyWith(color: c.text);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: LabelValue('Metal', job.metal, valueStyle: style)),
              const SizedBox(width: 12),
              Expanded(child: LabelValue('Center Stone', centerStone, valueStyle: style)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: LabelValue('Halo', '0.45ct tw (Increased from 0.3ct)', valueStyle: style)),
              const SizedBox(width: 12),
              Expanded(child: LabelValue('Ring Size', job.ringSize ?? 'US 6.5', valueStyle: style)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesignerNote extends StatelessWidget {
  const _DesignerNote();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = c.isDark ? c.surfaceHigh : c.navActive;
    // Muted "on-primary-container" text on the navy card.
    final fg = c.isDark ? c.text : c.onNavActive.withValues(alpha: 0.62);
    final body = AppText.bodyMd.copyWith(color: c.isDark ? c.textMuted : fg);
    final partner = app.partnerByName('Elena Rostova');
    Widget bullet(String t) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: body),
          Expanded(child: Text(t, style: body)),
        ],
      ),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: c.isDark ? Border.all(color: c.border) : null,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -22,
            left: -10,
            child: Transform.rotate(
              angle: 0.2,
              child: Icon(Icons.format_quote, size: 120, color: fg.withValues(alpha: 0.06)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DhAvatar(asset: partner?.avatar, name: 'Elena Rostova', size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Elena Rostova', style: AppText.labelMd.copyWith(color: fg, fontSize: 14)),
                          Text(
                            partner?.role ?? 'Lead CAD Designer',
                            style: AppText.labelSm.copyWith(color: fg.withValues(alpha: c.isDark ? 0.7 : 0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text("I've updated the model based on your feedback from Tuesday.", style: body),
                const SizedBox(height: 4),
                bullet('Increased the halo melee stones from 1.2mm to 1.5mm for better presence.'),
                bullet('Adjusted the gallery wire slightly lower to ensure the wedding band will sit flush.'),
                const SizedBox(height: 12),
                Text(
                  'Please review the proportions carefully before we cast.',
                  style: AppText.labelMd.copyWith(color: c.isDark ? c.text : fg, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// History entry: small dot on a hairline, sans date and a speech-box body.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.latest, required this.isLast, required this.boxed});

  final _HistoryEntry entry;
  final bool latest;
  final bool isLast;

  /// Older entries drop the box and fade out.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rail = c.borderStrong.withValues(alpha: c.isDark ? 0.6 : 0.3);
    final tile = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Stack(
              children: [
                Positioned(
                  left: 8,
                  top: latest ? 6 : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 8 : null,
                  child: Container(width: 1, color: rail),
                ),
                Positioned(
                  left: 1,
                  top: 1,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: latest ? c.accent : c.borderStrong, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.when, style: AppText.labelSm.copyWith(color: c.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  if (boxed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: latest ? c.surfaceHigh : (c.isDark ? c.surface : c.surfaceLow),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(entry.text, style: AppText.bodySm.copyWith(color: c.text)),
                    )
                  else
                    Text(entry.text, style: AppText.bodySm.copyWith(color: c.text)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return boxed ? tile : Opacity(opacity: 0.6, child: tile);
  }
}

// ---- Sheets & viewer -------------------------------------------------------

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.title, required this.hint, required this.action, this.subtitle, this.initial = ''});

  final String title;
  final String? subtitle;
  final String hint;
  final String action;
  final String initial;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppText.headlineSm),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(widget.subtitle!, style: AppText.bodySm.copyWith(color: c.textMuted)),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.bodyMd.copyWith(color: c.text),
                decoration: InputDecoration(hintText: widget.hint),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _ctrl,
                builder: (context, v, _) => PrimaryButton(
                  widget.action,
                  icon: Icons.send_outlined,
                  onPressed: v.text.trim().isEmpty ? null : () => Navigator.pop(context, v.text.trim()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openViewer(BuildContext context, List<String> images, {int initial = 0}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (_) => _ImageViewer(images: images, initial: initial),
  );
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.images, required this.initial});

  final List<String> images;
  final int initial;

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
                  child: Center(child: Image.asset(widget.images[i], fit: BoxFit.contain)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                widget.images.length > 1 ? 'Pinch to zoom · swipe for more views' : 'Pinch to zoom',
                style: AppText.bodySm.copyWith(color: c.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

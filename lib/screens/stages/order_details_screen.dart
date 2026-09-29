import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Order summary for the bench: live deadline countdown, blueprint asset,
/// technical specs and the workshop notes log.
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _note = TextEditingController();
  final _notesScroll = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollNotesToEnd(animate: false));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _note.dispose();
    _notesScroll.dispose();
    super.dispose();
  }

  void _scrollNotesToEnd({bool animate = true}) {
    if (!_notesScroll.hasClients) return;
    final end = _notesScroll.position.maxScrollExtent;
    if (animate) {
      _notesScroll.animateTo(end, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      _notesScroll.jumpTo(end);
    }
  }

  void _send(Job job) {
    final text = _note.text.trim();
    if (text.isEmpty) {
      showSnack(context, 'Type a note first', icon: Icons.edit_outlined);
      return;
    }
    app.postMessage(job, text);
    _note.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollNotesToEnd());
    showSnack(context, 'Note added to ${job.id}', icon: Icons.forum_outlined);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final job = app.jobOrDefault(widget.jobId);
        return DetailScaffold(
          title: 'Order Details',
          subtitle: job.id,
          bottom: Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  'Workflow',
                  icon: Icons.account_tree_outlined,
                  onPressed: () => Navigator.pushNamed(context, Routes.tracker, arguments: job.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  'Open Job',
                  icon: Icons.open_in_new,
                  onPressed: () => Navigator.pushNamed(context, Routes.job, arguments: job.id),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Order #${job.id}', style: AppText.headlineMd)),
                  const SizedBox(width: 10),
                  _PriorityPill(priority: job.priority),
                ],
              ),
              const SizedBox(height: 4),
              Text('Client: ${job.customer}', style: AppText.bodyMd.copyWith(color: c.textMuted)),
              const SizedBox(height: 20),
              _Countdown(due: job.dueDate),
              const SizedBox(height: 16),
              _AssetCard(job: job),
              const SizedBox(height: 16),
              _TechSpecs(job: job),
              const SizedBox(height: 16),
              _notesCard(job),
            ],
          ),
        );
      },
    );
  }

  Widget _notesCard(Job job) {
    final c = context.c;
    final notes = job.thread;
    return DhCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
              color: c.isDark ? c.surfaceHigh : c.surfaceLow,
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, size: 16, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('WORKSHOP NOTES', style: AppText.monoCaps.copyWith(color: c.textMuted)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    '${notes.length} Update${notes.length == 1 ? '' : 's'}',
                    style: AppText.monoSm.copyWith(color: c.isDark ? c.gold : c.accent, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: notes.isEmpty
                ? const EmptyState(icon: Icons.forum_outlined, message: 'No workshop notes yet.')
                : ListView.separated(
                    controller: _notesScroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => _NoteEntry(message: notes[i]),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(job),
                    style: AppText.monoMd.copyWith(color: c.text),
                    decoration: const InputDecoration(hintText: 'Add a note...'),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: c.action,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _send(job),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Tooltip(
                        message: 'Send note',
                        child: Icon(Icons.send, size: 18, color: c.onAction),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Sections --------------------------------------------------------------

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (label, color) = switch (priority) {
      Priority.critical => ('Critical', c.danger),
      Priority.rush => ('Rush', c.warning),
      Priority.high => ('High', c.gold),
      Priority.standard => ('Standard', c.textFaint),
    };
    return StatusChip('Priority: $label', color: color, dot: true);
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.due});

  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final left = due.difference(DateTime.now());
    final overdue = left.isNegative;
    final accent = overdue ? c.danger : (c.isDark ? c.gold : c.accent);
    final big = AppText.monoLg.copyWith(fontSize: 30, height: 1.1, fontWeight: FontWeight.w700);
    String two(int v) => v.toString().padLeft(2, '0');
    Widget unit(String value, String label, {bool highlight = false}) => Column(
      children: [
        Text(value, style: big.copyWith(color: highlight ? accent : c.text)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: AppText.monoCaps.copyWith(color: highlight ? accent : c.textFaint)),
      ],
    );
    Widget colon() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(':', style: big.copyWith(color: c.textFaint, fontSize: 24)),
    );

    final Widget counter;
    if (overdue) {
      final over = -left;
      counter = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('OVERDUE', style: big.copyWith(color: c.danger)),
          const SizedBox(height: 4),
          Text(
            'by ${over.inDays}d ${over.inHours.remainder(24)}h ${over.inMinutes.remainder(60)}m',
            style: AppText.monoMd.copyWith(color: c.danger),
          ),
        ],
      );
    } else {
      counter = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          unit(two(left.inDays), 'Days'),
          colon(),
          unit(two(left.inHours.remainder(24)), 'Hrs'),
          colon(),
          unit(two(left.inMinutes.remainder(60)), 'Mins', highlight: true),
        ],
      );
    }

    return DhCard(
      padding: EdgeInsets.zero,
      color: c.isDark ? c.surfaceHigh : c.surface,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _DotsPainter(accent.withValues(alpha: 0.12)))),
          Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: accent)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: c.textMuted),
                    const SizedBox(width: 8),
                    Text('PRODUCTION DEADLINE', style: AppText.monoCaps.copyWith(color: c.textMuted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                counter,
                const SizedBox(height: 12),
                Text('Due ${Fmt.dateLong(due)} · ${Fmt.time(due)}', style: AppText.monoSm.copyWith(color: c.textFaint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => _openViewer(context, Img.cadBlueprint),
                  child: Image.asset(Img.cadBlueprint, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surfaceHigh.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: c.border),
                    ),
                    child: Text('ID: ASSET-99A', style: AppText.monoSm.copyWith(color: c.textMuted, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: c.isDark ? c.surfaceHighest.withValues(alpha: 0.5) : c.surfaceLow,
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
                ),
                const SizedBox(width: 8),
                Material(
                  color: c.surfaceHigh,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _openViewer(context, Img.cadBlueprint),
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Tooltip(
                        message: 'Zoom blueprint',
                        child: Icon(Icons.zoom_in, color: c.accent),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechSpecs extends StatelessWidget {
  const _TechSpecs({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = job.weightGrams;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.precision_manufacturing_outlined, size: 16, color: c.textMuted),
              const SizedBox(width: 8),
              Text('TECHNICAL SPECS', style: AppText.monoCaps.copyWith(color: c.textMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          _SpecRow('Alloy', job.metal),
          _SpecRow('Center Stone', job.centerStone),
          _SpecRow('Setting Type', job.settingStyle),
          _SpecRow('Target Weight', w == null ? '—' : '${w.toStringAsFixed(1)}g ±0.1g', highlight: true, last: true),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value, {this.highlight = false, this.last = false});

  final String label;
  final String value;
  final bool highlight;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = highlight ? (c.isDark ? c.gold : c.accent) : c.text;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppText.bodyMd.copyWith(color: c.textMuted)),
          ),
          const SizedBox(width: 10),
          Flexible(
            flex: 3,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: highlight ? fg.withValues(alpha: 0.1) : c.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                  border: highlight ? Border.all(color: fg.withValues(alpha: 0.3)) : null,
                ),
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppText.monoMd.copyWith(color: fg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteEntry extends StatelessWidget {
  const _NoteEntry({required this.message});

  final ThreadMessage message;

  static String _when(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return Fmt.time(d);
    if (diff == -1) return 'Yesterday';
    return Fmt.date(d);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = message;
    final system = m.author == 'System' || m.kind != MessageKind.message;
    final accent = c.isDark ? c.gold : c.accent;
    final Widget avatar = m.avatar != null
        ? DhAvatar(asset: m.avatar, size: 32)
        : Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: m.isMe ? accent.withValues(alpha: 0.2) : c.surfaceHighest,
              shape: BoxShape.circle,
              border: Border.all(color: m.isMe ? accent.withValues(alpha: 0.3) : c.border),
            ),
            child: Icon(
              m.isMe
                  ? Icons.person
                  : system
                  ? Icons.sync_alt
                  : Icons.engineering,
              size: 16,
              color: m.isMe ? accent : c.info,
            ),
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      m.isMe ? '${m.author} (You)' : m.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.monoCaps.copyWith(fontSize: 10, color: m.isMe ? accent : c.text),
                    ),
                  ),
                  Text(_when(m.time), style: AppText.monoSm.copyWith(fontSize: 10, color: c.textFaint)),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: m.isMe ? accent.withValues(alpha: 0.08) : c.surfaceHigh,
                  border: m.isMe ? Border.all(color: accent.withValues(alpha: 0.25)) : null,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.title != null) ...[
                      Text(m.title!, style: AppText.labelMd.copyWith(color: c.text)),
                      const SizedBox(height: 2),
                    ],
                    Text(m.text, style: AppText.bodyMd.copyWith(color: system ? c.textMuted : c.text)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    for (double y = 2; y < size.height; y += 20) {
      for (double x = 2; x < size.width; x += 20) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

Future<void> _openViewer(BuildContext context, String image) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (ctx) {
      final c = ctx.c;
      return Dialog.fullscreen(
        backgroundColor: c.bg,
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text('ID: ASSET-99A', style: AppText.monoMd.copyWith(color: c.textMuted)),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 6,
                  child: Center(child: Image.asset(image, fit: BoxFit.contain)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Pinch to zoom · drag to pan', style: AppText.bodySm.copyWith(color: c.textFaint)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

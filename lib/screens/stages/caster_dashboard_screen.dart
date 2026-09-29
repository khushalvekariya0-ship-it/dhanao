import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Vendor (casting house) view: priority job, incoming wax, completions and
/// the casting hand-off with photo proof.
class CasterDashboardScreen extends StatefulWidget {
  const CasterDashboardScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<CasterDashboardScreen> createState() => _CasterDashboardScreenState();
}

class _CasterDashboardScreenState extends State<CasterDashboardScreen> {
  static const _vendor = 'Patel Works';
  static const _references = [Img.cadWireframeGreen, Img.waxModelSignet];

  final _detailsKey = GlobalKey();
  final _priorityKey = GlobalKey();
  bool _allActive = false;
  String? _selectedId;
  String? _photo;

  Job get _selected => app.jobOrDefault(_selectedId ?? widget.jobId);

  List<Job> get _scopeJobs => _allActive
      ? app.jobs.where((j) => j.stage == JobStage.wax || j.stage == JobStage.casting).toList()
      : app.jobs
            .where((j) => j.stage == JobStage.casting && (j.assignee == null || j.assignee!.contains('Patel')))
            .toList();

  List<Job> get _completedToday {
    final now = DateTime.now();
    bool today(DateTime d) => d.year == now.year && d.month == now.month && d.day == now.day;
    final out = <Job>[];
    final sample = app.jobById('DH-1056');
    if (sample != null) out.add(sample);
    for (final j in app.jobs) {
      if (j == sample) continue;
      if (j.history.any((e) => e.by == _vendor && e.stage == JobStage.assembly && today(e.at))) out.add(j);
    }
    return out;
  }

  // ---- Actions ------------------------------------------------------------

  void _select(Job job) {
    if (job.id == _selected.id) return;
    setState(() {
      _selectedId = job.id;
      _photo = null;
    });
    _scrollTo(_priorityKey);
    showSnack(context, '${job.id} selected', icon: Icons.touch_app_outlined);
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  void _scrollToDetails() => _scrollTo(_detailsKey);

  Future<void> _pickPhoto() async {
    final path = await pickImage(context, title: 'Casting Photo');
    if (path == null || !mounted) return;
    setState(() => _photo = path);
    showSnack(context, 'Casting photo attached', icon: Icons.photo_camera_outlined);
  }

  void _complete(Job job) {
    final photo = _photo;
    if (photo == null) return;
    final temps = _castingTemps(job.metal);
    final photoName = 'casting_${job.id}.jpg';
    app.recordStage(job, JobStage.casting, {
      'Caster': 'Patel Casting Works',
      'Alloy': job.metal,
      'Flask Temp': temps.$1,
      'Metal Temp': temps.$2,
      'Casting Photo': photoName,
      'Completed At': Fmt.dateTime(DateTime.now()),
    });
    app.addFile(
      job,
      ProjectFile(name: photoName, kind: FileKind.image, localPath: photo, jobId: job.id, uploadedBy: _vendor),
    );
    final next = app.advance(job, by: _vendor, note: 'Casting complete. Photo uploaded by Patel Casting Works.');
    setState(() => _photo = null);
    showSnack(
      context,
      '${job.id} casting complete${next == null ? '' : ' → ${next.label}'}',
      icon: Icons.check_circle_outline,
    );
  }

  void _receiveWax(Job job) {
    app.recordStage(job, JobStage.wax, {
      'Wax Received By': 'Patel Casting Works',
      'Received At': Fmt.dateTime(DateTime.now()),
    });
    app.advance(job, by: _vendor, note: 'Wax model received at Patel Casting Works.');
    showSnack(context, 'Wax received · ${job.id} ready for casting', icon: Icons.inventory_2_outlined);
  }

  Future<void> _reportIssue(Job job) async {
    final report = await showDhSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReportIssueSheet(jobId: job.id),
    );
    if (report == null || !mounted) return;
    final (type, note) = report;
    app.recordStage(job, job.stage, {'Issue Reported': type, 'Issue Note': note});
    app.addEvent(
      job,
      title: 'Issue reported: $type',
      text: note.isEmpty ? '$type reported by Patel Casting Works.' : note,
    );
    if (!job.atRisk) app.toggleRisk(job);
    showSnack(context, 'Issue reported · ${job.id} flagged at risk', icon: Icons.report_outlined);
  }

  void _openReferences(Job job, {int initial = 0}) {
    _openViewer(context, [job.image ?? Img.waxModelBlue, ..._references], initial: initial);
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final job = _selected;
        final queue = _scopeJobs.where((j) => j.id != job.id).toList();
        final incoming = app.jobsInStage(JobStage.wax).where((j) => j.id != job.id).toList();
        final completed = _completedToday;
        return DetailScaffold(
          title: 'Caster Dashboard',
          subtitle: job.id,
          bottom: _bottomBar(job),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _VendorHeader(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _FilterPill(
                      label: 'Assigned to Me',
                      icon: Icons.filter_list,
                      selected: !_allActive,
                      onTap: () => setState(() => _allActive = false),
                    ),
                    _FilterPill(
                      label: 'All Active',
                      selected: _allActive,
                      onTap: () => setState(() => _allActive = true),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _BarTitle('Active Priority', key: _priorityKey, color: c.accent, large: true),
                const SizedBox(height: 16),
                _PriorityCard(job: job, onInstructions: _scrollToDetails, onImages: () => _openReferences(job)),
                if (queue.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _BarTitle('Queue', color: c.borderStrong, trailing: _CountChip('${queue.length}')),
                  const SizedBox(height: 10),
                  for (final q in queue) ...[_QueueTile(job: q, onTap: () => _select(q)), const SizedBox(height: 8)],
                ] else if (_allActive) ...[
                  const SizedBox(height: 12),
                  Text('No other active wax or casting jobs.', style: AppText.bodySm.copyWith(color: c.textFaint)),
                ],
                const SizedBox(height: 24),
                _BarTitle('Incoming', color: c.gold),
                const SizedBox(height: 16),
                if (incoming.isEmpty)
                  Text('No wax models en route.', style: AppText.bodySm.copyWith(color: c.textFaint))
                else
                  for (final j in incoming) ...[
                    _IncomingCard(job: j, onTap: () => _select(j)),
                    const SizedBox(height: 10),
                  ],
                const SizedBox(height: 24),
                _BarTitle(
                  'Completed Today',
                  color: c.textFaint,
                  trailing: _CountChip('${completed.length} Job${completed.length == 1 ? '' : 's'}'),
                ),
                const SizedBox(height: 16),
                for (final j in completed) ...[
                  _CompletedCard(job: j, onTap: () => _select(j)),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 24),
                KeyedSubtree(key: _detailsKey, child: _details(job)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomBar(Job job) {
    final c = context.c;
    final Widget primary;
    if (job.stage == JobStage.casting) {
      primary = _FooterButton(
        label: 'Mark Complete',
        icon: Icons.check,
        primary: true,
        onPressed: _photo == null ? null : () => _complete(job),
      );
    } else if (job.stage == JobStage.wax) {
      primary = _FooterButton(
        label: 'Wax Received',
        icon: Icons.inventory_2_outlined,
        primary: true,
        onPressed: () => _receiveWax(job),
      );
    } else {
      primary = _FooterButton(
        label: 'Open Job',
        icon: Icons.arrow_forward,
        primary: true,
        onPressed: () => Navigator.pushNamed(context, Routes.job, arguments: job.id),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _FooterButton(label: 'Report Issue', color: c.danger, onPressed: () => _reportIssue(job)),
        ),
        const SizedBox(width: 12),
        Expanded(child: primary),
      ],
    );
  }

  Widget _details(Job job) {
    final c = context.c;
    final temps = _castingTemps(job.metal);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: _softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('JOB DETAILS', style: AppText.labelMd.copyWith(color: c.textMuted, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(
            job.id,
            style: AppText.monoLg.copyWith(fontSize: 22, height: 30 / 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Divider(color: c.border, height: 1),
          const SizedBox(height: 20),
          _DetailLabel('Reference'),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < _references.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _ZoomImage(
                    asset: _references[i],
                    onTap: () => _openReferences(job, initial: i + 1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          _DetailLabel('Specifications'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                _SpecRow('Alloy', job.metal),
                const _DashedLine(),
                _SpecRow('Flask Temp', temps.$1),
                const _DashedLine(),
                _SpecRow('Metal Temp', temps.$2, color: c.danger),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 22, color: c.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    job.notes ??
                        'Attention to sharp internal corners. Ensure complete burnout before casting to prevent porosity.',
                    style: AppText.bodySm.copyWith(color: c.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _DetailLabel('Completion'),
          const SizedBox(height: 12),
          if (job.stage == JobStage.casting)
            _PhotoDrop(photo: _photo, onTap: _pickPhoto, onClear: () => setState(() => _photo = null))
          else if (job.stage == JobStage.wax)
            _Banner(
              icon: Icons.hourglass_empty,
              color: c.warning,
              text:
                  'Wax model is en route. Mark it received to start casting — a casting photo is required '
                  'after the pour.',
            )
          else if (job.stage.isAfter(JobStage.casting))
            _Banner(
              icon: Icons.check_circle_outline,
              color: c.success,
              text: 'Casting completed. ${job.id} is now in ${job.stage.label}.',
            )
          else
            _Banner(
              icon: Icons.schedule,
              color: c.textMuted,
              text: '${job.id} is still in ${job.stage.label}. Casting opens once the wax model is printed.',
            ),
        ],
      ),
    );
  }

  /// (flask, metal) casting temperatures for the alloy.
  static (String, String) _castingTemps(String metal) {
    final m = metal.toLowerCase();
    if (m.contains('platinum')) return ('900°C', '2050°C');
    if (m.contains('silver')) return ('540°C', '980°C');
    if (m.contains('14k')) return ('620°C', '1000°C');
    return ('650°C', '1020°C');
  }
}

// ---- Sections --------------------------------------------------------------

class _VendorHeader extends StatelessWidget {
  const _VendorHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PATEL CASTING WORKS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelMd.copyWith(color: c.isDark ? c.gold : c.text, letterSpacing: 1.8),
              ),
            ),
            _PulseDot(color: c.accent),
            const SizedBox(width: 8),
            Text('LIVE UPDATES', style: AppText.labelSm.copyWith(color: c.textMuted, letterSpacing: 1.6)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Specialist Dashboard', style: AppText.display.copyWith(color: c.text)),
        ),
      ],
    );
  }
}

/// Rounded filter pill ("Assigned to Me" / "All Active").
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap, this.icon});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = selected ? c.onNavActive : c.textMuted;
    return Material(
      color: selected ? c.navActive : c.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 8)],
              Text(label, style: AppText.labelSm.copyWith(color: fg, fontSize: 12, letterSpacing: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded status pill (sans label, optional leading icon).
class _Pill extends StatelessWidget {
  const _Pill(this.label, {required this.bg, required this.fg, this.icon});

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(label, style: AppText.labelSm.copyWith(color: fg, letterSpacing: 0.55)),
        ],
      ),
    );
  }
}

List<BoxShadow>? _softShadow(BuildContext context) => context.c.isDark
    ? null
    : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))];

/// Horizontal dashed rule used inside the cards and spec table.
class _DashedLine extends StatelessWidget {
  const _DashedLine({this.vertical = 12});

  final double vertical;

  @override
  Widget build(BuildContext context) {
    final color = context.c.isDark ? context.c.borderStrong : context.c.surfaceHighest;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vertical),
      child: LayoutBuilder(
        builder: (context, box) {
          final n = (box.maxWidth / 7).floor();
          return Row(
            children: [
              for (var i = 0; i < n; i++) ...[
                Container(width: 4, height: 1, color: color),
                if (i < n - 1) const Spacer(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _BarTitle extends StatelessWidget {
  const _BarTitle(this.title, {super.key, required this.color, this.trailing, this.large = false});

  final String title;
  final Color color;
  final Widget? trailing;

  /// Bigger heading + bar for the primary section.
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: large ? 30 : 24,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: large ? AppText.headlineMd : AppText.headlineSm.copyWith(fontSize: 19))),
        ?trailing,
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: AppText.monoMd.copyWith(color: c.textMuted)),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.job, required this.onInstructions, required this.onImages});

  final Job job;
  final VoidCallback onInstructions;
  final VoidCallback onImages;

  /// "DUE TOMORROW" style urgency pill.
  Widget _duePill(BuildContext context) {
    final c = context.c;
    final d = job.daysUntilDue;
    final label = d < 0
        ? 'OVERDUE ${-d}D'
        : d == 0
        ? 'DUE TODAY'
        : d == 1
        ? 'DUE TOMORROW'
        : 'DUE IN $d DAYS';
    final (bg, fg) = d <= 1
        ? (c.dangerSoft, c.danger)
        : d <= 3
        ? (c.warningSoft, c.warning)
        : (c.surfaceHigh, c.textMuted);
    return _Pill(label, bg: bg, fg: fg, icon: Icons.timer_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = job.weightGrams;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: _softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onInstructions,
          child: Stack(
            children: [
              // Soft accent glow in the top-right corner.
              Positioned(
                top: -64,
                right: -64,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.accent.withValues(alpha: c.isDark ? 0.14 : 0.10),
                        c.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(job.id, style: AppText.monoMd.copyWith(color: c.accent)),
                              const SizedBox(height: 4),
                              Text(
                                job.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.headlineSm.copyWith(fontSize: 19, height: 26 / 19),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _duePill(context),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StageChip(job.stage),
                        if (job.atRisk) StatusChip('At Risk', color: c.danger, dot: true),
                        Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: Text(job.customer, style: AppText.bodySm.copyWith(color: c.textMuted)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _SpecTile(label: 'Material', value: job.metal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SpecTile(label: 'Weight', value: w == null ? '—' : '${w.toStringAsFixed(1)}g Est.'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onImages,
                          child: SizedBox(
                            width: 72,
                            height: 40,
                            child: Stack(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: c.surface, width: 2),
                                    boxShadow: _softShadow(context),
                                  ),
                                  child: ClipOval(child: Image.asset(job.image ?? Img.waxModelBlue, fit: BoxFit.cover)),
                                ),
                                Positioned(
                                  left: 32,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: c.surfaceHigh,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: c.surface, width: 2),
                                    ),
                                    child: Text('+2', style: AppText.labelSm.copyWith(color: c.textMuted)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _InstructionsButton(onPressed: onInstructions),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indigo pill CTA with a soft colored shadow.
class _InstructionsButton extends StatelessWidget {
  const _InstructionsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppText.labelMd.copyWith(fontSize: 14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text('View Instructions'), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 18)],
        ),
      ),
    );
  }
}

class _SpecTile extends StatelessWidget {
  const _SpecTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.labelSm.copyWith(color: c.textMuted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600, color: c.text),
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          DhImage(asset: job.image, width: 44, height: 44, radius: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.id, style: AppText.monoSm.copyWith(color: c.accent)),
                Text(
                  job.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.titleMd.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StageChip(job.stage),
        ],
      ),
    );
  }
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Opacity(
      opacity: 0.85,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: _softShadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(job.id, style: AppText.monoMd.copyWith(color: c.textMuted)),
                      ),
                      _Pill('Awaiting Wax', bg: c.surfaceHigh, fg: c.textMuted, icon: Icons.hourglass_empty),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(job.title, style: AppText.bodyMd.copyWith(color: c.text)),
                  const _DashedLine(vertical: 12),
                  Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 16, color: c.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Wax en route from Central Hub',
                          style: AppText.bodySm.copyWith(color: c.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dispatched = job.stage.index >= JobStage.dispatch.index;
    return Material(
      color: c.isDark ? c.surfaceLow : c.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      job.id,
                      style: AppText.monoMd.copyWith(
                        color: c.textMuted.withValues(alpha: 0.7),
                        decoration: TextDecoration.lineThrough,
                        decorationColor: c.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  dispatched
                      ? _Pill('Dispatched', bg: c.action, fg: c.onAction, icon: Icons.check_circle_outline)
                      : _Pill('Cast Complete', bg: c.success, fg: c.surface, icon: Icons.check_circle_outline),
                ],
              ),
              const SizedBox(height: 10),
              Text(job.title, style: AppText.bodyMd.copyWith(color: c.text.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomImage extends StatelessWidget {
  const _ZoomImage({required this.asset, required this.onTap});

  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: _softShadow(context)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover),
          Positioned(
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), shape: BoxShape.circle),
              child: const Icon(Icons.zoom_in, size: 16, color: Colors.white),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap),
          ),
        ],
      ),
    );
  }
}

/// Uppercase drawer section label ("REFERENCE", "SPECIFICATIONS").
class _DetailLabel extends StatelessWidget {
  const _DetailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppText.labelMd.copyWith(color: context.c.textMuted, letterSpacing: 1.0));
  }
}

/// "Alloy ........ 18K Yellow Gold" spec row.
class _SpecRow extends StatelessWidget {
  const _SpecRow(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppText.bodySm.copyWith(color: c.textMuted)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppText.monoMd.copyWith(color: color ?? c.text, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Dashed drop zone for the required casting photo (preview once picked).
class _PhotoDrop extends StatelessWidget {
  const _PhotoDrop({required this.photo, required this.onTap, required this.onClear});

  final String? photo;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (photo != null) {
      return UploadBox(title: 'Upload Casting Photo', height: 190, imagePath: photo, onTap: onTap, onClear: onClear);
    }
    return DashedBorder(
      radius: 16,
      strokeWidth: 2,
      color: c.borderStrong,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: c.surfaceHigh, shape: BoxShape.circle),
                  child: Icon(Icons.add_a_photo_outlined, size: 30, color: c.textMuted),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload Casting Photo',
                  textAlign: TextAlign.center,
                  style: AppText.headlineSm.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 4),
                Text(
                  'Required before marking complete',
                  textAlign: TextAlign.center,
                  style: AppText.bodySm.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Footer action: neutral filled "Report Issue" or the dark primary action.
class _FooterButton extends StatelessWidget {
  const _FooterButton({required this.label, required this.onPressed, this.icon, this.primary = false, this.color});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  /// Text tint for the neutral variant.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = primary ? c.action : c.surfaceHigh;
    final fg = primary ? c.onAction : (color ?? c.text);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.5),
        disabledForegroundColor: fg.withValues(alpha: 0.8),
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: AppText.labelMd.copyWith(fontSize: 14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppText.bodySm.copyWith(color: context.c.text)),
          ),
        ],
      ),
    );
  }
}

// ---- Sheets & viewer -------------------------------------------------------

class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet({required this.jobId});

  final String jobId;

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  static const _types = ['Porosity', 'Incomplete fill', 'Equipment delay', 'Other'];

  final _note = TextEditingController();
  String _type = _types.first;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Report Issue', style: AppText.headlineSm),
              const SizedBox(height: 4),
              Text(
                '${widget.jobId} will be flagged at risk and the production team notified.',
                style: AppText.bodySm.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 16),
              Field(
                label: 'Issue Type',
                child: ChoiceGroup<String>(
                  options: _types,
                  selected: _type,
                  columns: 2,
                  onChanged: (v) => setState(() => _type = v),
                ),
              ),
              const SizedBox(height: 16),
              Field(
                label: 'Details',
                child: TextField(
                  controller: _note,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.bodyMd.copyWith(color: c.text),
                  decoration: const InputDecoration(hintText: 'What happened? Affected area, flask number...'),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                'Submit Report',
                icon: Icons.report_outlined,
                color: c.danger,
                foreground: c.isDark ? c.bg : c.surface,
                onPressed: () => Navigator.pop(context, (_type, _note.text.trim())),
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
              child: Text('Pinch to zoom · swipe for more', style: AppText.bodySm.copyWith(color: c.textFaint)),
            ),
          ],
        ),
      ),
    );
  }
}

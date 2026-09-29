import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/stage_info.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Opens the Process Detail page for [stage] of [job].
void openStage(BuildContext context, Job job, JobStage stage) =>
    Navigator.pushNamed(context, Routes.stage, arguments: StageRef(job.id, stage));

Color _statusColor(DhColors c, StageStatus s) => switch (s) {
  StageStatus.done => c.success,
  StageStatus.current => c.isDark ? c.gold : c.accent,
  StageStatus.upcoming => c.textFaint,
  StageStatus.skipped => c.warning,
};

/// Process Detail: everything that happened in one stage of a job. Swipe (or tap the strip)
/// to move between the 14 stages.
class StageDetailScreen extends StatefulWidget {
  const StageDetailScreen({super.key, required this.jobId, required this.initialStage});

  final String jobId;
  final JobStage initialStage;

  @override
  State<StageDetailScreen> createState() => _StageDetailScreenState();
}

class _StageDetailScreenState extends State<StageDetailScreen> {
  static const _chipWidth = 104.0;

  late int _index = widget.initialStage.index;
  late final PageController _pages = PageController(initialPage: _index);
  late final ScrollController _strip = ScrollController(initialScrollOffset: _stripOffset(_index));

  double _stripOffset(int i) => (i * (_chipWidth + 8) - 120).clamp(0, double.infinity).toDouble();

  @override
  void dispose() {
    _pages.dispose();
    _strip.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= JobStage.values.length) return;
    _pages.animateToPage(i, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _onPage(int i) {
    setState(() => _index = i);
    if (_strip.hasClients) {
      final max = _strip.position.maxScrollExtent;
      _strip.animateTo(
        _stripOffset(i).clamp(0, max).toDouble(),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final job = app.jobOrDefault(widget.jobId);
        final stages = JobStage.values;
        final prev = _index > 0 ? stages[_index - 1] : null;
        final next = _index < stages.length - 1 ? stages[_index + 1] : null;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.maybePop(context)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Process Detail', style: AppText.headlineSm),
                Text(
                  '${job.id} · ${job.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.monoSm.copyWith(color: c.textFaint),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Open job',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => Navigator.pushNamed(context, Routes.job, arguments: job.id),
              ),
            ],
          ),
          body: Column(
            children: [
              SizedBox(
                height: 72,
                child: ListView.separated(
                  controller: _strip,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: stages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => _StripChip(
                    width: _chipWidth,
                    index: i,
                    record: StageRecord.of(job, stages[i]),
                    selected: i == _index,
                    onTap: () => _go(i),
                  ),
                ),
              ),
              Divider(height: 1, color: c.border),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: stages.length,
                  onPageChanged: _onPage,
                  itemBuilder: (ctx, i) => _StagePage(job: job, stage: stages[i]),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: prev == null ? null : () => _go(_index - 1),
                      icon: const Icon(Icons.chevron_left),
                      label: Text(prev?.short ?? '', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  Text('${_index + 1} / ${stages.length}', style: AppText.monoMd.copyWith(color: c.textMuted)),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: TextButton.icon(
                        onPressed: next == null ? null : () => _go(_index + 1),
                        icon: const Icon(Icons.chevron_left, textDirection: TextDirection.rtl),
                        label: Text(next?.short ?? '', overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StripChip extends StatelessWidget {
  const _StripChip({
    required this.width,
    required this.index,
    required this.record,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final int index;
  final StageRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final sc = _statusColor(c, record.status);
    return SizedBox(
      width: width,
      child: Material(
        color: selected ? c.accentSoft : (c.isDark ? c.surface : c.surfaceLow),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? c.accent : c.border, width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      record.status == StageStatus.done
                          ? Icons.check_circle
                          : record.status == StageStatus.current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: sc,
                    ),
                    const SizedBox(width: 4),
                    Text('${index + 1}'.padLeft(2, '0'), style: AppText.monoSm.copyWith(color: c.textFaint)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  record.stage.short,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelMd.copyWith(
                    fontSize: 13,
                    color: record.status == StageStatus.upcoming ? c.textFaint : c.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StagePage extends StatelessWidget {
  const _StagePage({required this.job, required this.stage});

  final Job job;
  final JobStage stage;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = StageRecord.of(job, stage);
    final info = StageInfo.of(stage);
    final isInquiryOrder = stage == JobStage.inquiry && job.order != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Header(record: r, info: info),
        const SizedBox(height: 12),
        _RecordCard(record: r, info: info, job: job),
        if (r.data.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailsCard(record: r),
        ] else if (r.status == StageStatus.current) ...[
          const SizedBox(height: 12),
          DhCard(
            child: Row(
              children: [
                Icon(Icons.edit_note, color: c.textFaint),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nothing recorded yet. Use Mark Complete below or open the ${info.workspace} screen to record details.',
                    style: AppText.bodySm.copyWith(color: c.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (isInquiryOrder) ...[const SizedBox(height: 12), JobOrderSpecs(order: job.order!, initiallyExpanded: -1)],
        if (r.files.isNotEmpty) ...[const SizedBox(height: 12), _FilesCard(files: r.files)],
        if (r.activity.isNotEmpty) ...[const SizedBox(height: 12), _ActivityCard(messages: r.activity)],
        const SizedBox(height: 12),
        _ChecklistCard(record: r, info: info),
        const SizedBox(height: 16),
        if (r.status == StageStatus.current && stage.next != null) ...[
          PrimaryButton(
            'Mark ${stage.short} Complete',
            icon: Icons.check_circle_outline,
            onPressed: () => showCompleteStageSheet(context, job),
          ),
          const SizedBox(height: 10),
        ],
        SecondaryButton(
          'Open ${info.workspace}',
          icon: Icons.open_in_new,
          onPressed: () => Navigator.pushNamed(context, Routes.forStage(stage), arguments: job.id),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.record, required this.info});

  final StageRecord record;
  final StageInfo info;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = record.stage;
    final sc = _statusColor(c, record.status);
    return DhCard(
      accentTop: record.status == StageStatus.current,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: s.color.withValues(alpha: 0.35)),
                ),
                child: Icon(s.icon, color: s.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STAGE ${s.index + 1} OF ${JobStage.values.length}',
                      style: AppText.monoCaps.copyWith(color: c.textFaint),
                    ),
                    const SizedBox(height: 2),
                    Text(s.label, style: AppText.headlineMd),
                  ],
                ),
              ),
              StatusChip(record.status.label, color: sc, dot: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(info.summary, style: AppText.bodyMd.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.info, required this.job});

  final StageRecord record;
  final StageInfo info;
  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = record;
    if (r.status == StageStatus.upcoming) {
      final prev = r.stage.index > 0 ? JobStage.values[r.stage.index - 1] : null;
      return DhCard(
        child: Row(
          children: [
            Icon(Icons.hourglass_empty, color: c.textFaint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not started yet', style: AppText.titleMd),
                  const SizedBox(height: 2),
                  Text(
                    'Starts after ${prev?.label ?? 'order creation'}. Handled by ${info.owner}. '
                    'Current stage: ${job.stage.label}.',
                    style: AppText.bodySm.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (r.status == StageStatus.skipped) {
      return DhCard(
        color: c.warningSoft,
        borderColor: c.warning.withValues(alpha: 0.4),
        child: Row(
          children: [
            Icon(Icons.fast_forward_outlined, color: c.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'This stage was skipped — the job was moved past it on the Production Floor.',
                style: AppText.bodySm.copyWith(color: c.text),
              ),
            ),
          ],
        ),
      );
    }
    final dur = r.duration;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Stage record'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: LabelValue('Started', r.start == null ? '—' : Fmt.relativeDay(r.start!), mono: true)),
              const SizedBox(width: 12),
              Expanded(
                child: LabelValue(
                  'Completed',
                  r.status == StageStatus.current ? 'In progress' : (r.end == null ? '—' : Fmt.relativeDay(r.end!)),
                  mono: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabelValue(
                  r.status == StageStatus.current ? 'Time so far' : 'Time taken',
                  dur == null ? '—' : formatDuration(dur),
                  mono: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LabelValue(r.status == StageStatus.current ? 'Assigned to' : 'Completed by', r.by ?? info.owner),
              ),
            ],
          ),
          if (r.note != null && r.note!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.isDark ? c.surfaceLow : c.surfaceLow,
                borderRadius: BorderRadius.circular(6),
                border: Border(left: BorderSide(color: c.accent, width: 3)),
              ),
              child: Text(r.note!, style: AppText.bodySm),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.record});

  final StageRecord record;

  @override
  Widget build(BuildContext context) {
    final entries = record.data.entries.toList();
    return DhCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            record.status == StageStatus.current ? 'Recorded so far' : 'What happened',
            trailing: Text('${entries.length}', style: AppText.monoSm.copyWith(color: context.c.textFaint)),
          ),
          const SizedBox(height: 4),
          for (final (i, e) in entries.indexed) KeyValueRow(e.key, e.value, divider: i < entries.length - 1),
        ],
      ),
    );
  }
}

class _FilesCard extends StatelessWidget {
  const _FilesCard({required this.files});

  final List<ProjectFile> files;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            'Photos & files',
            trailing: Text('${files.length}', style: AppText.monoSm.copyWith(color: c.textFaint)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final f = files[i];
                final isImage = f.asset != null || f.localPath != null;
                return GestureDetector(
                  onTap: isImage ? () => _viewImage(context, f) : () => showSnack(context, 'Opening ${f.name}…'),
                  child: SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isImage
                            ? DhImage(asset: f.asset, file: f.localPath, width: 96, height: 80, radius: 6)
                            : Container(
                                width: 96,
                                height: 80,
                                decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(6)),
                                child: Icon(f.icon, color: c.textMuted),
                              ),
                        const SizedBox(height: 6),
                        Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.monoSm),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _viewImage(BuildContext context, ProjectFile f) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: InteractiveViewer(
          child: Center(
            child: DhImage(asset: f.asset, file: f.localPath, fit: BoxFit.contain, radius: 0),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.messages});

  final List<ThreadMessage> messages;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            'Activity in this stage',
            trailing: Text('${messages.length}', style: AppText.monoSm.copyWith(color: c.textFaint)),
          ),
          const SizedBox(height: 8),
          for (final (i, m) in messages.indexed)
            PipelineTile(
              title: m.title ?? m.author,
              subtitle: '${m.title == null ? '' : '${m.author} · '}${Fmt.relativeDay(m.time)}',
              state: PipelineState.done,
              isLast: i == messages.length - 1,
              child: Text(m.text, style: AppText.bodySm.copyWith(color: c.textMuted)),
            ),
        ],
      ),
    );
  }
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.record, required this.info});

  final StageRecord record;
  final StageInfo info;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = record.status == StageStatus.done;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(
            'Stage checklist',
            trailing: Text(info.owner, style: AppText.labelMd.copyWith(color: c.textFaint)),
          ),
          const SizedBox(height: 10),
          for (final item in info.checklist)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: done ? c.success : c.textFaint,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: AppText.bodyMd.copyWith(
                        color: record.status == StageStatus.upcoming ? c.textFaint : c.text,
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

/// The job's 14 stages as tappable rows (Job Detail → Process tab).
class JobProcessList extends StatelessWidget {
  const JobProcessList({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stages = JobStage.values;
    final done = stages.where((s) => s.index < job.stage.index).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        DhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Production Process', style: AppText.headlineSm)),
                  Text('$done/${stages.length - 1} done', style: AppText.monoMd.copyWith(color: c.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              ThinProgress(value: job.progress),
              const SizedBox(height: 10),
              Text(
                'Tap any stage to see what happened in it — dates, who handled it, details, photos and messages.',
                style: AppText.bodySm.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final s in stages) ...[_ProcessRow(job: job, record: StageRecord.of(job, s)), const SizedBox(height: 8)],
      ],
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.job, required this.record});

  final Job job;
  final StageRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = record;
    final s = r.stage;
    final sc = _statusColor(c, r.status);
    final upcoming = r.status == StageStatus.upcoming;
    String sub;
    switch (r.status) {
      case StageStatus.done:
        sub = [
          if (r.end != null) Fmt.date(r.end!) else if (r.start != null) Fmt.date(r.start!),
          ?r.by,
          if (r.duration != null) formatDuration(r.duration!),
        ].join(' · ');
      case StageStatus.current:
        sub = 'In progress${r.start == null ? '' : ' since ${Fmt.relativeDay(r.start!)}'}';
      case StageStatus.upcoming:
        sub = StageInfo.of(s).owner;
      case StageStatus.skipped:
        sub = 'Skipped';
    }
    final preview = r.data.entries.take(2).map((e) => '${e.key}: ${e.value}').join('  •  ');
    return DhCard(
      onTap: () => openStage(context, job, s),
      borderColor: r.status == StageStatus.current ? sc : null,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: upcoming ? c.surfaceHigh : s.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(s.icon, size: 20, color: upcoming ? c.textFaint : s.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${s.index + 1}'.padLeft(2, '0'), style: AppText.monoSm.copyWith(color: c.textFaint)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleMd.copyWith(fontSize: 15, color: upcoming ? c.textFaint : c.text),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: c.textMuted),
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.monoSm.copyWith(color: c.textFaint),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            r.status == StageStatus.done
                ? Icons.check_circle
                : r.status == StageStatus.current
                ? Icons.radio_button_checked
                : Icons.chevron_right,
            color: sc,
            size: 20,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to complete the job's current stage with who/notes/photo, then advance.
Future<void> showCompleteStageSheet(BuildContext context, Job job) async {
  final stage = job.stage;
  final next = stage.next;
  if (next == null) return;
  final by = TextEditingController(text: app.userName);
  final note = TextEditingController();
  String? photo;
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final c = ctx.c;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Complete ${stage.label}', style: AppText.headlineSm),
                const SizedBox(height: 4),
                Text(
                  '${job.id} moves to ${next.label}. What you enter here is saved in the ${stage.label} record.',
                  style: AppText.bodySm.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 16),
                Field(
                  label: 'Completed by',
                  child: TextField(
                    controller: by,
                    decoration: const InputDecoration(hintText: 'Name / bench / vendor'),
                  ),
                ),
                const SizedBox(height: 14),
                Field(
                  label: 'Notes',
                  child: TextField(
                    controller: note,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'What was done, any issues…'),
                  ),
                ),
                const SizedBox(height: 14),
                UploadBox(
                  title: 'Add Photo (optional)',
                  subtitle: 'Proof of work for this stage',
                  height: 110,
                  imagePath: photo,
                  onTap: () async {
                    final p = await pickImage(ctx, title: '${stage.label} Photo');
                    if (p != null) setSheet(() => photo = p);
                  },
                  onClear: () => setSheet(() => photo = null),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(ctx, true),
                        icon: const Icon(Icons.check),
                        label: const Text('Mark Complete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (done == true) {
    app.completeStage(job, by: by.text, note: note.text.trim().isEmpty ? null : note.text.trim(), photoPath: photo);
    if (context.mounted) showSnack(context, '${job.id} moved to ${next.label}', icon: Icons.check_circle_outline);
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    by.dispose();
    note.dispose();
  });
}

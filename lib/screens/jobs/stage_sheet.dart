import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/stage_info.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Keys shown in the sheet's fact grid, so they're left out of "What happened".
const _factKeys = {'Assigned To', 'Expected'};

Color _statusColor(DhColors c, StageStatus s) => switch (s) {
  StageStatus.done => c.success,
  StageStatus.current => c.isDark ? c.gold : c.accent,
  StageStatus.upcoming => c.textMuted,
  StageStatus.skipped => c.warning,
};

String _statusLabel(StageStatus s) => switch (s) {
  StageStatus.done => 'Completed',
  StageStatus.current => 'In Progress',
  StageStatus.upcoming => 'Pending',
  StageStatus.skipped => 'Skipped',
};

/// Who holds the stage: the completer for finished stages, else the assignee (if any).
String? _heldBy(Job job, StageRecord r) {
  final assigned = r.data['Assigned To'];
  switch (r.status) {
    case StageStatus.done:
    case StageStatus.skipped:
      return r.by ?? assigned;
    case StageStatus.current:
      return assigned ?? job.assignee;
    case StageStatus.upcoming:
      return assigned;
  }
}

/// Slides up the details of [stage] over the current page (scrolls when long).
Future<void> openStage(BuildContext context, Job job, JobStage stage) {
  final c = context.c;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: c.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _StageSheet(jobId: job.id, stage: stage),
  );
}

class _StageSheet extends StatelessWidget {
  const _StageSheet({required this.jobId, required this.stage});

  final String jobId;
  final JobStage stage;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final c = context.c;
          final job = app.jobOrDefault(jobId);
          final r = StageRecord.of(job, stage);
          final info = StageInfo.of(stage);
          final details = [
            for (final e in r.data.entries)
              if (!_factKeys.contains(e.key)) e,
          ];
          final held = _heldBy(job, r);
          final dur = r.duration;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('${stage.index + 1}. ${stage.label}', style: AppText.headlineLg)),
                        const SizedBox(width: 12),
                        _StatusPill(label: _statusLabel(r.status), color: _statusColor(c, r.status)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${job.id} · ${job.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.monoSm.copyWith(color: c.textFaint),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _Fact('Received', r.start == null ? 'Not reached' : Fmt.relativeDay(r.start!))),
                        const SizedBox(width: 16),
                        Expanded(
                          child: r.status == StageStatus.done
                              ? _Fact('Completed', r.end == null ? '—' : Fmt.relativeDay(r.end!))
                              : _Fact('Expected', r.data['Expected'] ?? 'Not promised'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _Fact(
                      r.status == StageStatus.done ? 'Time taken' : 'Time in stage',
                      dur == null ? '—' : formatDuration(dur),
                    ),
                    const SizedBox(height: 22),
                    _Fact(
                      r.status == StageStatus.done ? 'Completed by' : 'Held by',
                      held ?? 'Nobody yet',
                      icon: Icons.person_outline,
                      sans: true,
                    ),
                    if (r.note != null && r.note!.isNotEmpty) ...[const SizedBox(height: 18), _NoteBox(text: r.note!)],
                    const SizedBox(height: 22),
                    Text(info.summary, style: AppText.bodyMd.copyWith(color: c.textMuted)),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _SheetSection(
                        title: r.status == StageStatus.current ? 'Recorded so far' : 'What happened',
                        count: details.length,
                        child: Column(
                          children: [
                            for (final (i, e) in details.indexed)
                              KeyValueRow(e.key, e.value, divider: i < details.length - 1),
                          ],
                        ),
                      ),
                    ],
                    if (stage == JobStage.inquiry && job.order != null) ...[
                      const SizedBox(height: 16),
                      JobOrderSpecs(order: job.order!, initiallyExpanded: -1),
                    ],
                    if (r.files.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _SheetSection(
                        title: 'Photos & files',
                        count: r.files.length,
                        child: _FilesStrip(files: r.files),
                      ),
                    ],
                    if (r.activity.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _SheetSection(
                        title: 'Activity',
                        count: r.activity.length,
                        child: Column(
                          children: [
                            for (final (i, m) in r.activity.indexed)
                              PipelineTile(
                                title: m.title ?? m.author,
                                subtitle: '${m.title == null ? '' : '${m.author} · '}${Fmt.relativeDay(m.time)}',
                                isLast: i == r.activity.length - 1,
                                child: Text(m.text, style: AppText.bodySm.copyWith(color: c.textMuted)),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _SheetSection(
                      title: 'Checklist',
                      trailing: info.owner,
                      child: Column(
                        children: [
                          for (final item in info.checklist)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    r.status == StageStatus.done ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 18,
                                    color: r.status == StageStatus.done ? c.success : c.textFaint,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(item, style: AppText.bodyMd)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pushNamed(context, Routes.forStage(stage), arguments: job.id),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: Text('Open ${info.workspace}'),
                      ),
                    ),
                  ],
                ),
              ),
              _ActionBar(job: job, record: r),
            ],
          );
        },
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: color == c.textMuted ? c.borderStrong : color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: AppText.monoCaps.copyWith(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

/// Mono caps label over a large value, as in the stage sheet design.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.icon, this.sans = false});

  final String label;
  final String value;
  final IconData? icon;
  final bool sans;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final vs = sans ? AppText.bodyLg.copyWith(fontSize: 18) : AppText.monoLg.copyWith(fontSize: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.monoCaps.copyWith(fontSize: 12, letterSpacing: 1.6, color: c.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 22, color: c.textMuted), const SizedBox(width: 10)],
            Expanded(child: Text(value, style: vs)),
          ],
        ),
      ],
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.isDark ? c.surface : c.surfaceLow,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: c.accent, width: 3)),
      ),
      child: Text(text, style: AppText.bodyMd),
    );
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({required this.title, required this.child, this.count, this.trailing});

  final String title;
  final Widget child;
  final int? count;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppText.monoCaps.copyWith(fontSize: 12, letterSpacing: 1.6, color: c.textMuted),
                ),
              ),
              if (count != null) Text('$count', style: AppText.monoSm.copyWith(color: c.textFaint)),
              if (trailing != null)
                Flexible(
                  child: Text(
                    trailing!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelMd.copyWith(color: c.textFaint),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _FilesStrip extends StatelessWidget {
  const _FilesStrip({required this.files});

  final List<ProjectFile> files;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 6),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final f = files[i];
          final isImage = f.asset != null || f.localPath != null;
          return GestureDetector(
            onTap: isImage ? () => _view(context, f) : () => showSnack(context, 'Opening ${f.name}…'),
            child: SizedBox(
              width: 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  isImage
                      ? DhImage(asset: f.asset, file: f.localPath, width: 96, height: 78, radius: 8)
                      : Container(
                          width: 96,
                          height: 78,
                          decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(8)),
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
    );
  }

  void _view(BuildContext context, ProjectFile f) {
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

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.job, required this.record});

  final Job job;
  final StageRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = record.stage;
    final info = StageInfo.of(s);
    Widget child;
    switch (record.status) {
      case StageStatus.upcoming:
        final assigned = record.data['Assigned To'];
        child = PrimaryButton(
          assigned == null ? 'Assign ${s.short}' : 'Reassign ${s.short}',
          icon: Icons.person_add_alt_1_outlined,
          onPressed: () => showAssignStageSheet(context, job, s),
        );
      case StageStatus.current:
        if (s.next == null) {
          child = PrimaryButton(
            'Open ${info.workspace}',
            icon: Icons.open_in_new,
            onPressed: () => Navigator.pushNamed(context, Routes.forStage(s), arguments: job.id),
          );
        } else {
          child = Row(
            children: [
              SizedBox(
                width: 56,
                child: OutlinedButton(
                  onPressed: () => showAssignStageSheet(context, job, s),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(56, 52)),
                  child: const Icon(Icons.person_add_alt_1_outlined),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  'Mark ${s.short} Complete',
                  icon: Icons.check_circle_outline,
                  onPressed: () => showCompleteStageSheet(context, job),
                ),
              ),
            ],
          );
        }
      case StageStatus.done:
      case StageStatus.skipped:
        child = SecondaryButton(
          'Open ${info.workspace}',
          icon: Icons.open_in_new,
          onPressed: () => Navigator.pushNamed(context, Routes.forStage(s), arguments: job.id),
        );
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: child,
      ),
    );
  }
}

/// Words that match partner roles suitable for each stage (for sorting the assign list).
const _roleHints = <JobStage, List<String>>{
  JobStage.cad: ['CAD', 'Designer'],
  JobStage.approval: ['Retailer', 'Designer'],
  JobStage.finalApproval: ['Retailer'],
  JobStage.casting: ['Casting'],
  JobStage.setting: ['Setter'],
  JobStage.assembly: ['Setter'],
  JobStage.qc: ['QC'],
  JobStage.certification: ['Lab'],
  JobStage.dispatch: ['Courier'],
  JobStage.delivered: ['Retailer'],
};

/// Pick who holds [stage] and an optional expected date.
Future<void> showAssignStageSheet(BuildContext context, Job job, JobStage stage) async {
  final hints = _roleHints[stage] ?? const <String>[];
  bool fits(Partner p) => hints.any((h) => p.role.contains(h));
  final partners = [...app.partners]..sort((a, b) => (fits(b) ? 1 : 0) - (fits(a) ? 1 : 0));
  DateTime? expected;
  final picked = await showModalBottomSheet<Partner>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final c = ctx.c;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Assign ${stage.label}', style: AppText.headlineSm),
              const SizedBox(height: 4),
              Text(
                'Choose who will hold this stage for ${job.id}.',
                style: AppText.bodySm.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 16),
              Field(
                label: 'Expected by (optional)',
                child: DateField(value: expected, onChanged: (d) => setSheet(() => expected = d)),
              ),
              const SizedBox(height: 16),
              const SectionLabel('Partners'),
              const SizedBox(height: 6),
              for (final p in partners)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: DhAvatar(asset: p.avatar, name: p.name, size: 40),
                  title: Text(p.name),
                  subtitle: Text('${p.role} · ${p.activeJobs} active'),
                  trailing: fits(p) ? StatusChip('Match', color: c.success) : null,
                  onTap: () => Navigator.pop(ctx, p),
                ),
            ],
          ),
        );
      },
    ),
  );
  if (picked == null) return;
  app.assignStage(job, stage, picked.name, expected: expected);
  if (context.mounted) showSnack(context, '${picked.name} assigned to ${stage.label}', icon: Icons.person_outline);
}

/// The job's 14 stages as tappable rows (Job Detail → Process tab). Tapping opens the stage sheet.
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
                  Expanded(child: Text('Lifecycle', style: AppText.headlineSm)),
                  Text('$done/${stages.length - 1} done', style: AppText.monoMd.copyWith(color: c.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              ThinProgress(value: job.progress),
              const SizedBox(height: 10),
              Text(
                'Tap any stage to see what happened in it — dates, who holds it, details, photos and messages.',
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
    final held = _heldBy(job, r);
    final String sub;
    switch (r.status) {
      case StageStatus.done:
        sub = [
          if (r.end != null) Fmt.date(r.end!) else if (r.start != null) Fmt.date(r.start!),
          ?held,
          if (r.duration != null) formatDuration(r.duration!),
        ].join(' · ');
      case StageStatus.current:
        sub = ['In progress${r.start == null ? '' : ' since ${Fmt.relativeDay(r.start!)}'}', ?held].join(' · ');
      case StageStatus.upcoming:
        sub = held == null
            ? 'Pending · ${StageInfo.of(s).owner}'
            : 'Assigned: $held${r.data['Expected'] == null ? '' : ' · by ${r.data['Expected']}'}';
      case StageStatus.skipped:
        sub = 'Skipped';
    }
    final preview = r.data.entries
        .where((e) => !_factKeys.contains(e.key))
        .take(2)
        .map((e) => '${e.key}: ${e.value}')
        .join('  •  ');
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
  final by = TextEditingController(text: job.stageData[stage]?['Assigned To'] ?? job.assignee ?? app.userName);
  final note = TextEditingController();
  String? photo;
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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

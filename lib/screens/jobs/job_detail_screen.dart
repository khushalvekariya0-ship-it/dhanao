import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';
import 'stage_sheet.dart';

/// Job detail hub (design: job_detail_dh_1048): overview, digital thread, files.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

enum _Menu { risk, share, tracker }

class _JobDetailScreenState extends State<JobDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onMenu(Job job, _Menu m) {
    switch (m) {
      case _Menu.risk:
        app.toggleRisk(job);
        showSnack(
          context,
          job.atRisk ? '${job.id} flagged as at risk' : '${job.id} no longer flagged',
          icon: job.atRisk ? Icons.flag : Icons.outlined_flag,
        );
      case _Menu.share:
        Clipboard.setData(
          ClipboardData(
            text:
                '${job.id} · ${job.title}\n${job.customer} · ${job.stage.label}\n'
                'Due ${Fmt.dateLong(job.dueDate)} · ${Fmt.money(job.value)}',
          ),
        );
        showSnack(context, 'Job summary copied — paste to share', icon: Icons.share_outlined);
      case _Menu.tracker:
        Navigator.pushNamed(context, Routes.tracker, arguments: job.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final job = app.jobOrDefault(widget.jobId);
        final c = context.c;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.maybePop(context)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: AppText.headlineSm, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(job.id, style: AppText.monoSm.copyWith(color: c.textFaint)),
              ],
            ),
            actions: [
              PopupMenuButton<_Menu>(
                tooltip: 'Job options',
                onSelected: (m) => _onMenu(job, m),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _Menu.risk,
                    child: _MenuRow(
                      icon: job.atRisk ? Icons.outlined_flag : Icons.flag_outlined,
                      label: job.atRisk ? 'Unmark at risk' : 'Mark at risk',
                    ),
                  ),
                  const PopupMenuItem(
                    value: _Menu.share,
                    child: _MenuRow(icon: Icons.share_outlined, label: 'Share'),
                  ),
                  const PopupMenuItem(
                    value: _Menu.tracker,
                    child: _MenuRow(icon: Icons.timeline, label: 'Workflow tracker'),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: [
                const Tab(text: 'Overview'),
                const Tab(text: 'Process'),
                Tab(text: 'Thread (${job.thread.length})'),
                Tab(text: 'Files (${job.files.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _OverviewTab(job: job, onViewFiles: () => _tabs.animateTo(3)),
              JobProcessList(job: job),
              _ThreadTab(job: job),
              _FilesTab(job: job),
            ],
          ),
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.c.textMuted),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

// ---- Shared actions ----------------------------------------------------------

Future<void> _markComplete(BuildContext context, Job job) => showCompleteStageSheet(context, job);

Future<void> _uploadPhoto(BuildContext context, Job job) async {
  final path = await pickImage(context, title: 'Upload Photo · ${job.id}');
  if (path == null || !context.mounted) return;
  final now = DateTime.now();
  final ext = path.contains('.') ? path.split('.').last.toLowerCase() : 'jpg';
  final stamp =
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  final name = '${job.stage.short.toLowerCase().replaceAll(' ', '_')}_photo_$stamp.$ext';
  app.addFile(
    job,
    ProjectFile(
      name: name,
      kind: FileKind.image,
      localPath: path,
      jobId: job.id,
      uploadedBy: app.userName,
      sizeLabel: _sizeLabel(path),
    ),
  );
  showSnack(context, '$name uploaded to ${job.id}', icon: Icons.photo_outlined);
}

String _sizeLabel(String path) {
  try {
    final bytes = File(path).lengthSync();
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).ceil()} KB';
  } catch (_) {
    return '—';
  }
}

bool _viewable(ProjectFile f) => f.asset != null || f.localPath != null;

void _openFile(BuildContext context, ProjectFile f) {
  if (!_viewable(f)) {
    showSnack(context, 'Opening ${f.name}…', icon: f.icon);
    return;
  }
  showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: f.localPath != null ? Image.file(File(f.localPath!)) : Image.asset(f.asset!)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      f.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.monoMd.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Image thumbnail for viewable files, otherwise a big file-type icon.
class _FileThumb extends StatelessWidget {
  const _FileThumb({required this.file, this.iconSize = 44});

  final ProjectFile file;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_viewable(file)) return DhImage(asset: file.asset, file: file.localPath);
    return Container(
      decoration: BoxDecoration(color: c.isDark ? c.surfaceHigh : c.surfaceLow, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Icon(file.icon, size: iconSize, color: c.textMuted),
    );
  }
}

// ---- Overview ------------------------------------------------------------------

Duration _expectedDuration(JobStage s) => Duration(
  hours: switch (s) {
    JobStage.inquiry => 24,
    JobStage.cad => 72,
    JobStage.approval => 24,
    JobStage.pricing => 24,
    JobStage.finalApproval => 48,
    JobStage.wax => 24,
    JobStage.casting => 32,
    JobStage.assembly => 48,
    JobStage.setting => 48,
    JobStage.polishing => 24,
    JobStage.qc => 12,
    JobStage.certification => 96,
    JobStage.dispatch => 48,
    JobStage.delivered => 0,
  },
);

class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.job, required this.onViewFiles});

  final Job job;
  final VoidCallback onViewFiles;

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> with AutomaticKeepAliveClientMixin {
  final _timeline = ScrollController();
  JobStage? _revealed;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  double _nodeWidth(JobStage s, bool current) {
    final tp = TextPainter(
      text: TextSpan(
        text: s.short,
        style: AppText.labelMd.copyWith(fontWeight: current ? FontWeight.w700 : FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = (current ? 26.0 : (s.index < widget.job.stage.index ? 22.0 : 16.0)) + 6 + tp.width + (current ? 16 : 0);
    tp.dispose();
    return w;
  }

  /// Scrolls the pipeline so the current stage sits near the middle.
  void _revealStage() {
    final stage = widget.job.stage;
    if (_revealed == stage) return;
    _revealed = stage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_timeline.hasClients) return;
      var x = 16.0;
      for (final s in JobStage.values) {
        if (s == stage) break;
        x += _nodeWidth(s, false) + 32;
      }
      final p = _timeline.position;
      final target = (x + _nodeWidth(stage, true) / 2 - p.viewportDimension / 2).clamp(0.0, p.maxScrollExtent);
      _timeline.animateTo(target.toDouble(), duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _revealStage();
    final job = widget.job;
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _IdHeader(job: job),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _MetaGrid(job: job),
        ),
        const SizedBox(height: 16),
        PrimaryScrollController(
          controller: _timeline,
          scrollDirection: Axis.horizontal,
          automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
          child: StageTimeline(current: job.stage, onTap: (s) => openStage(context, job, s)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CurrentStageCard(job: job),
              const SizedBox(height: 16),
              _ProductCard(job: job),
              if (job.order != null) ...[const SizedBox(height: 16), JobOrderSpecs(order: job.order!)],
              const SizedBox(height: 16),
              _NetworkHub(job: job),
              const SizedBox(height: 16),
              _FilesPreview(job: job, onViewAll: widget.onViewFiles),
              const SizedBox(height: 24),
              _StageScreens(job: job),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdHeader extends StatelessWidget {
  const _IdHeader({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (job.priority != Priority.standard)
              StatusChip(job.priority.label.toUpperCase(), color: c.accent, filled: true, mono: false),
            if (job.atRisk || job.isOverdue)
              StatusChip(job.isOverdue ? 'Overdue' : 'At Risk', color: c.danger, dot: true),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(color: c.isDark ? c.gold : c.accent),
                const SizedBox(width: 6),
                Text('Live Thread', style: AppText.monoMd.copyWith(color: c.textMuted)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            job.id,
            style: AppText.display.copyWith(fontFamily: AppText.mono, letterSpacing: -0.5, color: c.text),
          ),
        ),
        const SizedBox(height: 2),
        Text('${job.productType} · ${job.title}', style: AppText.bodyLg.copyWith(color: c.textMuted)),
      ],
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
      opacity: Tween(begin: 0.3, end: 1.0).animate(_ctrl),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  const _MetaGrid({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      child: OptionLayout(
        columns: 2,
        spacing: 16,
        children: [
          LabelValue('Customer', job.customer),
          LabelValue('Manufacturer', job.manufacturer),
          LabelValue(
            'Due Date',
            Fmt.date(job.dueDate),
            valueStyle: AppText.titleMd.copyWith(color: !job.isComplete && job.daysUntilDue <= 0 ? c.danger : c.text),
          ),
          LabelValue('Value', Fmt.money(job.value), mono: true),
        ],
      ),
    );
  }
}

class _CurrentStageCard extends StatelessWidget {
  const _CurrentStageCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stage = job.stage;
    final next = stage.next;
    final entered = job.stageEnteredAt ?? (job.history.isNotEmpty ? job.history.last.at : DateTime.now());
    final expected = entered.add(_expectedDuration(stage));
    final late = !job.isComplete && DateTime.now().isAfter(expected);
    final holder = job.assignee ?? job.manufacturer;
    return DhCard(
      accentTop: c.isDark,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [c.accent.withValues(alpha: 0.12), c.accent.withValues(alpha: 0)]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(stage.icon, color: c.accent, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.isComplete ? 'Delivered to customer' : '${stage.label} in progress',
                        style: AppText.headlineMd,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'at ',
                        style: AppText.bodyLg.copyWith(color: c.textMuted),
                      ),
                      TextSpan(
                        text: holder,
                        style: AppText.headlineSm.copyWith(color: c.text),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _TimeBox(label: 'Received', value: Fmt.dateTime(entered)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 18, color: c.textFaint),
                    ),
                    Expanded(
                      child: _TimeBox(
                        label: 'Expected',
                        value: Fmt.dateTime(expected),
                        color: late ? c.danger : c.accent,
                      ),
                    ),
                  ],
                ),
                if (late) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Past the expected hand-off by ${Fmt.ago(expected).replaceAll(' ago', '')}.',
                    style: AppText.bodySm.copyWith(color: c.danger),
                  ),
                ],
                const SizedBox(height: 18),
                if (next != null) ...[
                  PrimaryButton(
                    'Mark Complete',
                    icon: Icons.check_circle_outline,
                    onPressed: () => _markComplete(context, job),
                  ),
                  const SizedBox(height: 10),
                ],
                SecondaryButton(
                  'Upload Photo',
                  icon: Icons.add_a_photo_outlined,
                  onPressed: () => _uploadPhoto(context, job),
                ),
                if (next != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Next: ${next.label}',
                    textAlign: TextAlign.center,
                    style: AppText.monoSm.copyWith(color: c.textFaint),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.isDark ? c.surfaceHigh : c.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.labelSm.copyWith(color: c.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.monoMd.copyWith(
                color: color ?? c.text,
                fontWeight: color == null ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final specs = <(String, String)>[
      ('Product', job.quantity > 1 ? '${job.productType} × ${job.quantity}' : job.productType),
      ('Material', job.metal),
      if (job.centerStone != '—') ('Center Stone', job.centerStone),
      if (job.settingStyle != '—') ('Setting Style', job.settingStyle),
      if (job.weightGrams != null) ('Weight', Fmt.grams(job.weightGrams!)),
      if (job.ringSize != null) ('Ring Size', job.ringSize!),
    ];
    final image = job.image;
    return DhCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: image == null
                ? null
                : () =>
                      _openFile(context, ProjectFile(name: '${job.id}_render.jpg', kind: FileKind.image, asset: image)),
            child: SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DhImage(asset: image, radius: 0, placeholderIcon: Icons.diamond_outlined),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.center,
                        colors: [Colors.black.withValues(alpha: 0.65), Colors.black.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            job.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.headlineSm.copyWith(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Text('v2.FINAL', style: AppText.monoSm.copyWith(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                for (final (label, value) in specs) ...[
                  _SpecRow(label: label, value: value),
                  if (label != specs.last.$1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: c.isDark ? c.surfaceHigh : c.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Text(label, style: AppText.labelMd.copyWith(color: c.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.monoMd.copyWith(color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AvatarStyle { photo, dark, icon }

class _Participant {
  const _Participant(this.partner, this.role, {this.active = false, this.style = _AvatarStyle.photo});

  final Partner partner;
  final String role;
  final bool active;
  final _AvatarStyle style;
}

List<_Participant> _participants(Job job) {
  final out = <_Participant>[];
  void add(_Participant p) {
    if (out.every((o) => o.partner.name != p.partner.name)) out.add(p);
  }

  final designer = app.partnerByName('Sarah J.') ?? const Partner(name: 'Sarah J.', role: 'Lead Designer');
  add(_Participant(designer, designer.role));
  final assignee = job.assignee;
  if (assignee != null) {
    final p =
        app.partnerByName(assignee) ??
        Partner(name: assignee, role: 'In-house Bench', company: job.manufacturer, location: 'Mumbai, IN');
    add(_Participant(p, '${job.stage.label} (Active)', active: true));
  }
  final customer = app.partnerByName(job.customer) ?? Partner(name: job.customer, role: 'Client');
  add(_Participant(customer, customer.role, style: _AvatarStyle.dark));
  final stones = app.partnerByName('GemSource') ?? const Partner(name: 'GemSource', role: 'Stone Provider');
  add(_Participant(stones, stones.role, style: _AvatarStyle.icon));
  return out;
}

class _ParticipantAvatar extends StatelessWidget {
  const _ParticipantAvatar({required this.participant, this.size = 40});

  final _Participant participant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = participant.partner;
    if (participant.style == _AvatarStyle.icon && p.avatar == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.isDark ? c.surfaceHighest : c.surfaceHigh, shape: BoxShape.circle),
        child: Icon(Icons.diamond_outlined, size: size * 0.5, color: c.text),
      );
    }
    return DhAvatar(asset: p.avatar, name: p.name, size: size, dark: participant.style == _AvatarStyle.dark);
  }
}

class _NetworkHub extends StatelessWidget {
  const _NetworkHub({required this.job});

  final Job job;

  void _showDetails(BuildContext context, _Participant part) {
    final p = part.partner;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.c;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ParticipantAvatar(participant: part, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: AppText.headlineSm),
                          const SizedBox(height: 2),
                          Text(
                            part.role.toUpperCase(),
                            style: AppText.labelSm.copyWith(color: part.active ? c.accent : c.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DhCard(
                  color: c.isDark ? c.surfaceLow : c.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  child: Column(
                    children: [
                      KeyValueRow('Company', p.company ?? '—', mono: false, divider: true),
                      KeyValueRow('Location', p.location ?? '—', mono: false, divider: true),
                      KeyValueRow('Phone', p.phone ?? 'Not shared', divider: true),
                      KeyValueRow('Active jobs', '${p.activeJobs}', divider: true),
                      KeyValueRow('Rating', '★ ${p.rating.toStringAsFixed(1)}'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        'Call',
                        icon: Icons.call_outlined,
                        onPressed: () {
                          Navigator.pop(ctx);
                          showSnack(
                            context,
                            p.phone == null
                                ? 'No phone number on file for ${p.name}'
                                : 'Calling ${p.name} · ${p.phone}',
                            icon: Icons.call_outlined,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        'Message',
                        icon: Icons.chat_bubble_outline,
                        onPressed: () {
                          Navigator.pop(ctx);
                          showSnack(context, 'Opening chat with ${p.name}', icon: Icons.chat_bubble_outline);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final people = _participants(job);
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Network Hub', style: AppText.headlineSm)),
              StatusChip('${people.length} Active', color: c.accent),
            ],
          ),
          const SizedBox(height: 10),
          for (final part in people)
            InkWell(
              onTap: () => _showDetails(context, part),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    _ParticipantAvatar(participant: part),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            part.partner.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.labelMd.copyWith(fontSize: 14, color: c.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            part.role.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.labelSm.copyWith(color: part.active ? c.accent : c.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: c.textFaint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilesPreview extends StatelessWidget {
  const _FilesPreview({required this.job, required this.onViewAll});

  final Job job;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final files = job.files;
    return DhCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            'Project Files',
            icon: Icons.folder_open_outlined,
            action: 'View All (${files.length})',
            onAction: onViewAll,
          ),
          const SizedBox(height: 10),
          if (files.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: UploadBox(
                title: 'Upload the first photo',
                subtitle: 'Bench photos, references or QC shots',
                height: 110,
                onTap: () => _uploadPhoto(context, job),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                primary: false,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 8),
                itemCount: files.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _openFile(context, files[i]),
                  child: SizedBox(
                    width: 110,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 110, height: 110, child: _FileThumb(file: files[i], iconSize: 36)),
                        const SizedBox(height: 6),
                        Text(
                          files[i].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.monoSm.copyWith(color: c.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _stageLinks = <(String, String, String, IconData)>[
  (Routes.cadReview, 'CAD Review', 'Design sign-off', Icons.view_in_ar),
  (Routes.pricing, 'Pricing Approval', 'Quote & margin', Icons.request_quote_outlined),
  (Routes.casting, 'Casting', 'Caster workspace', Icons.local_fire_department_outlined),
  (Routes.qc, 'Quality Control', 'Inspection', Icons.rule_outlined),
  (Routes.certification, 'Certification', 'Lab report', Icons.workspace_premium_outlined),
  (Routes.shipping, 'Shipping', 'Dispatch & courier', Icons.local_shipping_outlined),
  (Routes.tracker, 'Workflow Tracker', 'All stages', Icons.timeline),
  (Routes.orderDetails, 'Order Details', 'Specs & BOM', Icons.receipt_long_outlined),
];

class _StageScreens extends StatelessWidget {
  const _StageScreens({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final current = Routes.forStage(job.stage);
    final rows = <Widget>[];
    for (var i = 0; i < _stageLinks.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StageLinkTile(link: _stageLinks[i], job: job, current: _stageLinks[i].$1 == current),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StageLinkTile(link: _stageLinks[i + 1], job: job, current: _stageLinks[i + 1].$1 == current),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Stage Screens', icon: Icons.apps_outlined),
        const SizedBox(height: 4),
        Text(
          'Open any stage workspace for ${job.id}. The highlighted one matches the current stage.',
          style: AppText.bodySm.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 12),
        ...rows,
      ],
    );
  }
}

class _StageLinkTile extends StatelessWidget {
  const _StageLinkTile({required this.link, required this.job, required this.current});

  final (String, String, String, IconData) link;
  final Job job;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (route, title, subtitle, icon) = link;
    final accent = c.isDark ? c.gold : c.accent;
    return Material(
      color: current ? c.accentSoft : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: current ? accent : c.border, width: current ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route, arguments: job.id),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: current ? accent : c.textMuted),
                  const Spacer(),
                  if (current) StatusChip('Now', color: accent),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: AppText.titleMd.copyWith(fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                current ? 'Current stage' : subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodySm.copyWith(color: current ? accent : c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Thread --------------------------------------------------------------------

String _stamp(DateTime d) {
  final now = DateTime.now();
  final today = d.year == now.year && d.month == now.month && d.day == now.day;
  return today ? Fmt.time(d) : Fmt.relativeDay(d);
}

class _ThreadTab extends StatefulWidget {
  const _ThreadTab({required this.job});

  final Job job;

  @override
  State<_ThreadTab> createState() => _ThreadTabState();
}

class _ThreadTabState extends State<_ThreadTab> with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  int _count = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _count = widget.job.thread.length;
  }

  @override
  void didUpdateWidget(covariant _ThreadTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = widget.job.thread.length;
    if (n == _count) return;
    _count = n;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    app.postMessage(widget.job, text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.c;
    final msgs = widget.job.thread;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(Icons.forum_outlined, color: c.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text('Digital Thread', style: AppText.headlineSm)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.isDark ? c.surface : c.surfaceLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulseDot(color: c.isDark ? c.gold : c.accent),
                    const SizedBox(width: 6),
                    Text('Live', style: AppText.labelSm.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: c.border),
        Expanded(
          child: msgs.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.forum_outlined,
                    message: 'No updates yet. Post the first message for this job.',
                  ),
                )
              : ListView.separated(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: msgs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, i) => _MessageView(message: msgs[msgs.length - 1 - i]),
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            decoration: BoxDecoration(
              color: c.isDark ? c.surfaceLow : c.surface,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Attach photo',
                  icon: Icon(Icons.attach_file, color: c.textMuted),
                  onPressed: () => _uploadPhoto(context, widget.job),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: AppText.bodyMd.copyWith(color: c.text),
                    decoration: InputDecoration(
                      hintText: 'Type a message or update...',
                      fillColor: c.isDark ? c.surface : c.surfaceLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: c.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send',
                  onPressed: _send,
                  style: IconButton.styleFrom(backgroundColor: c.action, foregroundColor: c.onAction),
                  icon: const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message});

  final ThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    if (m.kind != MessageKind.message) return _EventCard(message: m);
    return m.isMe ? _OwnBubble(message: m) : _OtherBubble(message: m);
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.message});

  final ThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = message;
    final isStage = m.kind == MessageKind.stage;
    final icon = switch (m.kind) {
      MessageKind.file => Icons.upload_file,
      MessageKind.stage => Icons.play_arrow_rounded,
      _ => Icons.info_outline,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: isStage ? c.accentSoft : (c.isDark ? c.surfaceHigh : c.surfaceLow),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: isStage ? c.accent : c.text),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title ?? m.author, style: AppText.labelMd.copyWith(fontSize: 13, color: c.text)),
                const SizedBox(height: 4),
                Text(m.text, style: AppText.bodySm.copyWith(color: c.textMuted)),
                const SizedBox(height: 8),
                Text(Fmt.relativeDay(m.time), style: AppText.monoSm.copyWith(color: c.textFaint)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OtherBubble extends StatelessWidget {
  const _OtherBubble({required this.message});

  final ThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = message;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DhAvatar(asset: m.avatar, name: m.author, size: 32),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.author, style: AppText.labelSm.copyWith(color: c.textMuted)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surfaceHigh,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(m.text, style: AppText.bodyMd.copyWith(color: c.text)),
              ),
              const SizedBox(height: 4),
              Text(_stamp(m.time), style: AppText.monoSm.copyWith(color: c.textFaint)),
            ],
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}

class _OwnBubble extends StatelessWidget {
  const _OwnBubble({required this.message});

  final ThreadMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = message;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('You', style: AppText.labelSm.copyWith(color: c.textMuted)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.action,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Text(m.text, style: AppText.bodyMd.copyWith(color: c.onAction)),
              ),
              const SizedBox(height: 4),
              Text(_stamp(m.time), style: AppText.monoSm.copyWith(color: c.textFaint)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---- Files ---------------------------------------------------------------------

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final files = job.files;
    return LayoutBuilder(
      builder: (context, box) {
        final tile = (box.maxWidth - 32 - 12) / 2;
        return CustomScrollView(
          primary: false,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Icon(Icons.folder_open_outlined, color: c.text),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Project Files (${files.length})', style: AppText.headlineSm)),
                    FilledButton.icon(
                      onPressed: () => _uploadPhoto(context, job),
                      icon: const Icon(Icons.upload, size: 18),
                      label: const Text('Upload'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: AppText.labelMd.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (files.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.folder_off_outlined,
                  message: 'No files yet. Upload bench photos, references or QC shots.',
                  action: OutlinedButton.icon(
                    onPressed: () => _uploadPhoto(context, job),
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: const Text('Upload Photo'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    mainAxisExtent: tile + 64,
                  ),
                  itemCount: files.length,
                  itemBuilder: (context, i) {
                    final f = files[i];
                    return InkWell(
                      onTap: () => _openFile(context, f),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: tile,
                            height: tile,
                            child: _FileThumb(file: f, iconSize: 48),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            f.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.monoMd.copyWith(color: c.text),
                          ),
                          Text(
                            '${f.sizeLabel} · ${f.uploadedBy}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.monoSm.copyWith(color: c.textFaint),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

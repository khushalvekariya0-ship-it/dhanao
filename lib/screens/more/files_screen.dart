import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

const _kindFilters = <(String, FileKind?)>[
  ('All', null),
  ('Images', FileKind.image),
  ('CAD', FileKind.cad),
  ('PDF', FileKind.pdf),
  ('Sheets', FileKind.sheet),
];

bool _viewable(ProjectFile f) => f.asset != null || f.localPath != null;

/// Files — every project file across all jobs.
class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final _search = TextEditingController();
  String _query = '';
  FileKind? _kind;
  bool _grid = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ProjectFile> get _visible {
    final q = _query.trim().toLowerCase();
    return app.allFiles.where((f) {
      if (_kind != null && f.kind != _kind) return false;
      if (q.isEmpty) return true;
      return f.name.toLowerCase().contains(q) ||
          (f.jobId ?? '').toLowerCase().contains(q) ||
          f.uploadedBy.toLowerCase().contains(q);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  void _open(ProjectFile f) {
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
                        f.jobId == null ? f.name : '${f.name} · ${f.jobId}',
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

  void _openJob(String id) => Navigator.pushNamed(context, Routes.job, arguments: id);

  Future<void> _upload() async {
    final job = await showModalBottomSheet<Job>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, scroll) {
          final c = ctx.c;
          final jobs = app.activeJobs..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Upload to which job?', style: AppText.headlineSm),
              const SizedBox(height: 4),
              Text(
                'The photo is added to the job files and its digital thread.',
                style: AppText.bodySm.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 8),
              for (final j in jobs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: DhImage(asset: j.image, width: 44, height: 44, radius: 6),
                  title: Text(j.id, style: AppText.monoLg.copyWith(color: c.text)),
                  subtitle: Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: StageChip(j.stage),
                  onTap: () => Navigator.pop(ctx, j),
                ),
            ],
          );
        },
      ),
    );
    if (job == null || !mounted) return;
    final path = await pickImage(context, title: 'Upload to ${job.id}');
    if (path == null || !mounted) return;
    final name = path.split(RegExp(r'[\\/]')).last;
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
    showSnack(context, '$name uploaded to ${job.id}', icon: Icons.cloud_done_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final all = app.allFiles;
        final files = _visible;
        final jobCount = {for (final f in all) f.jobId}.length;
        return DetailScaffold(
          title: 'Files',
          subtitle: '${all.length} FILES · $jobCount JOBS',
          actions: [
            IconButton(
              tooltip: _grid ? 'List view' : 'Grid view',
              icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view_outlined),
              onPressed: () => setState(() => _grid = !_grid),
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'files-upload',
            onPressed: _upload,
            icon: const Icon(Icons.upload),
            label: const Text('Upload'),
          ),
          body: LayoutBuilder(
            builder: (context, box) {
              final tile = (box.maxWidth - 32 - 12) / 2;
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        style: AppText.bodyMd.copyWith(color: c.text),
                        decoration: InputDecoration(
                          hintText: 'Search file name, job ID or uploader',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          for (final (label, kind) in _kindFilters) ...[
                            _FilterPill(
                              label: label,
                              count: kind == null ? all.length : all.where((f) => f.kind == kind).length,
                              selected: _kind == kind,
                              onTap: () => setState(() => _kind = kind),
                            ),
                            if (label != _kindFilters.last.$1) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (files.isEmpty)
                    SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.folder_off_outlined,
                        message: all.isEmpty ? 'No project files yet.' : 'No files match this filter.',
                        action: OutlinedButton.icon(
                          onPressed: _upload,
                          icon: const Icon(Icons.upload, size: 18),
                          label: const Text('Upload a photo'),
                        ),
                      ),
                    )
                  else if (_grid)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverGrid.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          mainAxisExtent: tile + 64,
                        ),
                        itemCount: files.length,
                        itemBuilder: (context, i) =>
                            _FileTile(file: files[i], size: tile, onTap: () => _open(files[i]), onJob: _openJob),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverList.separated(
                        itemCount: files.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) =>
                            _FileRow(file: files[i], onTap: () => _open(files[i]), onJob: _openJob),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.file, required this.size, this.iconSize = 26});

  final ProjectFile file;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_viewable(file)) {
      return DhImage(asset: file.asset, file: file.localPath, width: size, height: size);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.isDark ? c.surfaceHigh : c.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Icon(file.icon, size: iconSize, color: c.textMuted),
    );
  }
}

class _JobLink extends StatelessWidget {
  const _JobLink({required this.jobId, required this.onTap});

  final String jobId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: () => onTap(jobId),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          jobId,
          style: AppText.monoSm.copyWith(
            color: c.accent,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            decorationColor: c.accent.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onTap, required this.onJob});

  final ProjectFile file;
  final VoidCallback onTap;
  final ValueChanged<String> onJob;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = file;
    return DhCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _Thumb(file: f, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.monoMd.copyWith(color: c.text, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (f.jobId != null) ...[
                      _JobLink(jobId: f.jobId!, onTap: onJob),
                      Text(' · ', style: AppText.bodySm.copyWith(color: c.textFaint)),
                    ],
                    Expanded(
                      child: Text(
                        f.uploadedBy,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodySm.copyWith(color: c.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${Fmt.dateLong(f.date)} · ${f.sizeLabel}', style: AppText.monoSm.copyWith(color: c.textFaint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(_viewable(f) ? Icons.open_in_full : Icons.open_in_new, size: 18, color: c.textFaint),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.size, required this.onTap, required this.onJob});

  final ProjectFile file;
  final double size;
  final VoidCallback onTap;
  final ValueChanged<String> onJob;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final f = file;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumb(file: f, size: size, iconSize: 48),
          const SizedBox(height: 8),
          Text(
            f.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.monoMd.copyWith(color: c.text),
          ),
          Row(
            children: [
              if (f.jobId != null) _JobLink(jobId: f.jobId!, onTap: onJob),
              Expanded(
                child: Text(
                  ' · ${f.sizeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.monoSm.copyWith(color: c.textFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap, this.count});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = selected ? (c.isDark ? c.gold : c.navActive) : c.surface;
    final fg = selected ? (c.isDark ? c.onAction : c.onNavActive) : c.text;
    return Material(
      color: bg,
      shape: StadiumBorder(side: BorderSide(color: selected ? bg : c.border)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: AppText.labelMd.copyWith(fontSize: 13, color: fg)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text('$count', style: AppText.monoSm.copyWith(color: fg.withValues(alpha: 0.7))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

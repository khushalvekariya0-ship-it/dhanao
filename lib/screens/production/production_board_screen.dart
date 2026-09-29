import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Production Floor kanban — body of the FLOW tab. Long-press a card and
/// drag it onto another column to move the job to that stage.
class ProductionBoardScreen extends StatefulWidget {
  const ProductionBoardScreen({super.key});

  @override
  State<ProductionBoardScreen> createState() => _ProductionBoardScreenState();
}

class _ProductionBoardScreenState extends State<ProductionBoardScreen> {
  static const _anyCustomer = 'All';

  final _hScroll = ScrollController();
  Timer? _edgeTimer;
  double _edgeDir = 0;

  Set<Priority> _priorities = {};
  bool _atRiskOnly = false;
  String _customer = _anyCustomer;
  final Set<BoardColumn> _collapsed = {};

  int get _filterCount => (_priorities.isEmpty ? 0 : 1) + (_atRiskOnly ? 1 : 0) + (_customer == _anyCustomer ? 0 : 1);

  bool _matches(Job j) {
    if (_priorities.isNotEmpty && !_priorities.contains(j.priority)) return false;
    if (_atRiskOnly && !(j.atRisk || j.isOverdue)) return false;
    if (_customer != _anyCustomer && j.customer != _customer) return false;
    return true;
  }

  List<Job> _jobsIn(BoardColumn col) =>
      app.jobsInColumn(col).where(_matches).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  @override
  void dispose() {
    _edgeTimer?.cancel();
    _hScroll.dispose();
    super.dispose();
  }

  /// Scrolls the board sideways while a dragged card hovers near a screen edge.
  void _onDragUpdate(DragUpdateDetails d) {
    const edge = 56.0;
    final width = MediaQuery.sizeOf(context).width;
    final x = d.globalPosition.dx;
    final dir = x < edge ? -1.0 : (x > width - edge ? 1.0 : 0.0);
    if (dir == _edgeDir) return;
    _stopEdgeScroll();
    _edgeDir = dir;
    if (dir == 0) return;
    _edgeTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_hScroll.hasClients) return;
      final p = _hScroll.position;
      final next = (p.pixels + _edgeDir * 10).clamp(p.minScrollExtent, p.maxScrollExtent).toDouble();
      if (next != p.pixels) _hScroll.jumpTo(next);
    });
  }

  void _stopEdgeScroll() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    _edgeDir = 0;
  }

  void _drop(Job job, BoardColumn col) {
    _stopEdgeScroll();
    app.moveToColumn(job, col);
    showSnack(context, '${job.id} moved to ${col.label}', icon: Icons.swap_horiz);
  }

  void _openFilter() {
    final customers = {for (final j in app.jobs) j.customer}.toList()..sort();
    showDhSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
          }

          final shown = app.jobs.where(_matches).length;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Filter Board', style: AppText.headlineSm)),
                        TextButton(
                          onPressed: () => update(() {
                            _priorities = {};
                            _atRiskOnly = false;
                            _customer = _anyCustomer;
                          }),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Field(
                      label: 'Priority',
                      hint: 'Leave empty to show every priority.',
                      child: MultiChoiceGroup<Priority>(
                        options: Priority.values,
                        selected: _priorities,
                        labelOf: (p) => p.label,
                        dense: true,
                        onChanged: (s) => update(() => _priorities = s),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ToggleRow(
                      icon: Icons.warning_amber_rounded,
                      title: 'At risk only',
                      subtitle: 'Flagged or overdue jobs',
                      value: _atRiskOnly,
                      onChanged: (v) => update(() => _atRiskOnly = v),
                    ),
                    const SizedBox(height: 12),
                    Field(
                      label: 'Customer',
                      child: ChoiceGroup<String>(
                        options: [_anyCustomer, ...customers],
                        selected: _customer,
                        dense: true,
                        onChanged: (v) => update(() => _customer = v),
                      ),
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton('Show $shown jobs', onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BoardHeader(
            active: app.activeJobs.length,
            atRisk: app.atRiskJobs.length,
            filterCount: _filterCount,
            onFilter: _openFilter,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                final colWidth = math.min(box.maxWidth * 0.85, 320.0);
                return ListView(
                  controller: _hScroll,
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  children: [
                    for (final col in BoardColumn.values)
                      _KanbanColumn(
                        column: col,
                        jobs: _jobsIn(col),
                        width: colWidth,
                        collapsed: _collapsed.contains(col),
                        onToggleCollapse: () => setState(() {
                          if (!_collapsed.remove(col)) _collapsed.add(col);
                        }),
                        onDrop: (job) => _drop(job, col),
                        onDragUpdate: _onDragUpdate,
                        onDragEnd: _stopEdgeScroll,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color _columnColor(DhColors c, BoardColumn col) => switch (col) {
  BoardColumn.approved => c.gold,
  BoardColumn.wax => c.accent,
  BoardColumn.casting => c.warning,
  BoardColumn.assembly => c.info,
  BoardColumn.setting => c.success,
  BoardColumn.finishing => JobStage.qc.color,
  BoardColumn.dispatch => c.textFaint,
};

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.active, required this.atRisk, required this.filterCount, required this.onFilter});

  final int active;
  final int atRisk;
  final int filterCount;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('METRICS:', style: AppText.labelSm.copyWith(color: c.textMuted, letterSpacing: 1.2)),
              _MetricPill(dot: c.accent, label: '$active Active'),
              _MetricPill(dot: c.danger, label: '$atRisk At Risk'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Long-press a card to drag it to another stage.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodySm.copyWith(color: c.textFaint),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: c.isDark ? c.surface : c.surfaceLow,
                shape: StadiumBorder(side: BorderSide(color: filterCount > 0 ? c.accent : c.border)),
                child: InkWell(
                  onTap: onFilter,
                  customBorder: const StadiumBorder(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_list, size: 18, color: filterCount > 0 ? c.accent : c.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          filterCount > 0 ? 'Filter · $filterCount' : 'Filter',
                          style: AppText.labelMd.copyWith(fontSize: 13, color: c.text),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, Routes.newJob),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  shape: const StadiumBorder(),
                  textStyle: AppText.labelMd.copyWith(fontSize: 13),
                ),
                child: const Text('New Job'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.dot, required this.label});

  final Color dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.isDark ? c.surface : c.surfaceLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.labelMd.copyWith(color: c.text)),
        ],
      ),
    );
  }
}

enum _ColumnAction { openFirst, collapse, newJob }

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.column,
    required this.jobs,
    required this.width,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onDrop,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final BoardColumn column;
  final List<Job> jobs;
  final double width;
  final bool collapsed;
  final VoidCallback onToggleCollapse;
  final ValueChanged<Job> onDrop;
  final DragUpdateCallback onDragUpdate;
  final VoidCallback onDragEnd;

  void _onMenu(BuildContext context, _ColumnAction a) {
    switch (a) {
      case _ColumnAction.openFirst:
        if (jobs.isNotEmpty) Navigator.pushNamed(context, Routes.job, arguments: jobs.first.id);
      case _ColumnAction.collapse:
        onToggleCollapse();
      case _ColumnAction.newJob:
        Navigator.pushNamed(context, Routes.newJob);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DragTarget<Job>(
      onWillAcceptWithDetails: (d) => !column.stages.contains(d.data.stage),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, rejected) {
        final hover = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: hover ? c.accentSoft : c.surfaceLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: hover ? c.accent : c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, c),
              Divider(height: 1, color: c.border),
              Expanded(child: _body(context, c, hover)),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, DhColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: _columnColor(c, column), shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(column.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.isDark ? c.surfaceHighest : c.surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${jobs.length}', style: AppText.labelMd.copyWith(color: c.textMuted)),
                ),
              ],
            ),
          ),
          PopupMenuButton<_ColumnAction>(
            tooltip: '${column.label} options',
            icon: Icon(Icons.more_horiz, color: c.textMuted),
            onSelected: (a) => _onMenu(context, a),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ColumnAction.openFirst,
                enabled: jobs.isNotEmpty,
                child: const Text('Open first job'),
              ),
              PopupMenuItem(value: _ColumnAction.collapse, child: Text(collapsed ? 'Expand cards' : 'Collapse cards')),
              const PopupMenuItem(value: _ColumnAction.newJob, child: Text('Start a new job')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, DhColors c, bool hover) {
    if (jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.list_alt_outlined, size: 32, color: c.textFaint.withValues(alpha: hover ? 0.9 : 0.4)),
              const SizedBox(height: 8),
              Text(
                hover ? 'Release to move here' : 'Drop jobs here',
                style: AppText.bodySm.copyWith(color: c.textFaint.withValues(alpha: hover ? 1 : 0.7)),
              ),
            ],
          ),
        ),
      );
    }
    if (collapsed) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TextButton.icon(
            onPressed: onToggleCollapse,
            icon: const Icon(Icons.unfold_more, size: 18),
            label: Text('${jobs.length} job${jobs.length == 1 ? '' : 's'} hidden · Expand'),
          ),
        ),
      );
    }
    final cardWidth = width - 22;
    return ListView.separated(
      primary: false,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 96),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final job = jobs[i];
        final card = JobCard(
          job: job,
          compact: true,
          showStage: false,
          onTap: () => Navigator.pushNamed(context, Routes.job, arguments: job.id),
        );
        return LongPressDraggable<Job>(
          data: job,
          onDragUpdate: onDragUpdate,
          onDragEnd: (_) => onDragEnd(),
          feedback: _DragFeedback(
            width: cardWidth,
            child: JobCard(job: job, compact: true, showStage: false),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: card,
        );
      },
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Transform.rotate(
      angle: 0.03,
      child: Container(
        width: width,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.accent, width: 1.5),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.isDark ? 0.5 : 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Quick filters on the Orders tab.
enum JobsFilter {
  all('All'),
  active('Active'),
  atRisk('At Risk'),
  dueSoon('Due Soon'),
  completed('Completed');

  const JobsFilter(this.label);

  final String label;

  bool matches(Job j) => switch (this) {
    JobsFilter.all => true,
    JobsFilter.active => !j.isComplete,
    JobsFilter.atRisk => !j.isComplete && (j.atRisk || j.isOverdue),
    JobsFilter.dueSoon => !j.isComplete && j.daysUntilDue <= 3,
    JobsFilter.completed => j.isComplete,
  };
}

/// Selected Orders filter. Other tabs can open Orders pre-filtered:
/// `jobsFilter.value = JobsFilter.atRisk; homeTab.value = HomeTabs.orders;`
final ValueNotifier<JobsFilter> jobsFilter = ValueNotifier(JobsFilter.all);

enum _Sort {
  due('Due date', Icons.event_outlined),
  value('Value', Icons.payments_outlined),
  stage('Stage', Icons.account_tree_outlined);

  const _Sort(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Orders — the ORDERS tab body: searchable, filterable list of all jobs.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Sort _sort = _Sort.due;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesQuery(Job j) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return j.id.toLowerCase().contains(q) ||
        j.title.toLowerCase().contains(q) ||
        j.customer.toLowerCase().contains(q) ||
        j.stage.label.toLowerCase().contains(q) ||
        (j.assignee ?? '').toLowerCase().contains(q);
  }

  List<Job> _visible(JobsFilter filter) {
    final list = app.jobs.where((j) => filter.matches(j) && _matchesQuery(j)).toList();
    switch (_sort) {
      case _Sort.due:
        list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      case _Sort.value:
        list.sort((a, b) => b.value.compareTo(a.value));
      case _Sort.stage:
        list.sort((a, b) {
          final s = a.stage.index.compareTo(b.stage.index);
          return s != 0 ? s : a.dueDate.compareTo(b.dueDate);
        });
    }
    return list;
  }

  void _clear() {
    _search.clear();
    setState(() => _query = '');
    jobsFilter.value = JobsFilter.all;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: Listenable.merge([app, jobsFilter]),
      builder: (context, _) {
        final filter = jobsFilter.value;
        final jobs = _visible(filter);
        return CustomScrollView(
          primary: false,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Job Orders', style: AppText.headlineLg),
                              const SizedBox(height: 2),
                              Text(
                                '${jobs.length} of ${app.jobs.length} jobs',
                                style: AppText.monoMd.copyWith(color: c.textMuted),
                              ),
                            ],
                          ),
                        ),
                        _SortButton(sort: _sort, onChanged: (s) => setState(() => _sort = s)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      textInputAction: TextInputAction.search,
                      style: AppText.bodyMd.copyWith(color: c.text),
                      decoration: InputDecoration(
                        hintText: 'Job ID, customer, stage or specialist',
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
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    for (final f in JobsFilter.values) ...[
                      _FilterPill(
                        label: f.label,
                        count: app.jobs.where(f.matches).length,
                        selected: f == filter,
                        onTap: () => jobsFilter.value = f,
                      ),
                      if (f != JobsFilter.values.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            if (jobs.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.search_off,
                  message: 'No jobs match these filters.',
                  action: OutlinedButton.icon(
                    onPressed: _clear,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Clear filters'),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.separated(
                  itemCount: jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => JobCard(
                    job: jobs[i],
                    onTap: () => Navigator.pushNamed(context, Routes.job, arguments: jobs[i].id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onChanged});

  final _Sort sort;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return PopupMenuButton<_Sort>(
      tooltip: 'Sort jobs',
      initialValue: sort,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final s in _Sort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(s.icon, size: 18, color: s == sort ? c.accent : c.textMuted),
                const SizedBox(width: 10),
                Text(s.label, style: AppText.bodyMd.copyWith(color: s == sort ? c.accent : c.text)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.isDark ? c.surface : c.surfaceLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 18, color: c.textMuted),
            const SizedBox(width: 6),
            Text(sort.label, style: AppText.labelMd.copyWith(color: c.text)),
          ],
        ),
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

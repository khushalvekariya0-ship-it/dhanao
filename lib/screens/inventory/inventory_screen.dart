import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

enum _Segment { all, metals, gems }

enum _GemStatus { all, available, assigned }

/// Inventory — body of the STOCK tab: metal stock (grams) and gemstones.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _search = TextEditingController();
  String _query = '';
  _Segment _segment = _Segment.all;
  _GemStatus _gemStatus = _GemStatus.all;
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _filtersActive => _gemStatus != _GemStatus.all || _lowStockOnly;

  bool _has(String s) => s.toLowerCase().contains(_query.trim().toLowerCase());

  List<MetalStock> get _metals => app.metals.where((m) {
    if (_lowStockOnly && m.grams / m.capacityGrams >= 0.5) return false;
    return _has(m.code) || _has(m.name);
  }).toList();

  List<GemStock> get _gems => app.gems.where((g) {
    if (_gemStatus == _GemStatus.available && g.assignedJobId != null) return false;
    if (_gemStatus == _GemStatus.assigned && g.assignedJobId == null) return false;
    return _has(g.id) ||
        _has(g.name) ||
        _has(g.tag) ||
        _has(g.location) ||
        g.specs.values.any(_has) ||
        (g.assignedJobId != null && _has(g.assignedJobId!));
  }).toList();

  // ---- Metals ---------------------------------------------------------------

  Future<void> _adjustMetal(MetalStock m) async {
    final result = await showDialog<_Adjustment>(
      context: context,
      builder: (_) => _AdjustDialog(metal: m),
    );
    if (result == null || !mounted) return;
    setState(() => m.grams = (m.grams + result.delta).clamp(0, double.infinity).toDouble());
    final job = result.jobId == null ? null : app.jobById(result.jobId!);
    if (job != null) {
      app.addEvent(
        job,
        title: 'Metal issued',
        text: '${Fmt.grams(-result.delta)} of ${m.name} (${m.code}) issued from stock.',
      );
    }
    final verb = result.delta >= 0 ? 'Received' : 'Issued';
    showSnack(
      context,
      '$verb ${Fmt.grams(result.delta.abs())} ${m.code}${job != null ? ' → ${job.id}' : ''} · '
      'Balance ${Fmt.grams(m.grams)}',
      icon: Icons.scale_outlined,
    );
  }

  // ---- Gems -----------------------------------------------------------------

  void _assignGem(GemStock gem) {
    showDhSheet<void>(
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
              Text('Assign ${gem.id}', style: AppText.headlineSm),
              const SizedBox(height: 4),
              Text('${gem.name} · ${gem.location}', style: AppText.bodySm.copyWith(color: c.textMuted)),
              const SizedBox(height: 12),
              const SectionLabel('Active jobs'),
              const SizedBox(height: 4),
              for (final j in jobs)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: DhImage(asset: j.image, width: 44, height: 44, radius: 6),
                  title: Text(j.id, style: AppText.monoLg.copyWith(color: c.text)),
                  subtitle: Text('${j.title} · ${j.customer}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: StageChip(j.stage),
                  onTap: () {
                    Navigator.pop(ctx);
                    app.assignGem(gem, j.id);
                    app.addEvent(
                      j,
                      title: 'Stone allocated',
                      text: '${gem.name} (${gem.id}) reserved from ${gem.location}.',
                    );
                    showSnack(context, '${gem.id} assigned to ${j.id}', icon: Icons.link);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  void _unassignGem(GemStock gem) {
    final jobId = gem.assignedJobId;
    app.assignGem(gem, null);
    showSnack(
      context,
      '${gem.id} released${jobId != null ? ' from $jobId' : ''} · back in ${gem.location}',
      icon: Icons.link_off,
    );
  }

  // ---- Filter ---------------------------------------------------------------

  void _openFilter() {
    showDhSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void update(VoidCallback fn) {
            setState(fn);
            setSheet(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Filter Stock', style: AppText.headlineSm)),
                      TextButton(
                        onPressed: () => update(() {
                          _gemStatus = _GemStatus.all;
                          _lowStockOnly = false;
                        }),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Field(
                    label: 'Gemstone status',
                    child: ChoiceGroup<_GemStatus>(
                      options: _GemStatus.values,
                      selected: _gemStatus,
                      columns: 3,
                      dense: true,
                      labelOf: (s) => switch (s) {
                        _GemStatus.all => 'All',
                        _GemStatus.available => 'Available',
                        _GemStatus.assigned => 'Assigned',
                      },
                      onChanged: (s) => update(() => _gemStatus = s),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ToggleRow(
                    icon: Icons.trending_down,
                    title: 'Low metal stock only',
                    subtitle: 'Below 50% of vault capacity',
                    value: _lowStockOnly,
                    onChanged: (v) => update(() => _lowStockOnly = v),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton('Done', onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final showMetals = _segment != _Segment.gems;
        final showGems = _segment != _Segment.metals;
        final metals = showMetals ? _metals : <MetalStock>[];
        final gems = showGems ? _gems : <GemStock>[];
        return ListView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            DhSegmented<_Segment>(
              options: _Segment.values,
              selected: _segment,
              labelOf: (s) => switch (s) {
                _Segment.all => 'All',
                _Segment.metals => 'Metals',
                _Segment.gems => 'Gems',
              },
              onChanged: (s) => setState(() => _segment = s),
            ),
            const SizedBox(height: 12),
            _SearchBar(
              controller: _search,
              filtersActive: _filtersActive,
              onChanged: (v) => setState(() => _query = v),
              onClear: () {
                _search.clear();
                setState(() => _query = '');
              },
              onFilter: _openFilter,
            ),
            if (showMetals) ...[
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Raw Materials', caption: 'Metals (g)'),
              const SizedBox(height: 12),
              if (metals.isEmpty)
                Text('No metals match.', style: AppText.bodySm.copyWith(color: c.textFaint))
              else
                OptionLayout(
                  columns: 2,
                  spacing: 12,
                  children: [for (final m in metals) _MetalCard(metal: m, onTap: () => _adjustMetal(m))],
                ),
            ],
            if (showGems) ...[
              const SizedBox(height: 24),
              _SectionTitle(title: 'Gemstone Inventory', caption: 'Active Stock · ${gems.length}'),
              const SizedBox(height: 12),
              if (gems.isEmpty)
                const EmptyState(icon: Icons.diamond_outlined, message: 'No gemstones match your search or filter.')
              else
                for (final g in gems) ...[
                  _GemCard(
                    gem: g,
                    onAssign: () => _assignGem(g),
                    onUnassign: () => _unassignGem(g),
                    onOpenJob: () => Navigator.pushNamed(context, Routes.job, arguments: g.assignedJobId),
                  ),
                  if (g != gems.last) const SizedBox(height: 12),
                ],
            ],
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.filtersActive,
    required this.onChanged,
    required this.onClear,
    required this.onFilter,
  });

  final TextEditingController controller;
  final bool filtersActive;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppText.monoMd.copyWith(color: c.text),
              decoration: InputDecoration(
                hintText: 'Search inventory ID, type...',
                hintStyle: AppText.monoMd.copyWith(color: c.textFaint),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close, size: 18), onPressed: onClear),
                filled: false,
                border: UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.accent, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: filtersActive ? c.accent : (c.isDark ? c.surfaceHigh : c.surfaceLow),
            shape: CircleBorder(side: BorderSide(color: c.accent.withValues(alpha: 0.3))),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onFilter,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.filter_list, size: 20, color: filtersActive ? c.onAccent : c.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Expanded(child: Text(title, style: AppText.headlineSm)),
        const SizedBox(width: 8),
        Text(caption.toUpperCase(), style: AppText.monoCaps.copyWith(color: c.textMuted, letterSpacing: 1.6)),
      ],
    );
  }
}

class _MetalCard extends StatelessWidget {
  const _MetalCard({required this.metal, required this.onTap});

  final MetalStock metal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = metal;
    final ratio = m.capacityGrams <= 0 ? 0.0 : m.grams / m.capacityGrams;
    final low = ratio < 0.25;
    return DhCard(
      onTap: onTap,
      color: c.isDark ? c.surfaceHigh : c.surface,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(m.code, style: AppText.monoCaps.copyWith(color: c.isDark ? c.gold : c.accent)),
              ),
              Icon(Icons.tune, size: 16, color: c.textFaint),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: m.color,
                  shape: BoxShape.circle,
                  boxShadow: c.isDark ? [BoxShadow(color: m.color.withValues(alpha: 0.5), blurRadius: 8)] : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMd.copyWith(color: c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(Fmt.grams(m.grams).replaceAll(' g', ''), style: AppText.headlineMd),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text('g', style: AppText.monoCaps.copyWith(color: c.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ThinProgress(value: ratio, color: low ? c.danger : m.color),
          const SizedBox(height: 6),
          Text(
            low
                ? 'LOW · ${(ratio * 100).round()}% of ${Fmt.grams(m.capacityGrams, digits: 0)}'
                : '${(ratio * 100).round()}% of ${Fmt.grams(m.capacityGrams, digits: 0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.monoSm.copyWith(color: low ? c.danger : c.textFaint),
          ),
        ],
      ),
    );
  }
}

class _GemCard extends StatelessWidget {
  const _GemCard({required this.gem, required this.onAssign, required this.onUnassign, required this.onOpenJob});

  final GemStock gem;
  final VoidCallback onAssign;
  final VoidCallback onUnassign;
  final VoidCallback onOpenJob;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final assigned = gem.assignedJobId;
    final certified = gem.tag.toLowerCase().contains('cert');
    return DhCard(
      padding: EdgeInsets.zero,
      color: c.isDark ? c.surfaceLow : c.surface,
      borderColor: assigned != null ? c.accent.withValues(alpha: 0.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DhImage(asset: gem.image, width: 76, height: 76, placeholderIcon: Icons.diamond_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  gem.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.titleMd,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusChip(gem.tag, color: certified ? c.success : c.textMuted),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('ID: ${gem.id}', style: AppText.monoSm.copyWith(color: c.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final e in gem.specs.entries.take(3))
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.key, style: AppText.monoCaps.copyWith(fontSize: 10, color: c.textFaint)),
                            const SizedBox(height: 2),
                            Text(
                              e.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.monoLg.copyWith(color: c.text),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: c.isDark ? c.surface : c.surfaceLow,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Loc: ${gem.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.monoMd.copyWith(color: c.textMuted),
                      ),
                      if (assigned != null)
                        InkWell(
                          onTap: onOpenJob,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Assigned → $assigned',
                              style: AppText.monoMd.copyWith(color: c.accent, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (assigned == null)
                  FilledButton.icon(
                    onPressed: onAssign,
                    icon: const Icon(Icons.add_link, size: 18),
                    label: const Text('ASSIGN'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      textStyle: AppText.monoCaps.copyWith(fontSize: 12),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onUnassign,
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('Unassign'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      textStyle: AppText.labelMd.copyWith(fontSize: 13),
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

/// Result of the adjust-stock dialog: signed grams and optional job issued to.
class _Adjustment {
  const _Adjustment(this.delta, this.jobId);

  final double delta;
  final String? jobId;
}

class _AdjustDialog extends StatefulWidget {
  const _AdjustDialog({required this.metal});

  final MetalStock metal;

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  final _amount = TextEditingController(text: '10');
  bool _receive = true;
  String? _jobId;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text.trim()) ?? 0;

  void _bump(double by) {
    final next = (_value + by).clamp(0, 100000).toDouble();
    _amount.text = next == next.roundToDouble() ? next.toStringAsFixed(0) : next.toStringAsFixed(1);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = widget.metal;
    final amount = _value;
    final after = _receive ? m.grams + amount : m.grams - amount;
    final valid = amount > 0 && after >= 0;
    return AlertDialog(
      title: Text('Adjust ${m.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(m.code, style: AppText.monoLg.copyWith(color: c.isDark ? c.gold : c.accent)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'On hand ${Fmt.grams(m.grams)}',
                    textAlign: TextAlign.right,
                    style: AppText.monoMd.copyWith(color: c.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DhSegmented<bool>(
              options: const [true, false],
              selected: _receive,
              labelOf: (r) => r ? 'Receive' : 'Issue',
              onChanged: (r) => setState(() => _receive = r),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppText.monoLg.copyWith(color: c.text),
              decoration: const InputDecoration(labelText: 'Grams', suffixText: 'g'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final step in const [-10.0, -1.0, 1.0, 10.0]) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _bump(step),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: EdgeInsets.zero,
                        textStyle: AppText.monoMd,
                      ),
                      child: Text(step > 0 ? '+${step.toInt()}' : '${step.toInt()}'),
                    ),
                  ),
                  if (step != 10) const SizedBox(width: 6),
                ],
              ],
            ),
            if (!_receive) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: _jobId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Issue to job (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('General use — no job')),
                  for (final j in app.activeJobs)
                    DropdownMenuItem<String?>(
                      value: j.id,
                      child: Text('${j.id} · ${j.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _jobId = v),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              after < 0 ? 'Not enough stock to issue ${Fmt.grams(amount)}' : 'New balance: ${Fmt.grams(after)}',
              style: AppText.monoMd.copyWith(color: after < 0 ? c.danger : c.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textMuted)),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, _Adjustment(_receive ? amount : -amount, _receive ? null : _jobId))
              : null,
          child: Text(_receive ? 'Receive' : 'Issue'),
        ),
      ],
    );
  }
}

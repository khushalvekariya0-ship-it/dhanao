import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

const _roleFilters = ['All', 'Design', 'Casting', 'Stones', 'Retail', 'Lab/QC', 'Logistics'];

String _category(String role) {
  final r = role.toLowerCase();
  if (r.contains('design')) return 'Design';
  if (r.contains('lab') || r.contains('qc')) return 'Lab/QC';
  if (r.contains('cast') || r.contains('setter')) return 'Casting';
  if (r.contains('stone')) return 'Stones';
  if (r.contains('retail')) return 'Retail';
  if (r.contains('courier') || r.contains('logistic')) return 'Logistics';
  return 'Other';
}

List<Job> _linkedJobs(Partner p) =>
    app.jobs.where((j) => !j.isComplete && (j.assignee == p.name || j.customer == p.name)).toList();

/// Partners — the network hub of designers, casters, suppliers and retailers.
class PartnersScreen extends StatefulWidget {
  const PartnersScreen({super.key});

  @override
  State<PartnersScreen> createState() => _PartnersScreenState();
}

class _PartnersScreenState extends State<PartnersScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _role = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Partner> get _visible {
    final q = _query.trim().toLowerCase();
    return app.partners.where((p) {
      if (_role != 'All' && _category(p.role) != _role) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.role.toLowerCase().contains(q) ||
          (p.company ?? '').toLowerCase().contains(q) ||
          (p.location ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DetailScaffold(
      title: 'Partners',
      subtitle: 'NETWORK HUB · ${app.partners.length} PARTNERS',
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final list = _visible;
          final totalJobs = app.partners.fold<int>(0, (s, p) => s + p.activeJobs);
          final avg = app.partners.isEmpty
              ? 0.0
              : app.partners.fold<double>(0, (s, p) => s + p.rating) / app.partners.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Stat(label: 'Partners', value: '${app.partners.length}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(label: 'Active jobs', value: '$totalJobs'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(label: 'Avg rating', value: avg.toStringAsFixed(1)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: AppText.bodyMd.copyWith(color: c.text),
                decoration: InputDecoration(
                  hintText: 'Search name, company or location',
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
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final r in _roleFilters) ...[
                      _FilterPill(
                        label: r,
                        count: r == 'All'
                            ? app.partners.length
                            : app.partners.where((p) => _category(p.role) == r).length,
                        selected: r == _role,
                        onTap: () => setState(() => _role = r),
                      ),
                      if (r != _roleFilters.last) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                EmptyState(
                  icon: Icons.hub_outlined,
                  message: 'No partners match your search.',
                  action: OutlinedButton(
                    onPressed: () {
                      _search.clear();
                      setState(() {
                        _query = '';
                        _role = 'All';
                      });
                    },
                    child: const Text('Clear filters'),
                  ),
                ),
              for (final p in list) ...[
                _PartnerCard(partner: p, onTap: () => _showPartner(context, p)),
                if (p != list.last) const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

void _showPartner(BuildContext context, Partner p) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scroll) {
        final c = ctx.c;
        final jobs = _linkedJobs(p);
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(
              children: [
                _PartnerAvatar(partner: p, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: AppText.headlineSm),
                      const SizedBox(height: 2),
                      Text(p.role.toUpperCase(), style: AppText.labelSm.copyWith(color: c.accent)),
                      if (p.company != null) ...[
                        const SizedBox(height: 2),
                        Text(p.company!, style: AppText.bodySm.copyWith(color: c.textMuted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(label: 'Active jobs', value: '${p.activeJobs}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(label: 'Rating', value: p.rating.toStringAsFixed(1)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(label: 'In DhanaOS', value: '${jobs.length}'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionLabel('Contact'),
            const SizedBox(height: 8),
            DhCard(
              color: c.isDark ? c.surfaceLow : c.surface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  _ContactRow(icon: Icons.call_outlined, label: 'Phone', value: p.phone ?? 'Not shared', mono: true),
                  Divider(height: 1, color: c.border),
                  _ContactRow(icon: Icons.business_outlined, label: 'Company', value: p.company ?? '—'),
                  Divider(height: 1, color: c.border),
                  _ContactRow(icon: Icons.place_outlined, label: 'Location', value: p.location ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionLabel('Active Jobs (${jobs.length})'),
            const SizedBox(height: 8),
            if (jobs.isEmpty)
              Text('No active jobs linked to ${p.name} yet.', style: AppText.bodySm.copyWith(color: c.textFaint)),
            for (final j in jobs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DhCard(
                  color: c.isDark ? c.surfaceLow : c.surface,
                  padding: const EdgeInsets.all(12),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, Routes.job, arguments: j.id);
                  },
                  child: Row(
                    children: [
                      DhImage(asset: j.image, width: 40, height: 40, radius: 6),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(j.id, style: AppText.monoLg.copyWith(color: c.text)),
                            Text(
                              j.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.bodySm.copyWith(color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StageChip(j.stage),
                    ],
                  ),
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
                        p.phone == null ? 'No phone number on file for ${p.name}' : 'Calling ${p.name} · ${p.phone}',
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
        );
      },
    ),
  );
}

class _PartnerAvatar extends StatelessWidget {
  const _PartnerAvatar({required this.partner, this.size = 48});

  final Partner partner;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cat = _category(partner.role);
    if (partner.avatar == null && cat == 'Stones') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c.isDark ? c.surfaceHighest : c.surfaceHigh, shape: BoxShape.circle),
        child: Icon(Icons.diamond_outlined, size: size * 0.5, color: c.text),
      );
    }
    return DhAvatar(asset: partner.avatar, name: partner.name, size: size, dark: cat == 'Retail');
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner, required this.onTap});

  final Partner partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final p = partner;
    return DhCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PartnerAvatar(partner: p),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
                const SizedBox(height: 2),
                Text(
                  p.role.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.labelSm.copyWith(color: c.accent),
                ),
                if (p.company != null) ...[
                  const SizedBox(height: 6),
                  _IconLine(icon: Icons.business_outlined, text: p.company!),
                ],
                if (p.location != null) ...[
                  const SizedBox(height: 2),
                  _IconLine(icon: Icons.place_outlined, text: p.location!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 16, color: c.gold),
                  const SizedBox(width: 2),
                  Text(p.rating.toStringAsFixed(1), style: AppText.monoMd.copyWith(color: c.text)),
                ],
              ),
              const SizedBox(height: 8),
              StatusChip('${p.activeJobs} jobs', color: c.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(icon, size: 14, color: c.textFaint),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, this.mono = false});

  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textFaint),
          const SizedBox(width: 10),
          Text(label, style: AppText.bodyMd.copyWith(color: c.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (mono ? AppText.monoMd : AppText.bodyMd).copyWith(color: c.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.isDark ? c.surfaceHigh : c.surfaceLow, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.labelSm.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 6),
          Text(value, style: AppText.headlineMd.copyWith(color: c.text)),
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

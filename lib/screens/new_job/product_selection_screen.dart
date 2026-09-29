import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Full job order — Step 1 (Product): choose the category, add a reference, or clone a previous job.
class ProductSelectionScreen extends StatefulWidget {
  const ProductSelectionScreen({super.key});

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

const _categories = <(String, IconData)>[
  ('Ring', Icons.diamond_outlined),
  ('Earrings', Icons.stars_outlined),
  ('Necklace', Icons.all_inclusive),
  ('Pendant', Icons.blur_on),
  ('Bracelet', Icons.radio_button_unchecked),
  ('Bangle', Icons.toll_outlined),
  ('Brooch', Icons.filter_vintage_outlined),
  ('Other', Icons.category_outlined),
];

/// Maps a free product type ("Engagement Ring", "Tennis Bracelet") to one of the grid categories.
String _categoryOf(String productType) {
  final last = productType.trim().split(RegExp(r'\s+')).last.toLowerCase();
  for (final (name, _) in _categories) {
    if (name.toLowerCase() == last) return name;
  }
  return 'Other';
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  /// Bumped to rebuild the notes field after its text is replaced programmatically.
  int _notesVersion = 0;

  Future<void> _pickReference() async {
    final path = await pickImage(context, title: 'Reference Sketch');
    if (path == null || !mounted) return;
    final refs = app.draft.referenceImages;
    setState(() {
      if (refs.isEmpty) {
        refs.add(path);
      } else {
        refs[0] = path;
      }
    });
  }

  Future<void> _fromPrevious() async {
    final job = await showDhSheet<Job>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => _PreviousJobsSheet(scroll: scroll),
      ),
    );
    if (job == null || !mounted) return;
    setState(() {
      _copyFrom(job);
      _notesVersion++;
    });
    showSnack(context, 'Specs copied from ${job.id}', icon: Icons.content_copy);
  }

  void _copyFrom(Job job) {
    final d = app.draft
      ..productCategory = job.productType
      ..customer = job.customer
      ..quantity = job.quantity;
    if (job.weightGrams != null) d.targetWeight = job.weightGrams;

    // Metal: "18K Yellow Gold", "Platinum 950", "14K White Gold"…
    final m = job.metal.toLowerCase();
    if (m.contains('platinum')) {
      d
        ..baseMetal = 'Platinum'
        ..purity = '950 Plat'
        ..metalColor = 'White';
    } else if (m.contains('silver')) {
      d
        ..baseMetal = 'Silver'
        ..purity = '925 Silver'
        ..metalColor = 'White';
    } else {
      d.baseMetal = 'Gold';
      final k = RegExp(r'(\d{2})k').firstMatch(m);
      if (k != null) d.purity = '${k.group(1)}K';
      for (final color in const ['Yellow', 'White', 'Rose']) {
        if (m.contains(color.toLowerCase())) d.metalColor = color;
      }
      if (m.contains('two')) d.metalColor = 'Two Tone';
    }

    // Center stone: "2.4ct Lab Diamond", "1.8ct Emerald Cut", "2.1ct Pear Sapphire"…
    final stone = job.centerStone;
    final ct = RegExp(r'(\d+(?:\.\d+)?)\s*ct').firstMatch(stone);
    if (ct != null) d.stoneCarat = double.tryParse(ct.group(1)!);
    const shapes = ['Round', 'Oval', 'Emerald', 'Pear', 'Cushion', 'Princess', 'Marquise', 'Radiant'];
    for (final s in shapes) {
      if (stone.contains(s)) {
        d.stoneShape = s;
        break;
      }
    }
    final withoutCut = stone.replaceAll(RegExp(r'\w+ Cut'), '');
    for (final t in const ['Diamond', 'Sapphire', 'Ruby', 'Emerald']) {
      if (withoutCut.contains(t)) {
        d.stoneType = t;
        break;
      }
    }

    // Setting: "6-Prong Crown", "Micro-pave Halo", "Channel"…
    final s = job.settingStyle.toLowerCase();
    d.settingStyle = s.contains('halo')
        ? 'Halo'
        : s.contains('bezel')
        ? 'Bezel'
        : s.contains('tension')
        ? 'Tension'
        : s.contains('prong')
        ? 'Prong'
        : 'Other';
    if (s.contains('pav')) {
      d.sideStoneSetting = 'Pavé';
    } else if (s.contains('channel')) {
      d.sideStoneSetting = 'Channel';
    } else if (s.contains('shared')) {
      d.sideStoneSetting = 'Shared Prong';
    }

    final size = job.ringSize?.split(' ');
    if (size != null && size.length == 2) {
      d
        ..sizeSystem = size[0]
        ..ringSize = size[1];
    }

    d.notes = [
      if (job.notes != null && job.notes!.trim().isNotEmpty) job.notes!.trim(),
      'Based on ${job.id} — ${job.title}.',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = app.draft;
    final selected = _categoryOf(d.productCategory);
    final ref = d.referenceImages.isEmpty ? null : d.referenceImages.first;
    return WizardScaffold(
      title: 'Step 1: Specifications',
      step: 1,
      totalSteps: 4,
      stepLabel: 'Product',
      actions: const [_ProfileButton()],
      ctaLabel: 'Define Design Requirements',
      onCta: () => Navigator.pushNamed(context, Routes.designSpecs),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected Job Type', style: AppText.labelMd.copyWith(color: c.textMuted)),
                  const SizedBox(height: 2),
                  Text(d.jobType, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Material(
              color: c.accentSoft,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 16, color: c.isDark ? c.gold : c.accent),
                      const SizedBox(width: 4),
                      Text('Change', style: AppText.labelMd.copyWith(color: c.isDark ? c.gold : c.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('What are we making?', style: _sectionStyle(c)),
        const SizedBox(height: 8),
        Text(
          'Select the primary category for this job to set up the correct specification forms.',
          style: AppText.bodyLg.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 20),
        OptionLayout(
          columns: 2,
          spacing: 16,
          children: [
            for (final (name, icon) in _categories)
              _CategoryTile(
                icon: icon,
                label: name,
                selected: selected == name,
                onTap: () => setState(() => d.productCategory = name),
              ),
          ],
        ),
        const SizedBox(height: 32),
        Text('Start with a reference', style: _sectionStyle(c)),
        const SizedBox(height: 16),
        UploadBox(
          filledIcon: true,
          icon: Icons.add_a_photo_outlined,
          title: 'Upload or capture sketch',
          subtitle: 'Images, CAD files, or drawings',
          height: 168,
          imagePath: ref,
          onTap: _pickReference,
          onClear: ref == null ? null : () => setState(() => d.referenceImages.removeAt(0)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _fromPrevious,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: c.isDark ? c.border : c.borderStrong),
            backgroundColor: c.isDark ? c.surface : c.surfaceHigh.withValues(alpha: 0.7),
            textStyle: AppText.bodyLg.copyWith(fontWeight: FontWeight.w500),
          ),
          icon: const Icon(Icons.search, size: 20),
          label: const Text('Create from Previous Job'),
        ),
        const SizedBox(height: 32),
        Text('Piece Name', style: _sectionStyle(c)),
        const SizedBox(height: 12),
        DhTextField(value: d.title, hint: 'e.g. Gold Signet Ring', onChanged: (v) => d.title = v),
        const SizedBox(height: 32),
        Text('Additional Product Notes', style: _sectionStyle(c)),
        const SizedBox(height: 12),
        DhTextField(
          key: ValueKey(_notesVersion),
          value: d.notes,
          maxLines: 4,
          hint: 'Any initial thoughts on material, sizing, or special requirements...',
          onChanged: (v) => d.notes = v,
        ),
      ],
    );
  }
}

TextStyle _sectionStyle(DhColors c) =>
    AppText.bodyLg.copyWith(fontSize: 17, fontWeight: FontWeight.w500, color: c.text);

/// The design's black "profile" button at the right of the step header.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Tooltip(
        message: 'Profile & settings',
        child: Material(
          color: c.action,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.settings),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(dimension: 34, child: Icon(Icons.person_outline, size: 20, color: c.onAction)),
          ),
        ),
      ),
    );
  }
}

/// Tall tonal category tile (icon over label).
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = c.isDark ? c.gold : c.accent;
    return Material(
      color: selected ? c.accentSoft : (c.isDark ? c.surface : c.surfaceHigh.withValues(alpha: 0.7)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selected ? BorderSide(color: on, width: 1.5) : (c.isDark ? BorderSide(color: c.border) : BorderSide.none),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 116,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: selected ? on : c.text),
              const SizedBox(height: 12),
              Text(
                label,
                style: AppText.bodyLg.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? on : c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviousJobsSheet extends StatefulWidget {
  const _PreviousJobsSheet({required this.scroll});

  final ScrollController scroll;

  @override
  State<_PreviousJobsSheet> createState() => _PreviousJobsSheetState();
}

class _PreviousJobsSheetState extends State<_PreviousJobsSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final q = _query.trim().toLowerCase();
    final jobs = app.jobs.where((j) {
      if (q.isEmpty) return true;
      return j.id.toLowerCase().contains(q) ||
          j.title.toLowerCase().contains(q) ||
          j.customer.toLowerCase().contains(q) ||
          j.metal.toLowerCase().contains(q);
    }).toList();
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Text('Create from Previous Job', style: AppText.headlineSm),
        const SizedBox(height: 4),
        Text(
          'Copies product type, metal, stone, setting and size into this order.',
          style: AppText.bodySm.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search job ID, title or customer',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        if (jobs.isEmpty) const EmptyState(icon: Icons.search_off, message: 'No jobs match your search.'),
        for (final j in jobs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DhCard(
              padding: const EdgeInsets.all(10),
              onTap: () => Navigator.pop(context, j),
              child: Row(
                children: [
                  DhImage(asset: j.image, width: 52, height: 52, radius: 6),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(j.id, style: AppText.monoSm.copyWith(color: c.textFaint)),
                        Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.titleMd),
                        Text(
                          '${j.metal} · ${j.productType}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodySm.copyWith(color: c.textMuted),
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
    );
  }
}

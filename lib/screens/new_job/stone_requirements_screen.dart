import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

const _types = ['Diamond', 'Sapphire', 'Ruby', 'Emerald', 'Moissanite', 'Other'];
const _shapes = ['Round', 'Oval', 'Pear', 'Emerald', 'Radiant', 'Cushion', 'Marquise', 'Princess'];
const _colors = ['D-F', 'G-H', 'I-J', 'K-M'];
const _clarities = ['IF/FL', 'VVS1/2', 'VS1', 'VS2', 'SI1/2'];
const _cuts = ['Ex', 'VG', 'G', 'F'];
const _certificates = ['No Certificate', 'GIA', 'IGI', 'AGS', 'Other'];

/// Diamonds and moissanite are graded by color / clarity / cut; colored stones by tone.
bool _isGraded(String type) => type == 'Diamond' || type == 'Moissanite';

String _parcelTitle(MeleeParcel p) => p.type == 'Other' ? '${p.shape} Accent Stones' : '${p.shape} ${p.type}s';

enum _ParcelAction { save, delete }

class StoneRequirementsScreen extends StatefulWidget {
  const StoneRequirementsScreen({super.key});

  @override
  State<StoneRequirementsScreen> createState() => _StoneRequirementsScreenState();
}

class _StoneRequirementsScreenState extends State<StoneRequirementsScreen> {
  JobDraft get d => app.draft;

  late final TextEditingController _carat = TextEditingController(text: d.stoneCarat?.toStringAsFixed(2) ?? '');
  late final List<TextEditingController> _dims = _parseDims(d.stoneDims);
  late bool _notesOpen = d.stoneNotes.isNotEmpty;
  late bool _meleeSupplied = d.melee.isNotEmpty && d.melee.every((p) => p.supplied);
  final Set<MeleeParcel> _parcelNotesOpen = {};
  String? _certificatePhoto;

  /// Bumped after the parcel sheet saves so inline note fields re-read their value.
  int _rev = 0;

  static List<TextEditingController> _parseDims(String s) {
    final parts = s.split(RegExp(r'[x×]')).map((p) => p.trim()).toList();
    return List.generate(3, (i) {
      final v = i < parts.length ? parts[i] : '';
      return TextEditingController(text: v == '-' ? '' : v);
    });
  }

  @override
  void dispose() {
    _carat.dispose();
    for (final ctrl in _dims) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _setType(String t) => setState(() {
    if (_isGraded(t) != _isGraded(d.stoneType)) d.stoneColor = _isGraded(t) ? 'G-H' : '';
    d.stoneType = t;
  });

  void _stepCarat(double delta) {
    final v = ((((d.stoneCarat ?? 0) + delta) * 100).round() / 100).clamp(0.05, 99.0).toDouble();
    _carat.text = v.toStringAsFixed(2);
    setState(() => d.stoneCarat = v);
  }

  void _saveDims() {
    final v = [for (final ctrl in _dims) ctrl.text.trim()];
    setState(() => d.stoneDims = v.every((s) => s.isEmpty) ? '' : v.map((s) => s.isEmpty ? '-' : s).join(' x '));
  }

  Future<void> _pickStonePhoto() async {
    final path = await pickImage(context, title: 'Photo of Stone');
    if (path != null && mounted) setState(() => d.stonePhoto = path);
  }

  Future<void> _pickCertificate() async {
    final path = await pickImage(context, title: 'Stone Certificate');
    if (path != null && mounted) setState(() => _certificatePhoto = path);
  }

  void _setMeleeSource(bool supplied) => setState(() {
    _meleeSupplied = supplied;
    for (final p in d.melee) {
      p.supplied = supplied;
    }
  });

  Future<void> _openParcel([MeleeParcel? parcel]) async {
    final work = parcel == null
        ? MeleeParcel(supplied: _meleeSupplied)
        : MeleeParcel(
            type: parcel.type,
            shape: parcel.shape,
            sizeRange: parcel.sizeRange,
            totalCarat: parcel.totalCarat,
            colorClarity: parcel.colorClarity,
            supplied: parcel.supplied,
            notes: parcel.notes,
          );
    final action = await showModalBottomSheet<_ParcelAction>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ParcelSheet(parcel: work, isNew: parcel == null),
    );
    if (action == null || !mounted) return;
    setState(() {
      _rev++;
      if (action == _ParcelAction.delete) {
        d.melee.remove(parcel);
        _parcelNotesOpen.remove(parcel);
      } else if (parcel == null) {
        d.melee.add(work);
      } else {
        parcel
          ..type = work.type
          ..shape = work.shape
          ..sizeRange = work.sizeRange
          ..totalCarat = work.totalCarat
          ..colorClarity = work.colorClarity
          ..notes = work.notes;
      }
    });
    final msg = action == _ParcelAction.delete
        ? 'Parcel removed'
        : (parcel == null ? 'Parcel added' : 'Parcel updated');
    showSnack(context, msg, icon: action == _ParcelAction.delete ? Icons.delete_outline : Icons.check_circle_outline);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return WizardScaffold(
      title: 'Step 2: Stone Requirements',
      step: 2,
      totalSteps: 4,
      stepLabel: 'Stones',
      badge: 'Bespoke ${d.productCategory}',
      ctaLabel: 'Continue to Commercials',
      onCta: () => Navigator.pushNamed(context, Routes.commercial),
      children: [
        Text('Center Stone', style: AppText.headlineSm),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SourceCard(
                  icon: Icons.search,
                  label: 'Needs to be Sourced',
                  selected: !d.stoneSupplied,
                  onTap: () => setState(() => d.stoneSupplied = false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SourceCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'In Stock / Supplied',
                  gold: true,
                  selected: d.stoneSupplied,
                  onTap: () => setState(() => d.stoneSupplied = true),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: d.stoneSupplied ? const _SuppliedBanner() : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 24),
        const SectionLabel('Visual Reference'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: UploadBox(
                title: 'Add Photo of Stone',
                icon: Icons.add_a_photo_outlined,
                height: 128,
                imagePath: d.stonePhoto,
                onTap: _pickStonePhoto,
                onClear: () => setState(() => d.stonePhoto = null),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: UploadBox(
                title: 'Add Certificate',
                icon: Icons.description_outlined,
                height: 128,
                imagePath: _certificatePhoto,
                onTap: _pickCertificate,
                onClear: () => setState(() => _certificatePhoto = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _LinkButton(
          icon: _notesOpen ? Icons.expand_less : Icons.note_add_outlined,
          label: _notesOpen ? 'Hide notes' : (d.stoneNotes.isEmpty ? 'Add notes' : 'Edit notes'),
          onTap: () => setState(() => _notesOpen = !_notesOpen),
        ),
        if (_notesOpen)
          DhTextField(
            value: d.stoneNotes,
            maxLines: 3,
            hint: 'Enter stone notes (inclusions, orientation, handling)…',
            onChanged: (v) => setState(() => d.stoneNotes = v),
          )
        else if (d.stoneNotes.isNotEmpty)
          Text(
            d.stoneNotes,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodySm.copyWith(color: c.textMuted),
          ),
        const SizedBox(height: 16),
        _specsCard(c),
        const SizedBox(height: 24),
        Field(
          label: 'Certificate Required',
          child: ChoiceGroup<String>(
            options: _certificates,
            selected: d.certificate,
            dense: true,
            onChanged: (v) => setState(() => d.certificate = v),
          ),
        ),
        const SizedBox(height: 32),
        ..._meleeSection(c),
      ],
    );
  }

  Widget _specsCard(DhColors c) {
    final graded = _isGraded(d.stoneType);
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.diamond_outlined, size: 20, color: c.isDark ? c.gold : c.accent),
              const SizedBox(width: 8),
              Text('Specifications', style: AppText.titleMd),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  d.stoneLabel,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.monoSm.copyWith(color: c.textFaint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Field(
            label: 'Type',
            child: ChoiceGroup<String>(
              options: _types,
              selected: d.stoneType,
              columns: 3,
              dense: true,
              onChanged: _setType,
            ),
          ),
          const SizedBox(height: 16),
          Field(
            label: 'Origin',
            child: DhSegmented<String>(
              options: const ['Natural', 'Lab Grown'],
              selected: d.stoneOrigin,
              onChanged: (v) => setState(() => d.stoneOrigin = v),
            ),
          ),
          const SizedBox(height: 16),
          Field(
            label: 'Shape',
            child: SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _shapes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _ShapeChip(
                  shape: _shapes[i],
                  selected: d.stoneShape == _shapes[i],
                  onTap: () => setState(() => d.stoneShape = _shapes[i]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Field(label: 'Est. Carat', child: _caratStepper(c)),
          const SizedBox(height: 16),
          Field(label: 'Dimensions (L × W × D)', child: _dimsRow(c)),
          const SizedBox(height: 16),
          if (graded) ...[
            Field(
              label: 'Color',
              child: ChoiceGroup<String>(
                options: _colors,
                selected: d.stoneColor,
                columns: 4,
                mono: true,
                dense: true,
                onChanged: (v) => setState(() => d.stoneColor = v),
              ),
            ),
            const SizedBox(height: 16),
            Field(
              label: 'Clarity',
              child: ChoiceGroup<String>(
                options: _clarities,
                selected: d.stoneClarity,
                columns: 3,
                mono: true,
                dense: true,
                onChanged: (v) => setState(() => d.stoneClarity = v),
              ),
            ),
            const SizedBox(height: 16),
            Field(
              label: 'Cut',
              child: ChoiceGroup<String>(
                options: _cuts,
                selected: d.stoneCut,
                columns: 4,
                mono: true,
                dense: true,
                onChanged: (v) => setState(() => d.stoneCut = v),
              ),
            ),
          ] else
            Field(
              label: 'Color / Tone',
              hint: 'Describe hue, tone and saturation for sourcing.',
              child: DhTextField(
                value: d.stoneColor,
                hint: 'e.g. Royal blue, medium-dark tone',
                onChanged: (v) => setState(() => d.stoneColor = v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _caratStepper(DhColors c) {
    return Row(
      children: [
        _StepButton(icon: Icons.remove, tooltip: 'Decrease carat', onTap: () => _stepCarat(-0.05)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _carat,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.monoLg.copyWith(color: c.text, fontSize: 16),
            decoration: const InputDecoration(hintText: '0.00', suffixText: 'ct'),
            onChanged: (v) => setState(() => d.stoneCarat = double.tryParse(v.trim())),
          ),
        ),
        const SizedBox(width: 8),
        _StepButton(icon: Icons.add, tooltip: 'Increase carat', onTap: () => _stepCarat(0.05)),
      ],
    );
  }

  Widget _dimsRow(DhColors c) {
    Widget field(int i, String hint) => Expanded(
      child: TextField(
        controller: _dims[i],
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: AppText.monoLg.copyWith(color: c.text),
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
        onChanged: (_) => _saveDims(),
      ),
    );
    Widget times() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('×', style: AppText.monoLg.copyWith(color: c.textFaint)),
    );
    return Row(
      children: [
        field(0, 'L'),
        times(),
        field(1, 'W'),
        times(),
        field(2, 'D'),
        const SizedBox(width: 8),
        Text('mm', style: AppText.monoMd.copyWith(color: c.textFaint)),
      ],
    );
  }

  List<Widget> _meleeSection(DhColors c) {
    final count = d.melee.length;
    return [
      Row(
        children: [
          Expanded(child: Text('Melee & Accent Stones', style: AppText.headlineSm)),
          Text('$count PARCEL${count == 1 ? '' : 'S'}', style: AppText.monoCaps.copyWith(color: c.textFaint)),
        ],
      ),
      const SizedBox(height: 12),
      DhSegmented<bool>(
        options: const [false, true],
        selected: _meleeSupplied,
        labelOf: (v) => v ? 'In Stock / Supplied' : 'Needs Sourcing',
        onChanged: _setMeleeSource,
      ),
      const SizedBox(height: 6),
      Text('Applies to all melee parcels.', style: AppText.bodySm.copyWith(color: c.textFaint)),
      const SizedBox(height: 12),
      const Divider(),
      const SizedBox(height: 12),
      if (d.melee.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'No melee parcels yet. Add one if the design has accent or pavé stones.',
            style: AppText.bodySm.copyWith(color: c.textFaint),
          ),
        ),
      for (final p in d.melee) _parcelCard(c, p),
      const SizedBox(height: 4),
      _AddParcelButton(onTap: () => _openParcel()),
    ];
  }

  Widget _parcelCard(DhColors c, MeleeParcel p) {
    final open = _parcelNotesOpen.contains(p);
    final notes = p.notes ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DhCard(
            onTap: () => _openParcel(p),
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.blur_on, color: c.text),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _parcelTitle(p),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleMd.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(p.summary, style: AppText.monoMd.copyWith(color: c.textMuted)),
                      const SizedBox(height: 6),
                      StatusChip(p.supplied ? 'Supplied' : 'Sourcing', color: p.supplied ? c.gold : c.info),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit parcel',
                  icon: Icon(Icons.edit_outlined, color: c.textMuted),
                  onPressed: () => _openParcel(p),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _LinkButton(
            icon: open ? Icons.expand_less : Icons.note_add_outlined,
            label: open ? 'Hide parcel notes' : (notes.isEmpty ? 'Add parcel notes' : 'Edit parcel notes'),
            onTap: () => setState(() => open ? _parcelNotesOpen.remove(p) : _parcelNotesOpen.add(p)),
          ),
          if (open)
            DhTextField(
              key: ValueKey((p, _rev)),
              value: notes,
              maxLines: 2,
              hint: 'Matching, calibration, setting notes…',
              onChanged: (v) => setState(() => p.notes = v.trim().isEmpty ? null : v),
            )
          else if (notes.isNotEmpty)
            Text(
              notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySm.copyWith(color: c.textMuted),
            ),
        ],
      ),
    );
  }
}

/// Sourcing decision tile. The "supplied" variant tints gold with a pulsing dot.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.gold = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tint = gold ? c.gold : c.accent;
    return Material(
      color: selected ? (gold ? c.goldSoft : c.accentSoft) : (c.isDark ? c.surfaceLow : c.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? tint : c.borderStrong, width: selected ? 2 : 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 30, color: selected ? (c.isDark ? c.gold : c.text) : c.textMuted),
                  const SizedBox(height: 10),
                  Text(
                    label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AppText.labelMd.copyWith(fontSize: 13, letterSpacing: 0.8, color: c.text),
                  ),
                ],
              ),
            ),
            if (selected && gold) Positioned(top: 10, right: 10, child: _PulseDot(color: c.gold)),
            if (selected && !gold)
              Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, size: 18, color: c.accent)),
          ],
        ),
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
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Transform.scale(
              scale: 1 + _ctrl.value * 1.2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: (1 - _ctrl.value) * 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuppliedBanner extends StatelessWidget {
  const _SuppliedBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceHigh : c.surfaceHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.borderStrong),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: c.success, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CUSTOMER SUPPLIED STONE', style: AppText.labelMd.copyWith(letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text('Verified & Logged in Inventory', style: AppText.bodySm.copyWith(color: c.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.action, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.inventory, size: 20, color: c.isDark ? c.onAction : c.goldSoft),
          ),
        ],
      ),
    );
  }
}

/// Small uppercase text link with a leading icon ("ADD NOTES").
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label.toUpperCase(), style: AppText.labelMd.copyWith(letterSpacing: 0.6)),
        style: TextButton.styleFrom(
          foregroundColor: c.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(0, 38),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.isDark ? c.surfaceHigh : c.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(width: 48, height: 48, child: Icon(icon, size: 20, color: c.text)),
        ),
      ),
    );
  }
}

class _ShapeChip extends StatelessWidget {
  const _ShapeChip({required this.shape, required this.selected, required this.onTap});

  final String shape;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = selected ? (c.isDark ? c.gold : c.accent) : c.textMuted;
    return Material(
      color: selected ? c.accentSoft : (c.isDark ? c.surfaceLow : c.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? c.accent : c.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(size: const Size(28, 28), painter: _ShapePainter(shape, fg)),
              const SizedBox(height: 8),
              Text(
                shape,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.labelMd.copyWith(color: selected ? fg : c.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outline glyph for each center-stone cut.
class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);

  final String shape;
  final Color color;

  static Path _cutRect(Rect r, double cut) => Path()
    ..moveTo(r.left + cut, r.top)
    ..lineTo(r.right - cut, r.top)
    ..lineTo(r.right, r.top + cut)
    ..lineTo(r.right, r.bottom - cut)
    ..lineTo(r.right - cut, r.bottom)
    ..lineTo(r.left + cut, r.bottom)
    ..lineTo(r.left, r.bottom - cut)
    ..lineTo(r.left, r.top + cut)
    ..close();

  Path _path(Size s) {
    final w = s.width;
    final h = s.height;
    final center = Offset(w / 2, h / 2);
    switch (shape) {
      case 'Oval':
        return Path()..addOval(Rect.fromCenter(center: center, width: w * 0.62, height: h * 0.9));
      case 'Pear':
        return Path()
          ..moveTo(w / 2, h * 0.04)
          ..cubicTo(w * 0.62, h * 0.28, w * 0.8, h * 0.48, w * 0.8, h * 0.64)
          ..arcToPoint(Offset(w * 0.2, h * 0.64), radius: Radius.circular(w * 0.3))
          ..cubicTo(w * 0.2, h * 0.48, w * 0.38, h * 0.28, w / 2, h * 0.04)
          ..close();
      case 'Emerald':
        final r = Rect.fromLTRB(w * 0.22, h * 0.05, w * 0.78, h * 0.95);
        return _cutRect(r, w * 0.12)..addRect(r.deflate(w * 0.1));
      case 'Radiant':
        return _cutRect(Rect.fromLTRB(w * 0.14, h * 0.1, w * 0.86, h * 0.9), w * 0.1);
      case 'Cushion':
        return Path()..addRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.1, h * 0.1, w * 0.9, h * 0.9), Radius.circular(w * 0.26)),
        );
      case 'Marquise':
        return Path()
          ..moveTo(w / 2, h * 0.02)
          ..quadraticBezierTo(w * 0.98, h / 2, w / 2, h * 0.98)
          ..quadraticBezierTo(w * 0.02, h / 2, w / 2, h * 0.02)
          ..close();
      case 'Princess':
        final r = Rect.fromLTRB(w * 0.12, h * 0.12, w * 0.88, h * 0.88);
        return Path()
          ..addRect(r)
          ..moveTo(r.left, r.top)
          ..lineTo(r.right, r.bottom)
          ..moveTo(r.right, r.top)
          ..lineTo(r.left, r.bottom);
      default:
        return Path()
          ..addOval(Rect.fromCircle(center: center, radius: w * 0.44))
          ..addPath(_cutRect(Rect.fromCircle(center: center, radius: w * 0.2), w * 0.08), Offset.zero);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_path(size), paint);
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.shape != shape || old.color != color;
}

class _AddParcelButton extends StatelessWidget {
  const _AddParcelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DashedBorder(
      radius: 10,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 20, color: c.text),
                const SizedBox(width: 8),
                Text('ADD MELEE PARCEL', style: AppText.labelMd.copyWith(fontSize: 13, letterSpacing: 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Add / edit sheet for one melee parcel. Mutates [parcel] (a working copy) and
/// pops with a [_ParcelAction].
class _ParcelSheet extends StatefulWidget {
  const _ParcelSheet({required this.parcel, required this.isNew});

  final MeleeParcel parcel;
  final bool isNew;

  @override
  State<_ParcelSheet> createState() => _ParcelSheetState();
}

class _ParcelSheetState extends State<_ParcelSheet> {
  MeleeParcel get p => widget.parcel;

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
              Row(
                children: [
                  Icon(Icons.blur_on, color: c.isDark ? c.gold : c.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.isNew ? 'Add Melee Parcel' : 'Edit Melee Parcel', style: AppText.headlineSm),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(p.summary, style: AppText.monoSm.copyWith(color: c.textFaint)),
              const SizedBox(height: 16),
              Field(
                label: 'Type',
                child: ChoiceGroup<String>(
                  options: const ['Diamond', 'Sapphire', 'Other'],
                  selected: p.type,
                  columns: 3,
                  dense: true,
                  onChanged: (v) => setState(() => p.type = v),
                ),
              ),
              const SizedBox(height: 14),
              Field(
                label: 'Shape',
                child: ChoiceGroup<String>(
                  options: const ['Round', 'Baguette', 'Princess'],
                  selected: p.shape,
                  columns: 3,
                  dense: true,
                  onChanged: (v) => setState(() => p.shape = v),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Field(
                      label: 'Size Range',
                      child: DhTextField(
                        value: p.sizeRange.replaceAll('mm', '').trim(),
                        hint: '1.0 - 1.5',
                        mono: true,
                        suffixText: 'mm',
                        onChanged: (v) => setState(() => p.sizeRange = v.trim().isEmpty ? '' : '${v.trim()}mm'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Field(
                      label: 'Total Carat',
                      child: DhTextField(
                        value: p.totalCarat.toStringAsFixed(2),
                        hint: '0.25',
                        mono: true,
                        suffixText: 'ctw',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => setState(() => p.totalCarat = double.tryParse(v.trim()) ?? 0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Field(
                label: 'Color / Clarity',
                child: DhTextField(
                  value: p.colorClarity,
                  hint: 'G-H / VS',
                  mono: true,
                  onChanged: (v) => setState(() => p.colorClarity = v.trim()),
                ),
              ),
              const SizedBox(height: 14),
              Field(
                label: 'Notes',
                child: DhTextField(
                  value: p.notes ?? '',
                  maxLines: 2,
                  hint: 'Matching, calibration, setting notes…',
                  onChanged: (v) => p.notes = v.trim().isEmpty ? null : v,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!widget.isNew) ...[
                    Expanded(
                      child: SecondaryButton(
                        'Delete',
                        icon: Icons.delete_outline,
                        color: c.danger,
                        onPressed: () => Navigator.pop(context, _ParcelAction.delete),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      'Save Parcel',
                      icon: Icons.check,
                      onPressed: () => Navigator.pop(context, _ParcelAction.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

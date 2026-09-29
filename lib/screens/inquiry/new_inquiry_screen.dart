import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// "Create Inquiry" — a single-page brief (assets, voice note, specs, logistics) sent straight to CAD.
class NewInquiryScreen extends StatefulWidget {
  const NewInquiryScreen({super.key});

  @override
  State<NewInquiryScreen> createState() => _NewInquiryScreenState();
}

/// Metal chip → (baseMetal, purity, metalColor).
const _metalSpecs = {
  '18K Yellow': ('Gold', '18K', 'Yellow'),
  '14K White': ('Gold', '14K', 'White'),
  'Platinum': ('Platinum', '950 Plat', 'White'),
  'Rose Gold': ('Gold', '18K', 'Rose'),
};
const _sizes = ['Size 6.0', 'Size 6.5', 'Size 7.0', 'Size 7.5', 'Size 8.0'];
const _profiles = ['Comfort Fit', 'Standard', 'Flat'];
const _stoneTypes = ['Diamond', 'Sapphire', 'Emerald', 'Ruby', 'None'];
const _stoneShapes = ['Round', 'Oval', 'Emerald', 'Cushion', 'Pear', 'Princess'];

String _basename(String path) => path.split(RegExp(r'[\\/]')).last;

class _NewInquiryScreenState extends State<NewInquiryScreen> with SingleTickerProviderStateMixin {
  static final ThemeData _panelTheme = AppTheme.dark();

  String _metal = '18K Yellow';
  String _size = 'Size 6.0';
  String _profile = 'Comfort Fit';

  String? _refFile;
  bool _refRemoved = false;
  String? _sketch;
  final _carat = TextEditingController(text: '2.0');

  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  Timer? _timer;
  bool _recording = false;
  Duration _rec = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Fresh draft (same as app.resetDraft(), without notifying listeners mid-build).
    final d = app.draft = JobDraft();
    d.jobType = 'New Custom Design';
    d.productCategory = 'Ring';
    d.customer = '';
    d.stoneType = 'Diamond';
    d.stoneShape = 'Emerald';
    d.stoneCarat = 2.0;
    d.sizeSystem = 'US';
    _applyMetal(_metal);
    d.ringSize = _size.replaceFirst('Size ', '');
    d.bandProfile = _profile;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wave.dispose();
    _carat.dispose();
    super.dispose();
  }

  void _applyMetal(String m) {
    final spec = _metalSpecs[m]!;
    app.draft
      ..baseMetal = spec.$1
      ..purity = spec.$2
      ..metalColor = spec.$3;
  }

  // ---- Assets -------------------------------------------------------------
  Future<void> _pickRef() async {
    final path = await pickImage(context, title: 'Reference Image');
    if (path == null || !mounted) return;
    setState(() {
      _refFile = path;
      _refRemoved = false;
    });
  }

  Future<void> _pickSketch() async {
    final path = await pickImage(context, title: 'Upload Sketch');
    if (path == null || !mounted) return;
    setState(() => _sketch = path);
  }

  // ---- Voice note ---------------------------------------------------------
  void _toggleRecording() {
    final d = app.draft;
    if (_recording) {
      _timer?.cancel();
      _wave.stop();
      if (_rec == Duration.zero) _rec = const Duration(seconds: 1);
      setState(() {
        _recording = false;
        d.hasVoiceNote = true;
        d.voiceNoteLength = _rec;
      });
      showSnack(context, 'Briefing note saved (${Fmt.duration(_rec)})', icon: Icons.mic);
    } else {
      setState(() {
        _recording = true;
        _rec = Duration.zero;
      });
      _wave.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _rec += const Duration(seconds: 1));
      });
    }
  }

  void _deleteRecording() {
    setState(() {
      _rec = Duration.zero;
      app.draft
        ..hasVoiceNote = false
        ..voiceNoteLength = Duration.zero;
    });
  }

  // ---- Logistics ----------------------------------------------------------
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: app.draft.requestedDelivery ?? today.add(const Duration(days: 35)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Desired date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      app.draft
        ..requestedDelivery = picked
        ..deliveryDate = picked;
    });
  }

  void _saveDraft() {
    if (_recording) _toggleRecording();
    showSnack(context, 'Inquiry draft saved', icon: Icons.save_outlined);
  }

  void _submit() {
    final d = app.draft;
    if (d.customer.trim().isEmpty) {
      showSnack(context, 'Add the customer name under Logistics first', icon: Icons.info_outline);
      return;
    }
    if (_recording) _toggleRecording();
    _applyMetal(_metal);
    d
      ..customer = d.customer.trim()
      ..productCategory = 'Ring'
      ..sizeSystem = 'US'
      ..ringSize = _size.replaceFirst('Size ', '')
      ..bandProfile = _profile
      ..targetUnitPrice = d.budget ?? d.targetUnitPrice
      ..deliveryDate = d.requestedDelivery;
    d.referenceImages
      ..clear()
      ..addAll([?_refFile, ?_sketch]);
    final job = app.createJobFromDraft(title: '$_metal Custom Ring');
    if (d.stoneType == 'None') job.centerStone = '—';
    if (_refFile == null && !_refRemoved) {
      job.image = Img.ringEmeraldCutDark;
      job.files.add(
        ProjectFile(name: 'Client_Pinterest.jpg', kind: FileKind.image, asset: Img.ringEmeraldCutDark, jobId: job.id),
      );
    }
    if (d.hasVoiceNote) {
      job.files.add(
        ProjectFile(
          name: 'Designer_Briefing.m4a',
          kind: FileKind.audio,
          jobId: job.id,
          sizeLabel: '${math.max(0.1, d.voiceNoteLength.inSeconds * 0.016).toStringAsFixed(1)} MB',
        ),
      );
    }
    app.setStage(job, JobStage.cad, note: 'Inquiry submitted to CAD.');
    showSnack(context, 'Inquiry ${job.id} submitted to CAD', icon: Icons.send_outlined);
    Navigator.pushReplacementNamed(context, Routes.job, arguments: job.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const gap = SizedBox(height: 16);
    return DetailScaffold(
      title: 'Create Inquiry',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TextButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Save Draft'),
          ),
        ),
      ],
      bottom: PrimaryButton('Submit to CAD', trailingIcon: Icons.send, onPressed: _submit),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip('Inquiry Stage', color: c.textMuted),
              StatusChip('Drafting', color: c.accent, dot: true),
            ],
          ),
          const SizedBox(height: 16),
          _designAssets(c),
          gap,
          _briefingNote(c),
          gap,
          _technicalSpecs(c),
          gap,
          _logistics(),
        ],
      ),
    );
  }

  Widget _designAssets(DhColors c) {
    return DhCard(
      tag: '01/REQ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Design Assets', style: AppText.headlineSm),
          const SizedBox(height: 14),
          if (_refRemoved && _refFile == null)
            UploadBox(
              title: 'Add Reference Image',
              subtitle: 'Pinterest saves, photos or catalog shots',
              icon: Icons.add_photo_alternate_outlined,
              height: 150,
              onTap: _pickRef,
            )
          else
            _ReferenceTile(
              file: _refFile,
              name: _refFile == null ? 'Client_Pinterest.jpg' : _basename(_refFile!),
              onReplace: _pickRef,
              onRemove: () => setState(() {
                _refFile = null;
                _refRemoved = true;
              }),
            ),
          const SizedBox(height: 12),
          UploadBox(
            title: 'Upload Sketch',
            subtitle: 'JPEG, PNG or PDF (Max 10MB)',
            icon: Icons.draw_outlined,
            imagePath: _sketch,
            height: 150,
            onTap: _pickSketch,
            onClear: _sketch == null ? null : () => setState(() => _sketch = null),
          ),
        ],
      ),
    );
  }

  Widget _briefingNote(DhColors c) {
    final saved = !_recording && app.draft.hasVoiceNote;
    final btnColor = _recording ? c.warning : c.danger;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Designer Briefing Note', style: AppText.headlineSm),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
            decoration: BoxDecoration(
              color: c.surfaceLow,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: _recording ? btnColor.withValues(alpha: 0.6) : c.border),
            ),
            child: Row(
              children: [
                Material(
                  color: btnColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleRecording,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Icon(_recording ? Icons.stop : Icons.mic, color: c.isDark ? c.bg : c.surface),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Waveform(animation: _wave, active: _recording, color: c.text),
                ),
                const SizedBox(width: 12),
                Text(Fmt.duration(_rec), style: AppText.monoMd.copyWith(color: _recording ? btnColor : c.textMuted)),
                if (saved)
                  IconButton(
                    tooltip: 'Delete recording',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, size: 18, color: c.textFaint),
                    onPressed: _deleteRecording,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _recording
                ? 'Recording… tap stop to save'
                : saved
                ? 'Voice note attached · ${Fmt.duration(app.draft.voiceNoteLength)}'
                : 'Tap the mic to record a briefing for the designer',
            style: AppText.bodySm.copyWith(color: saved ? c.success : c.textFaint),
          ),
          const SizedBox(height: 14),
          DhTextField(
            value: app.draft.notes,
            maxLines: 3,
            hint: 'Written notes for the CAD designer…',
            onChanged: (v) => app.draft.notes = v,
          ),
        ],
      ),
    );
  }

  Widget _technicalSpecs(DhColors c) {
    final d = app.draft;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Technical Specs', style: AppText.headlineSm),
          const SizedBox(height: 16),
          const _IconLabel(Icons.hardware_outlined, 'Metal Type'),
          const SizedBox(height: 8),
          ChoiceGroup<String>(
            options: _metalSpecs.keys.toList(),
            selected: _metal,
            dense: true,
            onChanged: (v) => setState(() {
              _metal = v;
              _applyMetal(v);
            }),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _LabeledDropdown(
                  icon: Icons.radio_button_unchecked,
                  label: 'Ring Size',
                  value: _size,
                  items: _sizes,
                  onChanged: (v) => setState(() {
                    _size = v;
                    d.ringSize = v.replaceFirst('Size ', '');
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledDropdown(
                  icon: Icons.straighten,
                  label: 'Profile',
                  value: _profile,
                  items: _profiles,
                  onChanged: (v) => setState(() {
                    _profile = v;
                    d.bandProfile = v;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _IconLabel(Icons.diamond_outlined, 'Stone Requirements'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  value: d.stoneType,
                  items: _stoneTypes,
                  onChanged: (v) => setState(() => d.stoneType = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Dropdown(
                  value: d.stoneShape,
                  items: _stoneShapes,
                  enabled: d.stoneType != 'None',
                  onChanged: (v) => setState(() => d.stoneShape = v),
                ),
              ),
            ],
          ),
          if (d.stoneType != 'None') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _carat,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: AppText.monoLg.copyWith(color: c.text),
              decoration: const InputDecoration(
                labelText: 'Est. carat (center)',
                suffixText: 'ct',
                prefixIcon: Icon(Icons.scale_outlined, size: 20),
              ),
              onChanged: (v) => d.stoneCarat = double.tryParse(v),
            ),
          ],
          const SizedBox(height: 12),
          DhTextField(
            value: d.stoneNotes,
            maxLines: 3,
            hint:
                'e.g. Center: 2ct Emerald cut (supplied by customer). Halo: 1.5mm diamonds. '
                'Setting must sit flush with a standard wedding band.',
            onChanged: (v) => d.stoneNotes = v,
          ),
        ],
      ),
    );
  }

  /// Rendered with the dark token set in both themes — the design's navy "Logistics" panel.
  Widget _logistics() {
    final d = app.draft;
    return Theme(
      data: _panelTheme,
      child: Builder(
        builder: (context) {
          final c = context.c;
          final label = AppText.labelSm.copyWith(color: c.textMuted, letterSpacing: 1.2);
          return Material(
            color: c.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: c.border),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [c.gold.withValues(alpha: 0.18), c.gold.withValues(alpha: 0)]),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.gold, width: 1.5)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Logistics', style: AppText.headlineSm.copyWith(color: c.text)),
                      const SizedBox(height: 16),
                      Text('CUSTOMER', style: label),
                      const SizedBox(height: 6),
                      DhTextField(
                        value: d.customer,
                        hint: 'Retailer or client name',
                        prefixIcon: Icons.storefront_outlined,
                        onChanged: (v) => d.customer = v,
                      ),
                      const SizedBox(height: 14),
                      Text('TARGET BUDGET', style: label),
                      const SizedBox(height: 6),
                      DhTextField(
                        value: d.budget == null ? '' : d.budget!.toStringAsFixed(0),
                        hint: '2500',
                        prefixText: r'$ ',
                        mono: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) => d.budget = double.tryParse(v.replaceAll(',', '')),
                      ),
                      const SizedBox(height: 14),
                      Text('DESIRED DATE', style: label),
                      const SizedBox(height: 6),
                      _PanelDateTile(value: d.requestedDelivery, onTap: _pickDate),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({required this.file, required this.name, required this.onReplace, required this.onRemove});

  final String? file;
  final String name;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 210,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Material(
              color: c.surfaceHigh,
              child: InkWell(
                onTap: onReplace,
                child: DhImage(file: file, asset: file == null ? Img.ringEmeraldCutDark : null, radius: 0),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: c.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onReplace,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flip_camera_ios_outlined, size: 16, color: c.text),
                        const SizedBox(width: 6),
                        Text('Replace', style: AppText.labelMd.copyWith(color: c.text)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Ref: $name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.labelMd.copyWith(color: c.text),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Material(
                    color: c.danger,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: SizedBox.square(
                        dimension: 28,
                        child: Icon(Icons.close, size: 16, color: c.isDark ? c.bg : c.surface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.animation, required this.active, required this.color});

  final Animation<double> animation;
  final bool active;
  final Color color;

  static const _pattern = [3, 6, 4, 8, 5, 2, 7, 4, 3, 6, 4, 8, 5, 2, 7];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: LayoutBuilder(
        builder: (context, box) {
          final count = (box.maxWidth / 7).floor().clamp(0, 30);
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < count; i++)
                  Container(
                    width: 4,
                    margin: const EdgeInsets.only(right: 3),
                    height:
                        4.0 *
                        _pattern[i % _pattern.length] *
                        (active ? 0.4 + 0.6 * math.sin(animation.value * math.pi + i * 0.9).abs() : 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: active ? 0.9 : 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(icon, size: 16, color: c.textMuted),
        const SizedBox(width: 8),
        Flexible(
          child: Text(text, style: AppText.labelMd.copyWith(color: c.textMuted)),
        ),
      ],
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.onChanged, this.enabled = true});

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      isExpanded: true,
      borderRadius: BorderRadius.circular(8),
      dropdownColor: c.surface,
      icon: Icon(Icons.expand_more, color: c.textFaint),
      style: AppText.bodyMd.copyWith(color: c.text),
      items: [
        for (final i in items)
          DropdownMenuItem(
            value: i,
            child: Text(i, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null,
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IconLabel(icon, label),
        const SizedBox(height: 8),
        _Dropdown(value: value, items: items, onChanged: onChanged),
      ],
    );
  }
}

class _PanelDateTile extends StatelessWidget {
  const _PanelDateTile({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value == null ? 'mm/dd/yyyy' : Fmt.dateLong(value!),
                  style: AppText.monoMd.copyWith(color: value == null ? c.textFaint : c.text),
                ),
              ),
              Icon(Icons.calendar_today_outlined, size: 18, color: c.gold),
            ],
          ),
        ),
      ),
    );
  }
}

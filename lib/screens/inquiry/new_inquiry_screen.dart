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

/// mm/dd/yyyy, as in the design's date input.
String _numericDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

/// Design's "surface-container" panels: tonal fill, no border, 16px radius.
Color _panelColor(DhColors c) => c.isDark ? c.surface : c.surfaceHigh.withValues(alpha: 0.7);

/// White wells (inputs, chips, player) that sit on a panel.
Color _wellColor(DhColors c) => c.isDark ? c.surfaceLow : c.surface;

/// Tailwind `shadow-sm` for wells on the light theme.
List<BoxShadow>? _softShadow(DhColors c) =>
    c.isDark ? null : [BoxShadow(color: c.text.withValues(alpha: 0.07), blurRadius: 3, offset: const Offset(0, 1))];

class _NewInquiryScreenState extends State<NewInquiryScreen> with SingleTickerProviderStateMixin {
  static final DhColors _panelTokens = DhColors.dark;

  String _metal = '18K Yellow';
  String _size = 'Size 6.0';
  String _profile = 'Comfort Fit';

  /// Name of the piece; becomes the job title when set.
  String _pieceName = '';

  String? _refFile;
  bool _refRemoved = false;
  String? _sketch;
  final _carat = TextEditingController(text: '2.0');
  final _customerCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();

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
    _customerCtrl.dispose();
    _budgetCtrl.dispose();
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
    final name = _pieceName.trim();
    final job = app.createJobFromDraft(title: name.isNotEmpty ? name : '$_metal Custom Ring');
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
          padding: const EdgeInsets.only(right: 12),
          child: TextButton.icon(
            onPressed: _saveDraft,
            style: TextButton.styleFrom(
              backgroundColor: c.surfaceHigh,
              foregroundColor: c.text,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              textStyle: AppText.labelMd,
            ),
            icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
            label: const Text('Save Draft'),
          ),
        ),
      ],
      bottom: PrimaryButton('Submit to CAD', trailingIcon: Icons.send, onPressed: _submit),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          _stageLine(c),
          const SizedBox(height: 16),
          _designAssets(c),
          gap,
          _briefingNote(c),
          gap,
          _technicalSpecs(c),
          gap,
          _logistics(c),
        ],
      ),
    );
  }

  /// "INQUIRY STAGE • DRAFTING" overline.
  Widget _stageLine(DhColors c) {
    final style = AppText.labelSm.copyWith(letterSpacing: 1.6);
    return Row(
      children: [
        Text('INQUIRY STAGE', style: style.copyWith(color: c.textMuted)),
        Container(
          width: 4,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
        ),
        Text('DRAFTING', style: style.copyWith(color: c.accent)),
      ],
    );
  }

  Widget _designAssets(DhColors c) {
    final reference = _refRemoved && _refFile == null
        ? _EmptyAssetTile(
            icon: Icons.add_photo_alternate_outlined,
            title: 'Add Reference',
            subtitle: 'Pinterest saves, photos or catalog shots',
            onTap: _pickRef,
          )
        : _ImageAssetTile(
            file: _refFile,
            asset: _refFile == null ? Img.ringEmeraldCutDark : null,
            label: 'Ref: ${_refFile == null ? 'Client_Pinterest.jpg' : _basename(_refFile!)}',
            onReplace: _pickRef,
            onRemove: () => setState(() {
              _refFile = null;
              _refRemoved = true;
            }),
          );
    final sketch = _sketch == null
        ? _EmptyAssetTile(
            icon: Icons.draw_outlined,
            title: 'Upload Sketch',
            subtitle: 'JPEG, PNG or PDF (Max 10MB)',
            onTap: _pickSketch,
          )
        : _ImageAssetTile(
            file: _sketch,
            label: 'Sketch: ${_basename(_sketch!)}',
            onReplace: _pickSketch,
            onRemove: () => setState(() => _sketch = null),
          );
    return _Panel(
      title: 'Design Assets',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(4)),
        child: Text('01/REQ', style: AppText.monoMd.copyWith(color: c.textMuted)),
      ),
      child: SizedBox(
        height: 200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: reference),
            const SizedBox(width: 12),
            Expanded(child: sketch),
          ],
        ),
      ),
    );
  }

  Widget _briefingNote(DhColors c) {
    final saved = !_recording && app.draft.hasVoiceNote;
    final btnColor = _recording ? c.warning : c.danger;
    return _Panel(
      title: 'Designer Briefing Note',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            decoration: BoxDecoration(
              color: _wellColor(c),
              borderRadius: BorderRadius.circular(40),
              border: _recording ? Border.all(color: btnColor.withValues(alpha: 0.6)) : null,
              boxShadow: _softShadow(c),
            ),
            child: Row(
              children: [
                Material(
                  color: btnColor,
                  shape: const CircleBorder(),
                  elevation: c.isDark ? 0 : 2,
                  shadowColor: btnColor.withValues(alpha: 0.5),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleRecording,
                    child: SizedBox.square(
                      dimension: 48,
                      child: Icon(_recording ? Icons.stop : Icons.mic, color: c.isDark ? c.bg : c.surface),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                  )
                else
                  const SizedBox(width: 4),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _recording
                  ? 'Recording… tap stop to save'
                  : saved
                  ? 'Voice note attached · ${Fmt.duration(app.draft.voiceNoteLength)}'
                  : 'Tap the mic to record a briefing for the designer',
              style: AppText.bodySm.copyWith(color: saved ? c.success : c.textMuted),
            ),
          ),
          const SizedBox(height: 14),
          _WellTextField(
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
    return _Panel(
      title: 'Technical Specs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _IconLabel(Icons.label_outline, 'Piece Name'),
          const SizedBox(height: 12),
          _WellTextField(value: _pieceName, hint: 'e.g. Gold Signet Ring', onChanged: (v) => _pieceName = v),
          const SizedBox(height: 28),
          const _IconLabel(Icons.hardware_outlined, 'Metal Type'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _metalSpecs.keys)
                _MetalChip(
                  label: m,
                  selected: m == _metal,
                  onTap: () => setState(() {
                    _metal = m;
                    _applyMetal(m);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 28),
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
              const SizedBox(width: 16),
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
          const SizedBox(height: 28),
          const _IconLabel(Icons.diamond_outlined, 'Stone Requirements'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Dropdown(
                  value: d.stoneType,
                  items: _stoneTypes,
                  onChanged: (v) => setState(() => d.stoneType = v),
                ),
              ),
              const SizedBox(width: 16),
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
            _Well(
              child: TextField(
                controller: _carat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: AppText.monoLg.copyWith(color: c.text),
                decoration: _wellDecoration(c).copyWith(
                  labelText: 'Est. carat (center)',
                  suffixText: 'ct',
                  prefixIcon: const Icon(Icons.scale_outlined, size: 20),
                ),
                onChanged: (v) => d.stoneCarat = double.tryParse(v),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _WellTextField(
            value: d.stoneNotes,
            maxLines: 4,
            hint:
                'e.g. Center: 2ct Emerald cut (supplied by customer). Halo: 1.5mm diamonds. '
                'Setting must sit flush with a standard wedding band.',
            onChanged: (v) => d.stoneNotes = v,
          ),
        ],
      ),
    );
  }

  /// The design's navy "Logistics" panel (primary-container). Text and wells use the dark token set in both themes.
  Widget _logistics(DhColors c) {
    final d = app.draft;
    final p = _panelTokens;
    final label = AppText.labelSm.copyWith(color: p.text.withValues(alpha: 0.6), letterSpacing: 1.6);
    final mono = AppText.monoMd.copyWith(color: p.text);
    InputDecoration deco(String hint, {Widget? prefix}) => InputDecoration(
      hintText: hint,
      hintStyle: mono.copyWith(color: p.text.withValues(alpha: 0.35)),
      filled: true,
      fillColor: p.text.withValues(alpha: 0.08),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: p.text.withValues(alpha: 0.5)),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceHigh : c.navActive,
        borderRadius: BorderRadius.circular(16),
        border: c.isDark ? Border.all(color: c.border) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [p.text.withValues(alpha: 0.08), p.text.withValues(alpha: 0)]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Logistics', style: _Panel.titleStyle.copyWith(color: p.text.withValues(alpha: 0.6))),
                const SizedBox(height: 20),
                Text('CUSTOMER', style: label),
                const SizedBox(height: 8),
                TextField(
                  controller: _customerCtrl,
                  style: AppText.bodyMd.copyWith(color: p.text),
                  cursorColor: p.text,
                  decoration: deco(
                    'Retailer or client name',
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.storefront_outlined, size: 18, color: p.text.withValues(alpha: 0.7)),
                    ),
                  ).copyWith(hintStyle: AppText.bodyMd.copyWith(color: p.text.withValues(alpha: 0.35))),
                  onChanged: (v) => d.customer = v,
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('TARGET BUDGET', style: label),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _budgetCtrl,
                            style: mono,
                            cursorColor: p.text,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            decoration: deco(
                              '2500',
                              prefix: Padding(
                                padding: const EdgeInsets.only(left: 12, right: 8),
                                child: Text(r'$', style: mono),
                              ),
                            ),
                            onChanged: (v) => d.budget = double.tryParse(v.replaceAll(',', '')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('DESIRED DATE', style: label),
                          const SizedBox(height: 8),
                          Material(
                            color: p.text.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d.requestedDelivery == null ? 'mm/dd/yyyy' : _numericDate(d.requestedDelivery!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: mono.copyWith(
                                          color: d.requestedDelivery == null ? p.text.withValues(alpha: 0.5) : p.text,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.calendar_today_outlined, size: 18, color: p.text),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Borderless well input decoration (white on the tonal panels).
InputDecoration _wellDecoration(DhColors c) {
  final none = OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none);
  return InputDecoration(
    filled: true,
    fillColor: _wellColor(c),
    border: none,
    enabledBorder: none,
    disabledBorder: none,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: c.accent, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  );
}

/// Tonal section panel with a headline and optional trailing widget.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  static const titleStyle = TextStyle(
    fontFamily: AppText.sans,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
  );

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panelColor(c),
        borderRadius: BorderRadius.circular(16),
        border: c.isDark ? Border.all(color: c.border) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: titleStyle.copyWith(color: c.text)),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

/// White well with the design's soft shadow.
class _Well extends StatelessWidget {
  const _Well({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), boxShadow: _softShadow(c)),
      child: child,
    );
  }
}

/// Borderless multi-line text area that keeps its own controller.
class _WellTextField extends StatefulWidget {
  const _WellTextField({required this.value, required this.onChanged, this.hint, this.maxLines = 1});

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;

  @override
  State<_WellTextField> createState() => _WellTextFieldState();
}

class _WellTextFieldState extends State<_WellTextField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Well(
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        maxLines: widget.maxLines,
        style: AppText.bodyMd.copyWith(color: c.text),
        decoration: _wellDecoration(c).copyWith(hintText: widget.hint, hintMaxLines: widget.maxLines),
      ),
    );
  }
}

/// Metal type chip: solid primary when selected, white well otherwise.
class _MetalChip extends StatelessWidget {
  const _MetalChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), boxShadow: _softShadow(c)),
      child: Material(
        color: selected ? c.action : _wellColor(c),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(label, style: AppText.labelMd.copyWith(color: selected ? c.onAction : c.text)),
          ),
        ),
      ),
    );
  }
}

/// Filled image tile with a filename tag and a red remove button.
class _ImageAssetTile extends StatelessWidget {
  const _ImageAssetTile({required this.label, required this.onReplace, required this.onRemove, this.file, this.asset});

  final String? file;
  final String? asset;
  final String label;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: c.surfaceHigh,
            child: InkWell(
              onTap: onReplace,
              child: DhImage(file: file, asset: asset, radius: 0),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: c.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onReplace,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flip_camera_ios_outlined, size: 14, color: c.text),
                      const SizedBox(width: 4),
                      Text('Replace', style: AppText.labelMd.copyWith(color: c.text)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelSm.copyWith(color: c.text, letterSpacing: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: c.danger.withValues(alpha: 0.9),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: SizedBox.square(
                      dimension: 26,
                      child: Icon(Icons.close, size: 14, color: c.isDark ? c.bg : c.surface),
                    ),
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

/// Empty upload tile: recessed fill, round white icon badge, title + format hint.
class _EmptyAssetTile extends StatelessWidget {
  const _EmptyAssetTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.isDark ? c.surfaceLow : c.surfaceHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: _wellColor(c), shape: BoxShape.circle, boxShadow: _softShadow(c)),
                child: Icon(icon, size: 24, color: c.textMuted),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.labelMd.copyWith(color: c.text),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppText.bodySm.copyWith(color: c.textMuted),
              ),
            ],
          ),
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
          final count = (box.maxWidth / 8).floor().clamp(0, 30);
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) => Row(
              children: [
                for (var i = 0; i < count; i++)
                  Container(
                    width: 4,
                    margin: const EdgeInsets.only(right: 4),
                    height:
                        4.0 *
                        _pattern[i % _pattern.length] *
                        (active ? 0.4 + 0.6 * math.sin(animation.value * math.pi + i * 0.9).abs() : 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: active ? 0.9 : 0.4),
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
    return _Well(
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        isExpanded: true,
        borderRadius: BorderRadius.circular(8),
        dropdownColor: c.surface,
        icon: Icon(Icons.expand_more, color: c.textMuted),
        style: AppText.bodyMd.copyWith(color: c.text),
        decoration: _wellDecoration(c).copyWith(contentPadding: const EdgeInsets.fromLTRB(16, 13, 12, 13)),
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
      ),
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
        const SizedBox(height: 12),
        _Dropdown(value: value, items: items, onChanged: onChanged),
      ],
    );
  }
}

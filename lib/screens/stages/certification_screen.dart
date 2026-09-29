import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Gem lab certification tracking with an append-only audit trail
/// ("Digital Thread").
class CertificationScreen extends StatefulWidget {
  const CertificationScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<CertificationScreen> createState() => _CertificationScreenState();
}

class _AuditEntry {
  const _AuditEntry(this.title, this.by, this.when, {this.tracking});

  final String title;
  final String by;
  final String when;
  final String? tracking;
}

class _CertificationScreenState extends State<CertificationScreen> {
  static const _steps = ['Waiting', 'Sent', 'At Lab', 'In Progress', 'Certified', 'Returned'];
  static const _labs = [
    'IGI (International Gemological Institute)',
    'GIA (Gemological Institute of America)',
    'HRD Antwerp',
  ];

  int _status = 3;
  bool _required = true;
  String _lab = _labs.first;
  DateTime? _dateSent = DateTime.now().subtract(const Duration(days: 3));
  final _certNo = TextEditingController();
  String? _certFile;
  bool _certFileSaved = false;
  final List<_AuditEntry> _audit = [
    const _AuditEntry('Status Updated: In Progress', 'System', 'Oct 18, 14:32'),
    const _AuditEntry('Received at Lab', 'IGI Antwerp', 'Oct 17, 09:15'),
    const _AuditEntry('Package Sent', 'Logistics', 'Oct 15, 11:00', tracking: 'FEDEX: 9876543210'),
    const _AuditEntry('Certification Requested', 'Production Mgr', 'Oct 14, 16:45'),
  ];

  @override
  void dispose() {
    _certNo.dispose();
    super.dispose();
  }

  String get _labShort => _lab.split(' ').first;

  bool get _ready => !_required || _status >= 4;

  String _certFileName(Job job) => 'certificate_${_labShort.toLowerCase()}_${job.id}.jpg';

  /// Current form values, saved on the job's Certification stage record.
  Map<String, String> _details(Job job) => {
    'Certification Required': _required ? 'Yes' : 'No',
    if (_required) ...{
      'Laboratory': _lab,
      if (_dateSent != null) 'Date Sent': Fmt.dateLong(_dateSent!),
      'Certificate Number': _certNo.text.trim(),
      if (_certFile != null) 'Certificate File': _certFileName(job),
      'Status': _steps[_status],
    } else
      'Status': 'Not required',
  };

  // ---- Actions ------------------------------------------------------------

  void _setStatus(Job job, int i) {
    if (i == _status) return;
    final label = _steps[i];
    setState(() {
      _status = i;
      _audit.insert(0, _AuditEntry('Status Updated: $label', app.userName, Fmt.dateTime(DateTime.now())));
    });
    app.recordStage(job, JobStage.certification, _details(job));
    app.addEvent(job, title: 'Certification: $label', text: 'Certification status updated to $label ($_labShort).');
    showSnack(context, 'Status updated: $label', icon: Icons.timeline);
  }

  Future<void> _pickCertificate() async {
    final path = await pickImage(context, title: 'Upload Certificate');
    if (path == null || !mounted) return;
    setState(() {
      _certFile = path;
      _certFileSaved = false;
    });
    showSnack(context, 'Certificate attached — tap Save Details to log it', icon: Icons.upload_file);
  }

  void _save(Job job) {
    final parts = <String>[
      if (!_required) 'Certification not required',
      if (_required) _labShort,
      if (_required && _dateSent != null) 'Sent ${Fmt.date(_dateSent!)}',
      if (_required && _certNo.text.trim().isNotEmpty) 'Cert #${_certNo.text.trim()}',
    ];
    final summary = parts.join(' • ');
    final file = _certFile;
    if (_required && file != null && !_certFileSaved) {
      app.addFile(job, ProjectFile(name: _certFileName(job), kind: FileKind.image, localPath: file, jobId: job.id));
      _certFileSaved = true;
    }
    app.recordStage(job, JobStage.certification, _details(job));
    app.addEvent(job, title: 'Certification details saved', text: summary);
    setState(
      () => _audit.insert(0, _AuditEntry('Details Saved: $summary', app.userName, Fmt.dateTime(DateTime.now()))),
    );
    showSnack(context, 'Certification details saved', icon: Icons.save_outlined);
  }

  void _moveToDispatch(Job job) {
    final note = _required
        ? 'Certification ${_steps[_status].toLowerCase()} ($_labShort). Released to dispatch.'
        : 'No certification required. Released to dispatch.';
    app.recordStage(job, JobStage.certification, {
      ..._details(job),
      'Released To Dispatch': Fmt.dateTime(DateTime.now()),
    });
    app.setStage(job, JobStage.dispatch, note: note);
    setState(() => _audit.insert(0, _AuditEntry('Moved to Dispatch', app.userName, Fmt.dateTime(DateTime.now()))));
    showSnack(context, '${job.id} moved to Dispatch', icon: Icons.local_shipping_outlined);
  }

  void _showBlockchain(Job job) {
    final seed = '${job.id}|${_audit.length}|${_audit.first.title}|${_audit.first.when}';
    final hash = _pseudoHash(seed);
    final block = 18400000 + int.parse(hash.substring(2, 7), radix: 16) % 90000;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final c = ctx.c;
        Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(t, style: AppText.labelSm.copyWith(color: c.textFaint)),
        );
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.verified_outlined, color: c.accent),
              const SizedBox(width: 8),
              const Expanded(child: Text('Blockchain Record')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Anchored to the DhanaOS Digital Thread ledger. Records cannot be altered.',
                  style: AppText.bodySm.copyWith(color: c.textMuted),
                ),
                label('TRANSACTION HASH'),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.surfaceLow, borderRadius: BorderRadius.circular(6)),
                  child: SelectableText(hash, style: AppText.monoSm.copyWith(color: c.text)),
                ),
                label('BLOCK'),
                Text(
                  '#${Fmt.money(block, symbol: '')}',
                  style: AppText.monoLg.copyWith(color: c.text),
                ),
                label('RECORD'),
                Text('${job.id} · ${_audit.length} entries', style: AppText.monoMd.copyWith(color: c.text)),
                label('ANCHORED'),
                Text(Fmt.dateTime(DateTime.now()), style: AppText.monoMd.copyWith(color: c.text)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hash));
                Navigator.pop(ctx);
                showSnack(context, 'Transaction hash copied', icon: Icons.copy);
              },
              child: const Text('Copy Hash'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  /// Deterministic 256-bit hex string (FNV-1a rounds) for the mock ledger.
  static String _pseudoHash(String seed) {
    var h = 0x811C9DC5;
    final out = StringBuffer('0x');
    for (var round = 0; round < 8; round++) {
      for (final u in '$seed#$round'.codeUnits) {
        h ^= u;
        h = (h * 0x01000193) & 0xFFFFFFFF;
      }
      out.write(h.toRadixString(16).padLeft(8, '0'));
    }
    return out.toString();
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final job = app.jobOrDefault(widget.jobId);
        final inDispatch = job.stage.index >= JobStage.dispatch.index;
        Widget? bottom;
        if (inDispatch) {
          bottom = SecondaryButton(
            'Open Shipping',
            icon: Icons.local_shipping_outlined,
            onPressed: () => Navigator.pushNamed(context, Routes.shipping, arguments: job.id),
          );
        } else if (_ready) {
          bottom = PrimaryButton(
            'Move to Dispatch',
            icon: Icons.local_shipping_outlined,
            onPressed: () => _moveToDispatch(job),
          );
        }
        return DetailScaffold(
          title: 'Certification',
          subtitle: job.id,
          bottom: bottom,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text('Certification Tracking', style: AppText.display.copyWith(color: c.text)),
              const SizedBox(height: 8),
              Text(
                'Monitor the progress of gemological certifications and upload final documentation. All records '
                'are securely logged to the Digital Thread.',
                style: AppText.bodyLg.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 8),
              Text(
                '${job.title} · ${job.centerStone}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoSm.copyWith(color: c.textFaint),
              ),
              const SizedBox(height: 24),
              _statusCard(job),
              const SizedBox(height: 24),
              _detailsCard(job),
              const SizedBox(height: 24),
              _auditCard(job),
            ],
          ),
        );
      },
    );
  }

  Widget _statusCard(Job job) {
    final c = context.c;
    final done = _status >= 4;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Certification Status', style: AppText.headlineSm.copyWith(fontSize: 20, height: 28 / 20)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: c.navActive, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: done ? c.success : c.accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _steps[_status].toUpperCase(),
                      style: AppText.labelSm.copyWith(color: c.isDark ? c.gold : c.textFaint, letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _CertStepper(steps: _steps, current: _status, onTap: (i) => _setStatus(job, i)),
          const SizedBox(height: 10),
          Text(
            'Tap a step to update the status.',
            textAlign: TextAlign.center,
            style: AppText.bodySm.copyWith(color: c.textFaint),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(Job job) {
    final c = context.c;
    final now = DateTime.now();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Certification Details', style: AppText.headlineSm.copyWith(fontSize: 20, height: 28 / 20)),
          const SizedBox(height: 24),
          _FormField(
            label: 'Certification Required',
            child: DhSegmented<bool>(
              options: const [true, false],
              selected: _required,
              labelOf: (v) => v ? 'Yes' : 'No',
              onChanged: (v) => setState(() => _required = v),
            ),
          ),
          if (!_required) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _fieldFill(c), borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: c.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No lab certification required for this piece. It can move straight to dispatch.',
                      style: AppText.bodySm.copyWith(color: c.text),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            _FormField(
              label: 'Laboratory',
              child: _Raised(
                child: DropdownButtonFormField<String>(
                  initialValue: _lab,
                  isExpanded: true,
                  icon: Icon(Icons.expand_more, color: c.textMuted),
                  dropdownColor: c.surface,
                  borderRadius: BorderRadius.circular(8),
                  style: AppText.bodySm.copyWith(color: c.text, fontSize: 14),
                  decoration: _fieldDecoration(c),
                  items: [
                    for (final l in _labs)
                      DropdownMenuItem(
                        value: l,
                        child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _lab = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            _FormField(
              label: 'Date Sent',
              child: _DateInput(
                value: _dateSent,
                firstDate: DateTime(now.year - 1, now.month, now.day),
                lastDate: now.add(const Duration(days: 30)),
                onChanged: (d) => setState(() => _dateSent = d),
              ),
            ),
            const SizedBox(height: 24),
            _FormField(
              label: 'Certificate Number (Optional)',
              child: _Raised(
                child: TextField(
                  controller: _certNo,
                  keyboardType: TextInputType.number,
                  style: AppText.monoMd.copyWith(color: c.text),
                  decoration: _fieldDecoration(c).copyWith(hintText: 'e.g. 1234567890'),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _FormField(
              label: 'Upload Certificate (PDF)',
              child: _certFile != null
                  ? UploadBox(
                      title: 'Certificate',
                      height: 170,
                      imagePath: _certFile,
                      onTap: _pickCertificate,
                      onClear: () => setState(() {
                        _certFile = null;
                        _certFileSaved = false;
                      }),
                    )
                  : _CertDropZone(onTap: _pickCertificate),
            ),
          ],
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                boxShadow: c.isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: FilledButton(
                onPressed: () => _save(job),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  textStyle: AppText.labelMd.copyWith(fontSize: 14),
                ),
                child: const Text('Save Details'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditCard(Job job) {
    final c = context.c;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.isDark ? c.goldSoft : c.navActive,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.timeline, size: 20, color: c.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Digital Thread', style: AppText.headlineSm.copyWith(fontSize: 20, height: 26 / 20)),
                    Text(
                      'Immutable Audit Trail',
                      style: AppText.labelSm.copyWith(color: c.textMuted, letterSpacing: 0.55),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: c.isDark ? c.border : c.surfaceHighest, height: 1),
          const SizedBox(height: 24),
          for (var i = 0; i < _audit.length; i++)
            _ThreadTile(entry: _audit[i], latest: i == 0, isLast: i == _audit.length - 1, panel: _panelColor(c)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _showBlockchain(job),
            style: OutlinedButton.styleFrom(
              backgroundColor: _fieldFill(c),
              foregroundColor: c.isDark ? c.gold : c.text,
              minimumSize: const Size(double.infinity, 44),
              side: BorderSide(color: c.isDark ? c.border : c.surfaceHighest),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              textStyle: AppText.labelMd.copyWith(fontSize: 13),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.verified_outlined, size: 18), SizedBox(width: 8), Text('View Blockchain Record')],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Pieces ----------------------------------------------------------------

/// Card surface ("surface-container") behind each section.
Color _panelColor(DhColors c) => c.isDark ? c.surface : c.surfaceHigh;

/// Input fill that sits on a [_Panel].
Color _fieldFill(DhColors c) => c.isDark ? c.bg : c.surface;

InputDecoration _fieldDecoration(DhColors c) {
  const none = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4)), borderSide: BorderSide.none);
  return InputDecoration(
    filled: true,
    fillColor: _fieldFill(c),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    border: none,
    enabledBorder: none,
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: c.accent, width: 2),
    ),
    hintStyle: AppText.bodySm.copyWith(color: c.textFaint, fontSize: 14),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panelColor(c),
        borderRadius: BorderRadius.circular(8),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: child,
    );
  }
}

/// Sentence-case field label above an input.
class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.labelMd.copyWith(color: context.c.text)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Soft shadow under a borderless input.
class _Raised extends StatelessWidget {
  const _Raised({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: context.c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: child,
    );
  }
}

/// Borderless date input with a trailing calendar icon.
class _DateInput extends StatelessWidget {
  const _DateInput({required this.value, required this.onChanged, required this.firstDate, required this.lastDate});

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Raised(
      child: Material(
        color: _fieldFill(c),
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () async {
            var first = firstDate;
            var last = lastDate;
            final initial = value ?? DateTime.now();
            if (initial.isBefore(first)) first = initial;
            if (initial.isAfter(last)) last = initial;
            final d = await showDatePicker(context: context, initialDate: initial, firstDate: first, lastDate: last);
            if (d != null) onChanged(d);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value == null ? 'Select date' : Fmt.dateLong(value!),
                    style: value == null
                        ? AppText.bodySm.copyWith(color: c.textFaint, fontSize: 14)
                        : AppText.monoMd.copyWith(color: c.text),
                  ),
                ),
                Icon(Icons.calendar_month_outlined, size: 22, color: c.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed "Click to upload or drag and drop" zone.
class _CertDropZone extends StatelessWidget {
  const _CertDropZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // DashedBorder paints behind its child, so the fill sits outside it.
    return DecoratedBox(
      decoration: BoxDecoration(color: _fieldFill(c), borderRadius: BorderRadius.circular(8)),
      child: DashedBorder(
        radius: 8,
        strokeWidth: 2,
        color: c.borderStrong,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.isDark ? c.goldSoft : c.navActive,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.upload_file, size: 24, color: c.isDark ? c.gold : c.surface),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Click to upload',
                          style: TextStyle(fontWeight: FontWeight.w600, color: c.isDark ? c.gold : c.action),
                        ),
                        const TextSpan(text: ' or drag and drop'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: AppText.bodyMd.copyWith(color: c.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PDF, JPG, or PNG (max. 10MB)',
                    textAlign: TextAlign.center,
                    style: AppText.bodySm.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry of the Digital Thread: small dot on a hairline rail.
class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.entry, required this.latest, required this.isLast, required this.panel});

  final _AuditEntry entry;
  final bool latest;
  final bool isLast;
  final Color panel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rail = c.isDark ? c.borderStrong : c.borderStrong.withValues(alpha: 0.6);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: latest ? 8 : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 10 : null,
                  child: Container(width: 2, color: rail),
                ),
                Positioned(
                  left: 4,
                  top: 1,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: panel, shape: BoxShape.circle),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: latest ? c.action : rail, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, style: AppText.labelMd.copyWith(color: c.text, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('${entry.by} • ${entry.when}', style: AppText.bodySm.copyWith(color: c.textMuted)),
                  if (entry.tracking != null) ...[const SizedBox(height: 8), _TrackingTag(entry.tracking!)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingTag extends StatelessWidget {
  const _TrackingTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _fieldFill(c),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: c.accent, width: 2)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 16, color: c.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.monoMd.copyWith(color: c.textMuted)),
          ),
        ],
      ),
    );
  }
}

/// Horizontal status stepper. Labels alternate below / above the track so
/// six steps fit on a 360dp screen without truncation.
class _CertStepper extends StatelessWidget {
  const _CertStepper({required this.steps, required this.current, required this.onTap});

  final List<String> steps;
  final int current;
  final ValueChanged<int> onTap;

  static const _labelH = 16.0;
  static const _dot = 24.0;
  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final n = steps.length;
        final cell = w / n;
        final lw = math.min(cell * 2 - 8, 120.0);
        const dotTop = _labelH + _gap;
        const trackTop = dotTop + _dot / 2 - 2;
        double cx(int i) => cell * (i + 0.5);
        return SizedBox(
          height: dotTop + _dot + _gap + _labelH,
          child: Stack(
            children: [
              Positioned(
                left: cx(0),
                width: cx(n - 1) - cx(0),
                top: trackTop,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.surfaceHighest, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Positioned(
                left: cx(0),
                width: cx(current) - cx(0),
                top: trackTop,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.action, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              for (var i = 0; i < n; i++) Positioned(left: cx(i) - _dot / 2, top: dotTop, child: _node(c, i)),
              for (var i = 0; i < n; i++) _label(c, i, cx(i), lw, w),
              for (var i = 0; i < n; i++)
                Positioned(
                  left: cell * i,
                  width: cell,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTap(i)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(DhColors c, int i, double center, double lw, double w) {
    var left = center - lw / 2;
    var align = TextAlign.center;
    if (left < 0) {
      left = 0;
      align = TextAlign.left;
    } else if (left + lw > w) {
      left = w - lw;
      align = TextAlign.right;
    }
    final color = i == current ? c.action : (i < current ? c.text : c.textMuted);
    return Positioned(
      left: left,
      width: lw,
      top: i.isOdd ? 0 : _labelH + _gap + _dot + _gap,
      child: Text(
        steps[i].toUpperCase(),
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.labelSm.copyWith(
          color: color,
          letterSpacing: 0.8,
          fontWeight: i == current ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _node(DhColors c, int i) {
    final shadow = c.isDark
        ? null
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))];
    if (i < current) {
      return Container(
        width: _dot,
        height: _dot,
        decoration: BoxDecoration(color: c.action, shape: BoxShape.circle, boxShadow: shadow),
        child: Icon(Icons.check, size: 13, color: c.onAction),
      );
    }
    if (i == current) {
      return Container(
        width: _dot,
        height: _dot,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _panelColor(c),
          shape: BoxShape.circle,
          border: Border.all(color: c.action, width: 2),
          boxShadow: [BoxShadow(color: c.action.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c.action, shape: BoxShape.circle),
        ),
      );
    }
    return Container(
      width: _dot,
      height: _dot,
      decoration: BoxDecoration(color: c.surfaceHighest, shape: BoxShape.circle),
    );
  }
}

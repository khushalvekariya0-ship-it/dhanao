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
  String _certNo = '';
  String? _certFile;
  bool _certFileSaved = false;
  final List<_AuditEntry> _audit = [
    const _AuditEntry('Status Updated: In Progress', 'System', 'Oct 18, 14:32'),
    const _AuditEntry('Received at Lab', 'IGI Antwerp', 'Oct 17, 09:15'),
    const _AuditEntry('Package Sent', 'Logistics', 'Oct 15, 11:00', tracking: 'FEDEX: 9876543210'),
    const _AuditEntry('Certification Requested', 'Production Mgr', 'Oct 14, 16:45'),
  ];

  String get _labShort => _lab.split(' ').first;

  bool get _ready => !_required || _status >= 4;

  // ---- Actions ------------------------------------------------------------

  void _setStatus(Job job, int i) {
    if (i == _status) return;
    final label = _steps[i];
    setState(() {
      _status = i;
      _audit.insert(0, _AuditEntry('Status Updated: $label', app.userName, Fmt.dateTime(DateTime.now())));
    });
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
      if (_required && _certNo.trim().isNotEmpty) 'Cert #${_certNo.trim()}',
    ];
    final summary = parts.join(' • ');
    final file = _certFile;
    if (_required && file != null && !_certFileSaved) {
      app.addFile(
        job,
        ProjectFile(
          name: 'certificate_${_labShort.toLowerCase()}_${job.id}.jpg',
          kind: FileKind.image,
          localPath: file,
          jobId: job.id,
        ),
      );
      _certFileSaved = true;
    }
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
              const Text('Certification Tracking', style: AppText.headlineLg),
              const SizedBox(height: 6),
              Text(
                'Monitor the progress of gemological certifications and upload final documentation. All records '
                'are securely logged to the Digital Thread.',
                style: AppText.bodyMd.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 6),
              Text(
                '${job.title} · ${job.centerStone}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.monoSm.copyWith(color: c.textFaint),
              ),
              const SizedBox(height: 20),
              _statusCard(job),
              const SizedBox(height: 16),
              _detailsCard(job),
              const SizedBox(height: 16),
              _auditCard(job),
            ],
          ),
        );
      },
    );
  }

  Widget _statusCard(Job job) {
    final c = context.c;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Certification Status', style: AppText.headlineSm)),
              const SizedBox(width: 8),
              StatusChip(_steps[_status], color: _status >= 4 ? c.success : c.accent, dot: true),
            ],
          ),
          const SizedBox(height: 18),
          _CertStepper(steps: _steps, current: _status, onTap: (i) => _setStatus(job, i)),
          const SizedBox(height: 6),
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
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Certification Details', style: AppText.headlineSm),
          const SizedBox(height: 16),
          Field(
            label: 'Certification Required',
            child: DhSegmented<bool>(
              options: const [true, false],
              selected: _required,
              labelOf: (v) => v ? 'Yes' : 'No',
              onChanged: (v) => setState(() => _required = v),
            ),
          ),
          if (!_required) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surfaceLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.border),
              ),
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
            const SizedBox(height: 18),
            Field(
              label: 'Laboratory',
              child: ChoiceGroup<String>(
                options: _labs,
                selected: _lab,
                columns: 1,
                onChanged: (v) => setState(() => _lab = v),
              ),
            ),
            const SizedBox(height: 18),
            Field(
              label: 'Date Sent',
              child: DateField(
                value: _dateSent,
                firstDate: DateTime(now.year - 1, now.month, now.day),
                lastDate: now.add(const Duration(days: 30)),
                onChanged: (d) => setState(() => _dateSent = d),
              ),
            ),
            const SizedBox(height: 18),
            Field(
              label: 'Certificate Number (Optional)',
              child: DhTextField(value: _certNo, hint: 'e.g. 1234567890', mono: true, onChanged: (v) => _certNo = v),
            ),
            const SizedBox(height: 18),
            Field(
              label: 'Upload Certificate (PDF)',
              child: UploadBox(
                title: 'Click to upload or drag and drop',
                subtitle: 'PDF, JPG, or PNG (max. 10MB)',
                icon: Icons.upload_file,
                filledIcon: true,
                height: 150,
                imagePath: _certFile,
                onTap: _pickCertificate,
                onClear: () => setState(() {
                  _certFile = null;
                  _certFileSaved = false;
                }),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              'Save Details',
              expanded: false,
              icon: Icons.save_outlined,
              onPressed: () => _save(job),
            ),
          ),
        ],
      ),
    );
  }

  Widget _auditCard(Job job) {
    final c = context.c;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.goldSoft, shape: BoxShape.circle),
                child: Icon(Icons.timeline, size: 20, color: c.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Digital Thread', style: AppText.headlineSm),
                    Text('IMMUTABLE AUDIT TRAIL', style: AppText.labelSm.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 16),
          for (var i = 0; i < _audit.length; i++)
            PipelineTile(
              title: _audit[i].title,
              subtitle: '${_audit[i].by} • ${_audit[i].when}',
              state: i == 0 ? PipelineState.current : PipelineState.done,
              isLast: i == _audit.length - 1,
              child: _audit[i].tracking == null ? null : _TrackingTag(_audit[i].tracking!),
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => _showBlockchain(job),
            icon: Icon(Icons.verified_outlined, size: 18, color: c.accent),
            label: const Text('View Blockchain Record'),
          ),
        ],
      ),
    );
  }
}

// ---- Pieces ----------------------------------------------------------------

class _TrackingTag extends StatelessWidget {
  const _TrackingTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.isDark ? c.surfaceLow : c.bg,
        borderRadius: BorderRadius.circular(6),
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
    final color = i == current ? c.accent : (i < current ? c.text : c.textFaint);
    return Positioned(
      left: left,
      width: lw,
      top: i.isOdd ? 0 : _labelH + _gap + _dot + _gap,
      child: Text(
        steps[i].toUpperCase(),
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.labelSm.copyWith(color: color, fontWeight: i == current ? FontWeight.w800 : FontWeight.w600),
      ),
    );
  }

  Widget _node(DhColors c, int i) {
    if (i < current) {
      return Container(
        width: _dot,
        height: _dot,
        decoration: BoxDecoration(color: c.action, shape: BoxShape.circle),
        child: Icon(Icons.check, size: 14, color: c.onAction),
      );
    }
    if (i == current) {
      return Container(
        width: _dot,
        height: _dot,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.surface,
          shape: BoxShape.circle,
          border: Border.all(color: c.accent, width: 2),
          boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 10)],
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
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

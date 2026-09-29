import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Final commercial checkpoint: itemized quote, total and approval.
class PricingApprovalScreen extends StatefulWidget {
  const PricingApprovalScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<PricingApprovalScreen> createState() => _PricingApprovalScreenState();
}

class _QuoteLine {
  _QuoteLine(this.category, this.description, this.amount, this.icon);

  final String category;
  final String description;
  double amount;
  final IconData icon;
}

class _PricingApprovalScreenState extends State<PricingApprovalScreen> {
  late final List<_QuoteLine> _lines;
  late final double _quoted;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    _lines = _buildLines(app.jobOrDefault(widget.jobId));
    _quoted = _total;
  }

  static List<_QuoteLine> _buildLines(Job job) {
    final grams = (job.weightGrams ?? 14.2).toStringAsFixed(1);
    return [
      _QuoteLine('Metal', '${job.metal} (${grams}g)', 2100, Icons.diamond_outlined),
      _QuoteLine('Gemstones', 'Center Sapphire (1.2ct), Side Diamonds (0.5ct tw)', 1200, Icons.star_outline),
      _QuoteLine('Labor', 'Master Crafter - Assembly & Polish', 800, Icons.build_outlined),
      _QuoteLine('Setting', 'Micro-pave & Prong Setting', 400, Icons.precision_manufacturing_outlined),
      _QuoteLine('Certification', 'GIA & Third-party Appraisal', 350, Icons.workspace_premium_outlined),
    ];
  }

  double get _total => _lines.fold(0, (s, l) => s + l.amount);

  // ---- Actions ------------------------------------------------------------

  Future<void> _editLine(_QuoteLine line) async {
    if (_approved) {
      showSnack(context, 'The quote is locked after approval', icon: Icons.lock_outline);
      return;
    }
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(label: line.category, initial: line.amount),
    );
    if (value == null || !mounted) return;
    setState(() => line.amount = value);
    showSnack(context, '${line.category} updated to ${Fmt.money(value)}', icon: Icons.edit_outlined);
  }

  Future<void> _requestChanges(Job job) async {
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NoteSheet(
        title: 'Request Changes',
        subtitle: 'The pricing team will revise the quote and notify you.',
        hint: 'e.g. Reduce labor estimate, switch to 14K...',
        action: 'Send Request',
      ),
    );
    if (note == null || !mounted) return;
    app.addEvent(job, title: 'Quote changes requested', text: note);
    showSnack(context, 'Change request sent for ${job.id}', icon: Icons.send_outlined);
  }

  Future<void> _approve(Job job) async {
    final total = _total;
    final ok = await confirmDialog(
      context,
      title: 'Approve Design & Price?',
      message: 'You authorize manufacturing of ${job.id} at ${Fmt.money(total)}. The quote will be locked.',
      confirm: 'Approve',
    );
    if (!ok || !mounted) return;
    job.value = total;
    if (job.stage.isBefore(JobStage.wax)) {
      app.setStage(job, JobStage.wax, note: 'Quote approved. Released to manufacturing.');
    } else {
      app.addEvent(job, title: 'Quote approved', text: 'Final quote of ${Fmt.money(total)} approved.');
    }
    setState(() => _approved = true);
    showSnack(context, 'Approved for manufacturing · ${Fmt.money(total)}', icon: Icons.verified_outlined);
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final job = app.jobOrDefault(widget.jobId);
        return DetailScaffold(
          title: 'Pricing Approval',
          subtitle: job.id,
          bottom: _approved
              ? PrimaryButton(
                  'Track Production',
                  icon: Icons.route_outlined,
                  onPressed: () => Navigator.pushNamed(context, Routes.tracker, arguments: job.id),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Header(job: job, approved: _approved),
              const SizedBox(height: 28),
              _quoteCard(),
              const SizedBox(height: 24),
              _CheckpointCard(
                job: job,
                approved: _approved,
                total: _total,
                onApprove: () => _approve(job),
                onRequestChanges: () => _requestChanges(job),
              ),
              const SizedBox(height: 24),
              _ProductionStatus(approved: _approved),
            ],
          ),
        );
      },
    );
  }

  Widget _quoteCard() {
    final c = context.c;
    final total = _total;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Itemized Quote', style: AppText.headlineMd.copyWith(color: c.text)),
              ),
              if (_approved)
                Icon(Icons.lock_outline, size: 18, color: c.textFaint)
              else
                Text('Tap a line to edit', style: AppText.bodySm.copyWith(color: c.textFaint)),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _lines.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.borderStrong.withValues(alpha: 0.3))),
              ),
              child: _QuoteRow(line: _lines[i], onTap: () => _editLine(_lines[i])),
            ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.action, borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                Text('Total', style: AppText.headlineLg.copyWith(color: c.onAction)),
                const SizedBox(width: 12),
                Expanded(
                  child: FittedBox(
                    alignment: Alignment.centerRight,
                    fit: BoxFit.scaleDown,
                    child: Text(Fmt.money(total), style: AppText.display.copyWith(color: c.onAction)),
                  ),
                ),
              ],
            ),
          ),
          if (total != _quoted) ...[
            const SizedBox(height: 8),
            Text(
              'Adjusted from ${Fmt.money(_quoted)} (${total > _quoted ? '+' : ''}${Fmt.money(total - _quoted)})',
              textAlign: TextAlign.right,
              style: AppText.monoSm.copyWith(color: c.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Sections --------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.job, required this.approved});

  final Job job;
  final bool approved;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUOTE REVIEW', style: AppText.labelMd.copyWith(color: c.isDark ? c.gold : c.text, letterSpacing: 2.4)),
        const SizedBox(height: 8),
        Text('Final Approval', style: AppText.display.copyWith(color: c.text)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined, size: 22, color: c.accent),
                const SizedBox(width: 8),
                Text(
                  'Job #${job.id}',
                  style: AppText.headlineSm.copyWith(color: c.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            approved
                ? StatusChip('Approved for Manufacturing', color: c.success, icon: Icons.check)
                : StatusChip('Awaiting Approval', color: c.accent, dot: true),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${job.title} · ${job.customer}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppText.bodySm.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.line, required this.onTap});

  final _QuoteLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.navActive, borderRadius: BorderRadius.circular(4)),
              child: Icon(line.icon, size: 22, color: c.isDark ? c.onNavActive : c.textFaint),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.category, style: AppText.headlineSm.copyWith(color: c.text)),
                  const SizedBox(height: 2),
                  Text(line.description, style: AppText.bodySm.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(Fmt.money(line.amount), style: AppText.headlineSm.copyWith(color: c.text)),
          ],
        ),
      ),
    );
  }
}

class _CheckpointCard extends StatelessWidget {
  const _CheckpointCard({
    required this.job,
    required this.approved,
    required this.total,
    required this.onApprove,
    required this.onRequestChanges,
  });

  final Job job;
  final bool approved;
  final double total;
  final VoidCallback onApprove;
  final VoidCallback onRequestChanges;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tile = approved ? c.success : c.accent;
    return _Panel(
      shadow: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(12)),
            child: Icon(approved ? Icons.verified : Icons.gavel, size: 40, color: approved ? c.surface : c.onAccent),
          ),
          const SizedBox(height: 16),
          Text(
            approved ? 'Approved for Manufacturing' : 'Commercial Checkpoint',
            textAlign: TextAlign.center,
            style: AppText.headlineMd.copyWith(color: c.text),
          ),
          const SizedBox(height: 8),
          Text(
            approved
                ? 'Design and price locked at ${Fmt.money(total)}. ${job.id} is released to manufacturing.'
                : 'By approving, you authorize the start of manufacturing based on the agreed design and price.',
            textAlign: TextAlign.center,
            style: AppText.bodyMd.copyWith(color: c.textMuted),
          ),
          if (!approved) ...[
            const SizedBox(height: 28),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: c.isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: FilledButton(
                onPressed: onApprove,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: AppText.labelMd.copyWith(fontSize: 15),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 22),
                    SizedBox(width: 8),
                    Flexible(child: Text('Approve Design & Price', overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRequestChanges,
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text('Request Changes'),
              style: TextButton.styleFrom(
                foregroundColor: c.textMuted,
                minimumSize: const Size(0, 44),
                textStyle: AppText.labelMd.copyWith(fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "surface-container" card used by every section.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(20), this.shadow = false});

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Stronger (shadow-md) elevation.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.isDark ? c.surface : c.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: c.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: shadow ? 0.08 : 0.05),
                  blurRadius: shadow ? 8 : 2,
                  offset: Offset(0, shadow ? 3 : 1),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _ProductionStatus extends StatelessWidget {
  const _ProductionStatus({required this.approved});

  final bool approved;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Panel(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRODUCTION STATUS',
            style: AppText.labelMd.copyWith(color: c.isDark ? c.gold : c.text, fontSize: 13, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          const _StatusStep('Design Review', PipelineState.done),
          const SizedBox(height: 16),
          _StatusStep('Awaiting Approval', approved ? PipelineState.done : PipelineState.current),
          const SizedBox(height: 16),
          _StatusStep(
            'Approved for Manufacturing',
            approved ? PipelineState.current : PipelineState.pending,
            color: approved ? c.success : null,
          ),
        ],
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep(this.label, this.state, {this.color});

  final String label;
  final PipelineState state;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = color ?? c.accent;
    Widget dot;
    TextStyle style;
    switch (state) {
      case PipelineState.done:
        dot = SizedBox(
          width: 18,
          height: 18,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: c.textFaint.withValues(alpha: 0.5), shape: BoxShape.circle),
            ),
          ),
        );
        style = AppText.bodyLg.copyWith(color: c.text.withValues(alpha: 0.5));
      case PipelineState.current:
        dot = SizedBox(
          width: 18,
          height: 18,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), spreadRadius: 4)],
              ),
            ),
          ),
        );
        style = AppText.headlineSm.copyWith(color: accent);
      case PipelineState.pending:
        dot = SizedBox(
          width: 18,
          height: 18,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.textFaint.withValues(alpha: 0.5)),
              ),
            ),
          ),
        );
        style = AppText.bodyLg.copyWith(color: c.text.withValues(alpha: 0.5));
    }
    return Row(
      children: [
        dot,
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: style)),
      ],
    );
  }
}

// ---- Dialogs & sheets ------------------------------------------------------

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.label, required this.initial});

  final String label;
  final double initial;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial.toStringAsFixed(0));
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '').trim());
    if (v == null || v < 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      title: Text('Edit ${widget.label}'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: AppText.monoLg.copyWith(color: c.text),
        decoration: InputDecoration(prefixText: r'$ ', labelText: 'Amount (USD)', errorText: _error),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textMuted)),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.title, required this.hint, required this.action, this.subtitle});

  final String title;
  final String? subtitle;
  final String hint;
  final String action;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppText.headlineSm),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(widget.subtitle!, style: AppText.bodySm.copyWith(color: c.textMuted)),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.bodyMd.copyWith(color: c.text),
                decoration: InputDecoration(hintText: widget.hint),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _ctrl,
                builder: (context, v, _) => PrimaryButton(
                  widget.action,
                  icon: Icons.send_outlined,
                  onPressed: v.text.trim().isEmpty ? null : () => Navigator.pop(context, v.text.trim()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

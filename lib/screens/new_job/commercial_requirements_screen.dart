import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

class CommercialRequirementsScreen extends StatefulWidget {
  const CommercialRequirementsScreen({super.key});

  @override
  State<CommercialRequirementsScreen> createState() => _CommercialRequirementsScreenState();
}

class _CommercialRequirementsScreenState extends State<CommercialRequirementsScreen> {
  JobDraft get d => app.draft;

  Future<void> _editAmount(
    String title,
    double initial,
    void Function(double) apply, {
    bool integer = false,
    String prefix = r'$',
  }) async {
    final v = await showDialog<double>(
      context: context,
      builder: (_) => _AmountDialog(title: title, initial: initial, integer: integer, prefix: prefix),
    );
    if (v != null && mounted) setState(() => apply(v));
  }

  Future<void> _editLine([CostLine? line]) async {
    final res = await showDialog<_LineEdit>(
      context: context,
      builder: (_) => _CostLineDialog(line: line),
    );
    if (res == null || !mounted) return;
    setState(() {
      if (res.delete) {
        d.costs.remove(line);
      } else if (line == null) {
        d.costs.add(CostLine(res.label, res.amount));
      } else {
        line
          ..label = res.label
          ..amount = res.amount;
      }
    });
    if (res.delete) showSnack(context, 'Removed ${res.label}', icon: Icons.delete_outline);
  }

  void _removeLine(CostLine line) {
    setState(() => d.costs.remove(line));
    showSnack(context, 'Removed ${line.label}', icon: Icons.delete_outline);
  }

  void _setQty(int q) => setState(() => d.quantity = q.clamp(1, 9999).toInt());

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return WizardScaffold(
      title: 'Step 2: Resource Allocation',
      step: 2,
      totalSteps: 4,
      stepLabel: 'Commercials',
      badge: 'Draft',
      ctaLabel: 'Continue to Delivery',
      onCta: () => Navigator.pushNamed(context, Routes.delivery),
      children: [
        Wrap(spacing: 8, runSpacing: 8, children: [_Tag('Bespoke ${d.productCategory}'), _Tag(d.jobType)]),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.info_outline, size: 16, color: c.textFaint),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Manufacturing decisions should remain within this approved commercial envelope.',
                style: AppText.bodyMd.copyWith(color: c.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DhCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Field(
                label: 'Customer',
                child: DhTextField(
                  value: d.customer,
                  hint: 'Customer / retailer name',
                  prefixIcon: Icons.storefront_outlined,
                  onChanged: (v) => setState(() => d.customer = v),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('QUANTITY', style: AppText.labelSm.copyWith(color: c.textMuted)),
                        const SizedBox(height: 2),
                        Text('Units in this order', style: AppText.bodySm.copyWith(color: c.textFaint)),
                      ],
                    ),
                  ),
                  _QtyStepper(
                    value: d.quantity,
                    onChanged: _setQty,
                    onTapValue: () => _editAmount(
                      'Quantity',
                      d.quantity.toDouble(),
                      (v) => d.quantity = v.round().clamp(1, 9999).toInt(),
                      integer: true,
                      prefix: '',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Pricing Basis', style: AppText.headlineSm),
        const SizedBox(height: 12),
        DhSegmented<String>(
          options: const ['Fixed Quote', 'Cost Plus'],
          selected: d.pricingBasis,
          onChanged: (v) => setState(() => d.pricingBasis = v),
        ),
        const SizedBox(height: 8),
        Text(
          d.pricingBasis == 'Cost Plus'
              ? 'Billed at actual material and labour cost plus the agreed margin.'
              : 'Unit price is locked at quote; overruns stay with the manufacturer.',
          style: AppText.bodySm.copyWith(color: c.textFaint),
        ),
        const SizedBox(height: 24),
        Text('Materials', style: AppText.headlineSm),
        const SizedBox(height: 12),
        _MaterialCard(
          icon: Icons.hexagon_outlined,
          title: 'Metal',
          subtitle: d.metalLabel,
          chip: StatusChip('Locked Rate', color: c.accent, mono: false),
          leftLabel: 'Supplied by',
          leftValue: d.customerSuppliedMetal ? 'Client' : 'House',
          rightLabel: 'Market rate (oz)',
          rightValue: Fmt.money(d.metalMarketRate, cents: true),
          onEdit: () => _editAmount('Market Rate (per oz)', d.metalMarketRate, (v) => d.metalMarketRate = v),
        ),
        const SizedBox(height: 12),
        _MaterialCard(
          icon: Icons.diamond_outlined,
          title: 'Center Stone',
          subtitle: d.stoneLabel,
          chip: d.stoneSupplied
              ? StatusChip('Client Owned', color: c.gold, mono: false)
              : StatusChip('To Source', color: c.info, mono: false),
          leftLabel: 'Supplied by',
          leftValue: d.stoneSupplied ? 'Client' : 'House (sourcing)',
          rightLabel: 'Declared value',
          rightValue: Fmt.money(d.declaredStoneValue, cents: true),
          onEdit: () => _editAmount('Declared Stone Value', d.declaredStoneValue, (v) => d.declaredStoneValue = v),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Text('Manufacturing', style: AppText.headlineSm)),
            Text(
              '${d.costs.length} LINE${d.costs.length == 1 ? '' : 'S'}',
              style: AppText.monoCaps.copyWith(color: c.textFaint),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _costsCard(c),
        const SizedBox(height: 6),
        Text('Tap a line to edit, swipe left to remove.', style: AppText.bodySm.copyWith(color: c.textFaint)),
        const SizedBox(height: 24),
        _EnvelopeCard(
          draft: d,
          onEditTarget: () => _editAmount('Target Unit Price', d.targetUnitPrice, (v) => d.targetUnitPrice = v),
          onEditMax: () => _editAmount('Max Approved Price', d.maxApprovedPrice, (v) => d.maxApprovedPrice = v),
        ),
      ],
    );
  }

  Widget _costsCard(DhColors c) {
    return DhCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (d.costs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No manufacturing lines yet. Add CAD, setting, finishing or certification costs.',
                style: AppText.bodySm.copyWith(color: c.textFaint),
              ),
            ),
          for (final line in d.costs) ...[
            Dismissible(
              key: ObjectKey(line),
              direction: DismissDirection.endToStart,
              background: Container(
                color: c.dangerSoft,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: Icon(Icons.delete_outline, color: c.danger),
              ),
              onDismissed: (_) => _removeLine(line),
              child: InkWell(
                onTap: () => _editLine(line),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyMd.copyWith(color: c.textMuted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(Fmt.money(line.amount, cents: true), style: AppText.monoMd.copyWith(color: c.text)),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: c.textFaint),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _editLine(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add line'),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: c.isDark ? c.surfaceHigh : c.surfaceLow,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('SUBTOTAL', style: AppText.labelSm.copyWith(color: c.textMuted)),
                ),
                Text(
                  Fmt.money(d.manufacturingTotal, cents: true),
                  style: AppText.monoLg.copyWith(color: c.text, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: AppText.labelMd.copyWith(color: c.textMuted)),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged, required this.onTapValue});

  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onTapValue;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget btn(IconData icon, String tip, VoidCallback? onTap) => Tooltip(
      message: tip,
      child: Material(
        color: c.isDark ? c.surfaceHigh : c.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: onTap == null ? c.textFaint : c.text),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(Icons.remove, 'Decrease quantity', value > 1 ? () => onChanged(value - 1) : null),
        InkWell(
          onTap: onTapValue,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minWidth: 56),
            height: 44,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$value', style: AppText.monoLg.copyWith(fontSize: 18, color: c.text)),
          ),
        ),
        btn(Icons.add, 'Increase quantity', value < 9999 ? () => onChanged(value + 1) : null),
      ],
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget chip;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: c.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.titleMd),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodySm.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              chip,
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabelValue(
                  leftLabel,
                  leftValue,
                  valueStyle: AppText.bodyMd.copyWith(fontWeight: FontWeight.w500, color: c.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EditableValue(label: rightLabel, value: rightValue, onTap: onEdit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Label + mono value with a pencil — tapping opens an amount editor.
class _EditableValue extends StatelessWidget {
  const _EditableValue({
    required this.label,
    required this.value,
    required this.onTap,
    this.valueStyle,
    this.labelColor,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final TextStyle? valueStyle;
  final Color? labelColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final lc = labelColor ?? c.textFaint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.toUpperCase(), style: AppText.labelSm.copyWith(color: lc)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: valueStyle ?? AppText.monoLg.copyWith(color: c.text),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.edit_outlined, size: 14, color: lc),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Target vs max approved price. Dark slab in light theme, gold-on-navy in dark.
class _EnvelopeCard extends StatelessWidget {
  const _EnvelopeCard({required this.draft, required this.onEditTarget, required this.onEditMax});

  final JobDraft draft;
  final VoidCallback onEditTarget;
  final VoidCallback onEditMax;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = draft;
    final bg = c.isDark ? c.surfaceHigh : c.action;
    final fg = c.isDark ? c.text : c.onAction;
    final hi = c.isDark ? c.gold : c.onAction;
    final muted = fg.withValues(alpha: 0.65);
    final overTarget = d.targetUnitPrice > d.maxApprovedPrice;
    final overCost = d.manufacturingTotal > d.maxApprovedPrice;
    final ratio = d.maxApprovedPrice <= 0 ? 1.0 : d.targetUnitPrice / d.maxApprovedPrice;
    final headroom = d.maxApprovedPrice - d.targetUnitPrice;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppText.bodySm.copyWith(color: muted)),
          ),
          Text(value, style: AppText.monoMd.copyWith(color: fg)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.isDark ? c.gold.withValues(alpha: 0.45) : bg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 20, color: hi),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Commercial Envelope', style: AppText.headlineSm.copyWith(color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _EditableValue(
                  label: 'Target unit price',
                  value: Fmt.money(d.targetUnitPrice),
                  labelColor: muted,
                  valueStyle: AppText.monoLg.copyWith(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: hi,
                  ),
                  onTap: onEditTarget,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _EditableValue(
                  label: 'Max approved',
                  value: Fmt.money(d.maxApprovedPrice),
                  labelColor: muted,
                  alignEnd: true,
                  valueStyle: AppText.monoLg.copyWith(fontSize: 18, color: fg),
                  onTap: onEditMax,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: fg.withValues(alpha: 0.18),
              color: overTarget ? c.warning : (c.isDark ? c.gold : c.accentSoft),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  overTarget ? 'Over by ${Fmt.money(-headroom)}' : 'Headroom ${Fmt.money(headroom)}',
                  style: AppText.monoSm.copyWith(color: overTarget ? c.warning : muted),
                ),
              ),
              Text('${(ratio * 100).round()}% of max', style: AppText.monoSm.copyWith(color: muted)),
            ],
          ),
          Divider(height: 24, color: fg.withValues(alpha: 0.15)),
          row('Manufacturing subtotal', Fmt.money(d.manufacturingTotal, cents: true)),
          row('Order value (× ${d.quantity})', Fmt.money(d.targetUnitPrice * d.quantity)),
          if (overTarget || overCost) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (overTarget)
                  StatusChip(
                    'Target exceeds max approved',
                    color: c.warning,
                    icon: Icons.warning_amber_rounded,
                    mono: false,
                  ),
                if (overCost)
                  StatusChip(
                    'Manufacturing exceeds max',
                    color: c.warning,
                    icon: Icons.warning_amber_rounded,
                    mono: false,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.title, required this.initial, this.prefix = r'$', this.integer = false});

  final String title;
  final double initial;
  final String prefix;
  final bool integer;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.integer || widget.initial == widget.initial.roundToDouble()
        ? widget.initial.toStringAsFixed(0)
        : widget.initial.toStringAsFixed(2),
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_ctrl.text.replaceAll(',', '').trim());
    if (v == null || v < 0 || (widget.integer && v < 1)) {
      setState(() => _error = 'Enter a valid number');
      return;
    }
    Navigator.pop(context, widget.integer ? v.roundToDouble() : v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: widget.integer ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
        style: AppText.monoLg.copyWith(color: c.text),
        decoration: InputDecoration(prefixText: widget.prefix.isEmpty ? null : widget.prefix, errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textMuted)),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _LineEdit {
  const _LineEdit(this.label, this.amount, {this.delete = false});

  final String label;
  final double amount;
  final bool delete;
}

class _CostLineDialog extends StatefulWidget {
  const _CostLineDialog({this.line});

  final CostLine? line;

  @override
  State<_CostLineDialog> createState() => _CostLineDialogState();
}

class _CostLineDialogState extends State<_CostLineDialog> {
  late final TextEditingController _label = TextEditingController(text: widget.line?.label ?? '');
  late final TextEditingController _amount = TextEditingController(
    text: widget.line == null ? '' : widget.line!.amount.toStringAsFixed(2),
  );
  String? _labelError;
  String? _amountError;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim();
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    setState(() {
      _labelError = label.isEmpty ? 'Required' : null;
      _amountError = amount == null || amount < 0 ? 'Enter a valid amount' : null;
    });
    if (_labelError != null || _amountError != null) return;
    Navigator.pop(context, _LineEdit(label, amount!));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final line = widget.line;
    return AlertDialog(
      title: Text(line == null ? 'Add Cost Line' : 'Edit Cost Line'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            autofocus: line == null,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.bodyMd.copyWith(color: c.text),
            decoration: InputDecoration(labelText: 'Label', hintText: 'e.g. Engraving', errorText: _labelError),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.monoLg.copyWith(color: c.text),
            decoration: InputDecoration(labelText: 'Amount', prefixText: r'$', errorText: _amountError),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        if (line != null)
          TextButton(
            onPressed: () => Navigator.pop(context, _LineEdit(line.label, line.amount, delete: true)),
            child: Text('Delete', style: TextStyle(color: c.danger)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: c.textMuted)),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

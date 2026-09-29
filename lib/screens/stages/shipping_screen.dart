import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Logistics & dispatch: routing, manifest, security protocol and the
/// dispatch → delivered hand-off.
class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key, this.jobId});

  final String? jobId;

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _Address {
  const _Address(this.name, this.street, this.suite, this.city, this.country);

  final String name;
  final String street;
  final String suite;
  final String city;
  final String country;

  String get lines => [street, suite, city, country].where((l) => l.trim().isNotEmpty).join('\n');
}

class _SummaryEntry {
  const _SummaryEntry(this.title, this.text, this.state);

  final String title;
  final String text;
  final PipelineState state;
}

class _ShippingScreenState extends State<ShippingScreen> {
  static const _couriers = [
    'Brinks Secure Logistics (High Value)',
    'FedEx Priority Overnight',
    'Malca-Amit (International)',
  ];
  static const _checks = [
    'Tamper-evident seal applied to inner box (Seal #TE-921)',
    'Appraisal documents included in hidden compartment.',
    'High-res final QC photos uploaded to vault.',
  ];

  final _tracking = TextEditingController();
  final Set<int> _security = {};
  int _route = 0;
  String _courier = _couriers.first;
  late String _insurance;
  _Address _address = const _Address(
    'Aurum Jewelers - Flagship',
    '784 5th Avenue',
    'Suite 12A',
    'New York, NY 10022',
    'United States',
  );

  @override
  void initState() {
    super.initState();
    final v = app.jobOrDefault(widget.jobId).value;
    _insurance = Fmt.money(v, cents: true, symbol: '');
  }

  @override
  void dispose() {
    _tracking.dispose();
    super.dispose();
  }

  // ---- State helpers ------------------------------------------------------

  ThreadMessage? _dispatchEvent(Job job) {
    for (final m in job.thread.reversed) {
      if (m.title == 'Dispatched') return m;
    }
    return null;
  }

  bool _inTransit(Job job) => job.stage == JobStage.dispatch && _dispatchEvent(job) != null;

  bool _locked(Job job) => job.stage == JobStage.delivered || _inTransit(job);

  (String, Color) _status(Job job, DhColors c) {
    if (job.stage == JobStage.delivered) return ('Delivered', c.success);
    if (_inTransit(job)) return ('In Transit', c.info);
    return ('Awaiting Dispatch', c.accent);
  }

  String get _courierShort => _courier.split(' (').first;

  static String _sku(Job job) {
    final m = job.metal.toLowerCase();
    final metal = m.contains('platinum')
        ? 'PT'
        : m.contains('silver')
        ? 'AG'
        : m.contains('white')
        ? 'WG'
        : m.contains('rose')
        ? 'RG'
        : 'YG';
    final type = job.productType.isEmpty ? 'X' : job.productType.substring(0, 1).toUpperCase();
    return '$type-$metal-${job.id.replaceAll('DH-', '')}';
  }

  List<_SummaryEntry> _summary(Job job) {
    final transit = _inTransit(job);
    final delivered = job.stage == JobStage.delivered;
    final dispatchText = delivered
        ? 'Delivered to ${_address.name}'
        : transit
        ? 'In transit via $_courierShort'
        : 'Awaiting final manifest';
    if (job.history.isEmpty) {
      return [
        const _SummaryEntry('Oct 12 · Casting', 'Completed by Marco V.', PipelineState.done),
        const _SummaryEntry('Oct 15 · Setting', 'Main stone set (GIA 44921)', PipelineState.done),
        const _SummaryEntry('Oct 18 · Polish & QC', 'Passed final inspection', PipelineState.done),
        _SummaryEntry('Today · Dispatch', dispatchText, delivered ? PipelineState.done : PipelineState.current),
      ];
    }
    final h = job.history;
    final recent = h.length > 4 ? h.sublist(h.length - 4) : h;
    final out = <_SummaryEntry>[
      for (final e in recent)
        _SummaryEntry(
          '${_day(e.at)} · ${e.stage.label}',
          e.stage == JobStage.dispatch
              ? dispatchText
              : e.note ?? (e.stage == job.stage ? 'In progress • ${e.by}' : 'Completed by ${e.by}'),
          e.stage == job.stage && !delivered ? PipelineState.current : PipelineState.done,
        ),
    ];
    if (job.stage.isBefore(JobStage.dispatch)) {
      out.add(const _SummaryEntry('Dispatch', 'Awaiting final manifest', PipelineState.pending));
    }
    return out;
  }

  static String _day(DateTime d) {
    final now = DateTime.now();
    final today = d.year == now.year && d.month == now.month && d.day == now.day;
    return today ? 'Today' : Fmt.date(d);
  }

  // ---- Actions ------------------------------------------------------------

  void _lockedSnack() => showSnack(context, 'Manifest is locked after dispatch', icon: Icons.lock_outline);

  Future<void> _editAddress() async {
    final a = await showDialog<_Address>(
      context: context,
      builder: (_) => _AddressDialog(initial: _address),
    );
    if (a == null || !mounted) return;
    setState(() => _address = a);
    showSnack(context, 'Destination updated: ${a.name}', icon: Icons.location_on_outlined);
  }

  Future<void> _scan(Job job) async {
    final path = await pickImage(context, title: 'Scan Waybill Barcode');
    if (path == null || !mounted) return;
    final prefix = _courier.startsWith('Brinks')
        ? 'BRK'
        : _courier.startsWith('FedEx')
        ? 'FDX'
        : 'MLC';
    final code = '$prefix${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';
    app.addFile(job, ProjectFile(name: 'waybill_$code.jpg', kind: FileKind.image, localPath: path, jobId: job.id));
    _tracking.text = code;
    showSnack(context, 'Waybill captured: $code', icon: Icons.qr_code_2);
  }

  Future<void> _confirmDispatch(Job job) async {
    final waybill = _tracking.text.trim().toUpperCase();
    if (waybill.isEmpty) {
      showSnack(context, 'Enter or scan the tracking number / waybill first', icon: Icons.qr_code_scanner);
      return;
    }
    if (_security.length < _checks.length) {
      showSnack(
        context,
        'Complete the security protocol (${_security.length}/${_checks.length} verified)',
        icon: Icons.shield_outlined,
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Confirm Dispatch?',
      message:
          '${job.id} ships via $_courierShort to ${_address.name}.\n'
          'Waybill $waybill · insured for \$$_insurance.',
      confirm: 'Dispatch',
    );
    if (!ok || !mounted) return;
    if (job.stage.isBefore(JobStage.dispatch)) {
      app.setStage(
        job,
        JobStage.dispatch,
        note: 'Manifest generated. Routed ${_route == 0 ? 'to jeweler' : 'direct to customer'}.',
      );
    }
    app.addEvent(job, title: 'Dispatched', text: '$_courier • Waybill $waybill');
    showSnack(context, '${job.id} dispatched · In Transit', icon: Icons.local_shipping_outlined);
  }

  Future<void> _markDelivered(Job job) async {
    final ok = await confirmDialog(
      context,
      title: 'Mark Delivered?',
      message: 'Confirm ${job.id} was received by ${_address.name}.',
      confirm: 'Delivered',
    );
    if (!ok || !mounted) return;
    app.setStage(job, JobStage.delivered, note: 'Delivered to ${_address.name}.');
    showSnack(context, '${job.id} delivered', icon: Icons.inventory_2_outlined);
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final c = context.c;
        final job = app.jobOrDefault(widget.jobId);
        final (status, statusColor) = _status(job, c);
        return DetailScaffold(
          title: 'Shipping',
          subtitle: job.id,
          bottom: _bottomBar(job),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 18, color: c.accent),
                  const SizedBox(width: 8),
                  Text('LOGISTICS & DISPATCH', style: AppText.labelSm.copyWith(color: c.accent, letterSpacing: 1.6)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Job #${job.id}: Final Dispatch', style: AppText.headlineLg),
              const SizedBox(height: 6),
              Text(
                'Initiating secure transit protocols. Select routing path and verify insurance coverage before '
                'generating final manifest.',
                style: AppText.bodyMd.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 14),
              _StatusCard(status: status, color: statusColor, detail: _dispatchEvent(job)?.text),
              const SizedBox(height: 16),
              _routingCard(job),
              const SizedBox(height: 16),
              _manifestCard(job),
              const SizedBox(height: 16),
              _productCard(job),
              const SizedBox(height: 16),
              _securityCard(job),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomBar(Job job) {
    final c = context.c;
    if (job.stage == JobStage.delivered) {
      return SecondaryButton(
        'Open Job',
        icon: Icons.open_in_new,
        onPressed: () => Navigator.pushNamed(context, Routes.job, arguments: job.id),
      );
    }
    if (_inTransit(job)) {
      return PrimaryButton('Mark Delivered', icon: Icons.inventory_2_outlined, onPressed: () => _markDelivered(job));
    }
    return Row(
      children: [
        TextButton(
          onPressed: () => showSnack(context, 'Manifest draft saved for ${job.id}', icon: Icons.save_outlined),
          style: TextButton.styleFrom(
            foregroundColor: c.text,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            textStyle: AppText.titleMd.copyWith(fontSize: 15),
          ),
          child: const Text('Save Draft'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrimaryButton('Confirm Dispatch', icon: Icons.send_outlined, onPressed: () => _confirmDispatch(job)),
        ),
      ],
    );
  }

  Widget _routingCard(Job job) {
    final locked = _locked(job);
    Widget option(int i, IconData icon, String title, String subtitle) => IconOptionCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      horizontal: true,
      selected: _route == i,
      trailing: _RadioMark(selected: _route == i),
      onTap: locked ? _lockedSnack : () => setState(() => _route = i),
    );
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.route_outlined, title: 'Routing Selection'),
          const SizedBox(height: 14),
          option(0, Icons.storefront_outlined, 'Return to Jeweler', 'Standard B2B transfer protocol.'),
          const SizedBox(height: 10),
          option(1, Icons.home_outlined, 'Direct to Customer', 'Requires white-glove unboxing prep.'),
        ],
      ),
    );
  }

  Widget _manifestCard(Job job) {
    final c = context.c;
    final locked = _locked(job);
    return DhCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.fact_check_outlined, title: 'Manifest Details'),
          const SizedBox(height: 16),
          Field(
            label: 'Courier Service',
            child: ChoiceGroup<String>(
              options: _couriers,
              selected: _courier,
              columns: 1,
              onChanged: (v) => locked ? _lockedSnack() : setState(() => _courier = v),
            ),
          ),
          const SizedBox(height: 18),
          Field(
            label: 'Declared Insurance Value',
            code: 'USD',
            child: DhTextField(
              value: _insurance,
              prefixText: r'$ ',
              mono: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _insurance = v,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('DESTINATION ADDRESS', style: AppText.labelSm.copyWith(color: c.textMuted)),
              ),
              TextButton(
                onPressed: locked ? _lockedSnack : _editAddress,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 4),
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
                Icon(Icons.location_on_outlined, color: c.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_address.name, style: AppText.titleMd.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(_address.lines, style: AppText.bodyMd.copyWith(color: c.text, height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _openViewer(context, Img.mapNewYork),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(Img.mapNewYork, width: 88, height: 72, fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Field(
            label: 'Tracking Number / Waybill',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tracking,
                    readOnly: locked,
                    textCapitalization: TextCapitalization.characters,
                    style: AppText.monoLg.copyWith(color: c.text),
                    decoration: InputDecoration(
                      hintText: 'Scan barcode or enter manually...',
                      hintStyle: AppText.bodySm.copyWith(color: c.textFaint),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: c.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: locked ? _lockedSnack : () => _scan(job),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Tooltip(
                        message: 'Scan barcode',
                        child: Icon(Icons.qr_code_scanner, color: c.text),
                      ),
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

  Widget _productCard(Job job) {
    final c = context.c;
    final scrim = c.isDark ? c.bg : c.navActive;
    final fg = c.isDark ? c.text : c.onNavActive;
    final entries = _summary(job);
    return DhCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(job.image ?? Img.ringEmeraldCutWhite, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [scrim.withValues(alpha: 0.85), scrim.withValues(alpha: 0)],
                      stops: const [0, 0.65],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(2)),
                        child: Text('SKU: ${_sku(job)}', style: AppText.monoSm.copyWith(color: c.onAccent)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headlineSm.copyWith(color: fg),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionLabel('Production Summary'),
                const SizedBox(height: 14),
                for (var i = 0; i < entries.length; i++)
                  PipelineTile(
                    title: entries[i].title,
                    subtitle: entries[i].text,
                    state: entries[i].state,
                    isLast: i == entries.length - 1,
                  ),
                const SizedBox(height: 8),
                const Divider(),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, Routes.job, arguments: job.id),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View Full History Archive'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityCard(Job job) {
    final c = context.c;
    final bg = c.isDark ? c.surfaceHigh : c.navActive;
    final fg = c.isDark ? c.text : c.onNavActive;
    final locked = _locked(job);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: c.isDark ? BorderSide(color: c.border) : BorderSide.none,
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: _securityList(c, fg, locked)),
    );
  }

  Widget _securityList(DhColors c, Color fg, bool locked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, color: c.isDark ? c.gold : c.goldSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Security Protocol', style: AppText.headlineSm.copyWith(color: fg)),
            ),
            Text(
              '${locked ? _checks.length : _security.length}/${_checks.length}',
              style: AppText.monoSm.copyWith(color: fg.withValues(alpha: 0.7)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _checks.length; i++)
          InkWell(
            onTap: locked ? null : () => setState(() => _security.contains(i) ? _security.remove(i) : _security.add(i)),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: locked || _security.contains(i),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: fg.withValues(alpha: 0.6), width: 1.5),
                    onChanged: locked
                        ? null
                        : (v) => setState(() => v == true ? _security.add(i) : _security.remove(i)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_checks[i], style: AppText.bodySm.copyWith(color: fg.withValues(alpha: 0.9))),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Pieces ----------------------------------------------------------------

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: context.c.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: AppText.headlineSm)),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.color, this.detail});

  final String status;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DhCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CURRENT STATUS', style: AppText.labelSm.copyWith(color: c.textMuted)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(status, style: AppText.headlineSm.copyWith(color: c.text)),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!, style: AppText.monoSm.copyWith(color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? c.accent : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: selected ? c.accent : c.borderStrong, width: 1.5),
      ),
      child: selected ? Icon(Icons.check, size: 16, color: c.onAccent) : null,
    );
  }
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({required this.initial});

  final _Address initial;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final _name = TextEditingController(text: widget.initial.name);
  late final _street = TextEditingController(text: widget.initial.street);
  late final _suite = TextEditingController(text: widget.initial.suite);
  late final _city = TextEditingController(text: widget.initial.city);
  late final _country = TextEditingController(text: widget.initial.country);

  @override
  void dispose() {
    for (final c in [_name, _street, _suite, _city, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty || _street.text.trim().isEmpty || _city.text.trim().isEmpty) {
      showSnack(context, 'Name, street and city are required', icon: Icons.error_outline);
      return;
    }
    Navigator.pop(
      context,
      _Address(_name.text.trim(), _street.text.trim(), _suite.text.trim(), _city.text.trim(), _country.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget field(TextEditingController ctrl, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        textCapitalization: TextCapitalization.words,
        style: AppText.bodyMd.copyWith(color: c.text),
        decoration: InputDecoration(labelText: label),
      ),
    );
    return AlertDialog(
      title: const Text('Destination Address'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field(_name, 'Recipient / Store'),
            field(_street, 'Street'),
            field(_suite, 'Suite / Floor'),
            field(_city, 'City, State ZIP'),
            field(_country, 'Country'),
          ],
        ),
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

Future<void> _openViewer(BuildContext context, String image) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (ctx) {
      final c = ctx.c;
      return Dialog.fullscreen(
        backgroundColor: c.bg,
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(child: Image.asset(image, fit: BoxFit.contain)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('Pinch to zoom', style: AppText.bodySm.copyWith(color: c.textFaint)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

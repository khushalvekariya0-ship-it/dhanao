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

  String get oneLine => [name, street, suite, city, country].where((l) => l.trim().isNotEmpty).join(', ');
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
  late final _insurance = TextEditingController(
    text: Fmt.money(app.jobOrDefault(widget.jobId).value, cents: true, symbol: ''),
  );
  final Set<int> _security = {};
  int _route = 0;
  String _courier = _couriers.first;
  _Address _address = const _Address(
    'Aurum Jewelers - Flagship',
    '784 5th Avenue',
    'Suite 12A',
    'New York, NY 10022',
    'United States',
  );

  @override
  void dispose() {
    _tracking.dispose();
    _insurance.dispose();
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
          'Waybill $waybill · insured for \$${_insurance.text.trim()}.',
      confirm: 'Dispatch',
    );
    if (!ok || !mounted) return;
    final insured = double.tryParse(_insurance.text.replaceAll(',', '').trim());
    app.recordStage(job, JobStage.dispatch, {
      'Routing': _route == 0 ? 'Return to Jeweler' : 'Direct to Customer',
      'Courier': _courier,
      'Insurance Value': insured == null ? _insurance.text.trim() : Fmt.money(insured),
      'Destination': _address.oneLine,
      'Waybill': waybill,
      if (_security.contains(0)) 'Security Seal': 'Seal #TE-921',
      'Dispatched At': Fmt.dateTime(DateTime.now()),
    });
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
    app.recordStage(job, JobStage.delivered, {
      'Delivered At': Fmt.dateTime(DateTime.now()),
      'Received By': _address.name,
    });
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
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _Hero(job: job, status: status, color: statusColor, detail: _dispatchEvent(job)?.text),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _routingCard(job),
                    const SizedBox(height: 20),
                    _manifestCard(job),
                    const SizedBox(height: 20),
                    _productCard(job),
                    const SizedBox(height: 20),
                    _securityCard(job),
                  ],
                ),
              ),
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
    Widget option(int i, IconData icon, String title, String subtitle) => Expanded(
      child: _RouteTile(
        icon: icon,
        title: title,
        subtitle: subtitle,
        selected: _route == i,
        onTap: locked ? _lockedSnack : () => setState(() => _route = i),
      ),
    );
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.route_outlined, title: 'Routing Selection'),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                option(0, Icons.storefront_outlined, 'Return to Jeweler', 'Standard B2B transfer protocol.'),
                const SizedBox(width: 12),
                option(1, Icons.home_outlined, 'Direct to Customer', 'Requires white-glove unboxing prep.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _manifestCard(Job job) {
    final c = context.c;
    final locked = _locked(job);
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle(icon: Icons.fact_check_outlined, title: 'Manifest Details'),
          const SizedBox(height: 24),
          const _FieldLabel('Courier Service'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _courier,
            isExpanded: true,
            icon: Icon(Icons.expand_more, color: c.textMuted),
            dropdownColor: c.surface,
            borderRadius: BorderRadius.circular(8),
            style: AppText.bodyMd.copyWith(color: c.text),
            decoration: _wellDecoration(c),
            items: [
              for (final o in _couriers)
                DropdownMenuItem(
                  value: o,
                  child: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: locked ? null : (v) => setState(() => _courier = v ?? _courier),
          ),
          const SizedBox(height: 24),
          _FieldLabel(
            'Declared Insurance Value',
            trailing: Text('USD', style: AppText.monoMd.copyWith(color: c.accent)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _insurance,
            readOnly: locked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: AppText.monoLg.copyWith(color: c.text, fontSize: 15),
            decoration: _wellDecoration(c).copyWith(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Text(r'$', style: AppText.monoLg.copyWith(color: c.textMuted, fontSize: 15)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
          const SizedBox(height: 24),
          _FieldLabel(
            'Destination Address',
            trailing: GestureDetector(
              onTap: locked ? _lockedSnack : _editAddress,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text('Edit', style: AppText.labelSm.copyWith(color: c.accent, fontSize: 12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _well(c), borderRadius: BorderRadius.circular(4)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.location_on_outlined, color: c.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _address.name,
                        style: AppText.bodyMd.copyWith(color: c.text, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(_address.lines, style: AppText.bodyMd.copyWith(color: c.text, height: 1.6)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _openViewer(context, Img.mapNewYork),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: c.surfaceHigh),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(Img.mapNewYork, width: 96, height: 76, fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _FieldLabel('Tracking Number / Waybill'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tracking,
                  readOnly: locked,
                  textCapitalization: TextCapitalization.characters,
                  style: AppText.monoLg.copyWith(color: c.text),
                  decoration: _wellDecoration(c).copyWith(
                    hintText: 'Scan barcode or enter manually...',
                    hintStyle: AppText.monoMd.copyWith(color: c.textFaint, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: c.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
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
        ],
      ),
    );
  }

  Widget _productCard(Job job) {
    final c = context.c;
    final scrim = c.isDark ? c.bg : c.text;
    const fg = Colors.white;
    final entries = _summary(job);
    return _Section(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 192,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(job.image ?? Img.ringEmeraldCutWhite, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [scrim.withValues(alpha: 0.8), scrim.withValues(alpha: 0)],
                      stops: const [0, 0.6],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(2)),
                        child: Text('SKU: ${_sku(job)}', style: AppText.monoSm.copyWith(color: c.onAccent)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headlineSm.copyWith(color: fg, fontSize: 19, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('PRODUCTION SUMMARY', style: AppText.labelMd.copyWith(color: c.textMuted)),
                const SizedBox(height: 16),
                for (var i = 0; i < entries.length; i++)
                  _SummaryTile(entry: entries[i], isFirst: i == 0, isLast: i == entries.length - 1),
                const SizedBox(height: 24),
                Divider(color: c.isDark ? c.border : c.surfaceHighest, height: 1),
                const SizedBox(height: 4),
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
    final fg = c.isDark ? c.textMuted : c.onNavActive.withValues(alpha: 0.72);
    final locked = _locked(job);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(20),
      child: _securityList(c, fg, locked),
    );
  }

  Widget _securityList(DhColors c, Color fg, bool locked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 22, color: c.isDark ? c.gold : c.goldSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Security Protocol', style: AppText.headlineSm.copyWith(color: fg)),
            ),
            Text(
              '${locked ? _checks.length : _security.length}/${_checks.length}',
              style: AppText.monoSm.copyWith(color: fg.withValues(alpha: 0.8)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _checks.length; i++)
          InkWell(
            onTap: locked ? null : () => setState(() => _security.contains(i) ? _security.remove(i) : _security.add(i)),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: locked || _security.contains(i),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide(color: fg, width: 1.5),
                    onChanged: locked
                        ? null
                        : (v) => setState(() => v == true ? _security.add(i) : _security.remove(i)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_checks[i], style: AppText.bodySm.copyWith(color: fg, fontSize: 14, height: 1.45)),
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

/// Input "well" fill (surface-container-low).
Color _well(DhColors c) => c.surfaceLow;

InputDecoration _wellDecoration(DhColors c) {
  const none = OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(4)), borderSide: BorderSide.none);
  return InputDecoration(
    filled: true,
    fillColor: _well(c),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: none,
    enabledBorder: none,
    disabledBorder: none,
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(4)),
      borderSide: BorderSide(color: c.accent, width: 2),
    ),
  );
}

/// White section card with a soft shadow (hairline border in dark).
class _Section extends StatelessWidget {
  const _Section({required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(icon, size: 24, color: c.isDark ? c.gold : c.text),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: AppText.headlineMd.copyWith(color: c.text)),
        ),
      ],
    );
  }
}

/// Sentence-case field label with an optional trailing widget ("USD", "Edit").
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(text, style: AppText.labelMd.copyWith(color: context.c.text)),
        ),
        ?trailing,
      ],
    );
  }
}

/// White header band: section eyebrow, title, intro and the status card.
class _Hero extends StatelessWidget {
  const _Hero({required this.job, required this.status, required this.color, this.detail});

  final Job job;
  final String status;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.surface,
        border: c.isDark ? Border(bottom: BorderSide(color: c.border)) : null,
        boxShadow: c.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))],
      ),
      child: Stack(
        children: [
          // Decorative abstract blob behind the status card.
          Positioned(
            right: -48,
            bottom: -40,
            child: Container(
              width: 200,
              height: 170,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: c.isDark ? 0.14 : 0.32),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(110),
                  topRight: Radius.circular(70),
                  bottomLeft: Radius.circular(90),
                  bottomRight: Radius.circular(120),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 22, color: c.accent),
                    const SizedBox(width: 8),
                    Text('LOGISTICS & DISPATCH', style: AppText.labelSm.copyWith(color: c.accent, letterSpacing: 2.2)),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Job #${job.id}: Final Dispatch', style: AppText.display.copyWith(color: c.text)),
                const SizedBox(height: 8),
                Text(
                  'Initiating secure transit protocols. Select routing path and verify insurance coverage before '
                  'generating final manifest.',
                  style: AppText.bodyLg.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: c.isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('CURRENT STATUS', style: AppText.labelSm.copyWith(color: c.textMuted)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(status, style: AppText.headlineSm.copyWith(color: c.isDark ? c.gold : c.action)),
                          ],
                        ),
                        if (detail != null) ...[
                          const SizedBox(height: 4),
                          Text(detail!, style: AppText.monoSm.copyWith(color: c.textMuted)),
                        ],
                      ],
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

/// Tall routing option tile; the selected one turns navy.
class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = selected ? c.navActive : _well(c);
    final iconColor = selected ? (c.isDark ? c.gold : c.textFaint) : c.textMuted;
    final titleColor = selected ? (c.isDark ? c.gold : c.accentSoft) : c.text;
    final subColor = selected ? (c.isDark ? c.textMuted : c.onNavActive.withValues(alpha: 0.7)) : c.textMuted;
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selected && c.isDark ? BorderSide(color: c.gold, width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 150),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 30, color: iconColor),
                    const Spacer(),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: selected
                            ? (c.isDark ? c.gold : c.surface)
                            : (c.isDark ? c.surfaceHighest : c.surfaceHigh),
                        shape: BoxShape.circle,
                      ),
                      child: selected ? Icon(Icons.check, size: 16, color: c.isDark ? c.onAction : c.navActive) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.titleMd.copyWith(color: titleColor, fontSize: 17, height: 1.3)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppText.bodySm.copyWith(color: subColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Condensed production-summary timeline row (small dot on a 2px rail).
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.entry, required this.isFirst, required this.isLast});

  final _SummaryEntry entry;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final rail = c.isDark ? c.border : c.surfaceHighest;
    final current = entry.state == PipelineState.current;
    final pending = entry.state == PipelineState.pending;
    final active = c.isDark ? c.gold : c.accent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 14,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 2, color: rail)),
                Positioned(
                  left: -5,
                  top: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: current ? active : rail,
                      shape: BoxShape.circle,
                      border: current ? null : Border.all(color: c.surface, width: 2),
                      boxShadow: current ? [BoxShadow(color: active.withValues(alpha: 0.2), spreadRadius: 4)] : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: AppText.labelSm.copyWith(
                      color: current ? active : (pending ? c.textFaint : c.textMuted),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.text,
                    style: AppText.bodySm.copyWith(
                      color: pending ? c.textFaint : c.text,
                      fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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

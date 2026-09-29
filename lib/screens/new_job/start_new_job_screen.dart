import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

/// Step 1/4 of the New Job wizard: pick the job type and which flow to use.
class StartNewJobScreen extends StatefulWidget {
  const StartNewJobScreen({super.key});

  @override
  State<StartNewJobScreen> createState() => _StartNewJobScreenState();
}

class _JobType {
  const _JobType(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}

const _jobTypes = [
  _JobType('New Custom Design', 'Start a fresh CAD from sketch', Icons.draw_outlined),
  _JobType('Recreate Existing', 'Duplicate or repair a piece', Icons.content_copy_outlined),
  _JobType('Reset Stone', 'Mounting customer materials', Icons.diamond),
  _JobType('Repair', 'Restoration or sizing services', Icons.build_outlined),
];

class _StartNewJobScreenState extends State<StartNewJobScreen> {
  bool _quick = false;

  @override
  void initState() {
    super.initState();
    // Fresh draft for every new job. Assigned directly (same as app.resetDraft()) because notifying
    // listeners while this route is being built would trip "setState() called during build".
    app.draft = JobDraft();
  }

  Color _tint(DhColors c, int i) => switch (i) {
    0 => c.gold,
    1 => c.success,
    2 => c.info,
    _ => c.isDark ? c.danger : c.accent,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = app.draft;
    return BlueprintBackdrop(
      corner: true,
      child: WizardScaffold(
        title: 'NEW JOB',
        step: 1,
        totalSteps: 4,
        stepLabel: 'Job Type',
        ctaLabel: 'Continue',
        onCta: () => Navigator.pushNamed(context, _quick ? Routes.capture : Routes.product),
        children: [
          const SizedBox(height: 8),
          Text('Job Type', textAlign: TextAlign.center, style: AppText.headlineLg),
          const SizedBox(height: 8),
          Text(
            'Select the primary service for this work order.',
            textAlign: TextAlign.center,
            style: AppText.bodyLg.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 24),
          for (var i = 0; i < _jobTypes.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _TypeCard(
              icon: _jobTypes[i].icon,
              title: _jobTypes[i].title,
              subtitle: _jobTypes[i].subtitle,
              tint: _tint(c, i),
              selected: d.jobType == _jobTypes[i].title,
              onTap: () => setState(() => d.jobType = _jobTypes[i].title),
            ),
          ],
          const SizedBox(height: 32),
          Text('How do you want to start?', style: AppText.headlineSm),
          const SizedBox(height: 4),
          Text('You can always add more detail to the job later.', style: AppText.bodyMd.copyWith(color: c.textMuted)),
          const SizedBox(height: 16),
          _FlowCard(
            icon: Icons.bolt,
            title: 'Quick Capture',
            subtitle: 'Photo, voice note & basics · 4 steps',
            selected: _quick,
            onTap: () => setState(() => _quick = true),
          ),
          const SizedBox(height: 12),
          _FlowCard(
            icon: Icons.assignment_outlined,
            title: 'Full Job Order',
            subtitle: 'Specs, stones, commercials & quality',
            selected: !_quick,
            onTap: () => setState(() => _quick = false),
          ),
        ],
      ),
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
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
    final on = c.isDark ? c.gold : c.accent;
    return _TypeCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      mono: false,
      tint: on,
      selected: selected,
      onTap: onTap,
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? on : c.textFaint,
      ),
    );
  }
}

/// Horizontal option card from the design: icon tile, title, one-line mono subtitle and a chevron.
/// Tinted icon tiles in dark; neutral grey tiles with ink icons in light.
class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.selected,
    required this.onTap,
    this.mono = true,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final on = c.isDark ? c.gold : c.accent;
    final iconColor = c.isDark ? tint : (selected ? on : c.text);
    return Material(
      color: selected ? c.accentSoft : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? on : (c.isDark ? c.border : c.borderStrong.withValues(alpha: 0.6)),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.isDark ? tint.withValues(alpha: 0.12) : c.surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.isDark ? tint.withValues(alpha: 0.3) : c.surfaceLow),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.titleMd.copyWith(fontSize: 17, height: 24 / 17, color: c.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: mono ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: (mono ? AppText.monoMd : AppText.bodySm).copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ?? Icon(Icons.chevron_right, color: c.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faint "technical blueprint" grid painted behind a [Scaffold] (whose background is made
/// transparent). Opaque cards, app bar and bottom bar sit on top of it, so it never hurts legibility.
class BlueprintBackdrop extends StatelessWidget {
  const BlueprintBackdrop({super.key, required this.child, this.corner = false, this.cell = 24});

  final Widget child;

  /// Only a fading 256px patch in the bottom-right corner instead of the whole screen.
  final bool corner;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color line;
    if (corner) {
      line = c.isDark ? c.gold.withValues(alpha: 0.28) : c.textFaint.withValues(alpha: 0.22);
    } else {
      line = c.isDark ? c.gold.withValues(alpha: 0.06) : c.textFaint.withValues(alpha: 0.08);
    }
    final theme = Theme.of(context);
    return ColoredBox(
      color: c.bg,
      child: Stack(
        children: [
          if (corner)
            Positioned(
              right: -64,
              bottom: 24,
              width: 256,
              height: 256,
              child: CustomPaint(painter: _GridPainter(line, 25.6, fade: true)),
            )
          else
            Positioned.fill(child: CustomPaint(painter: _GridPainter(line, cell))),
          Theme(
            data: theme.copyWith(scaffoldBackgroundColor: Colors.transparent),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color, this.cell, {this.fade = false});

  final Color color;
  final double cell;
  final bool fade;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    if (fade) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0), color],
      ).createShader(rect);
    } else {
      paint.color = color;
    }
    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color || old.cell != cell || old.fade != fade;
}

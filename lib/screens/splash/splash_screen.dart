import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/assets.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../shell/home_shell.dart';

/// Brand splash shown on launch: the logo stays exactly where the native launch
/// screen drew it (112dp tile, screen centre) while "DhanaOS" fades in beneath it,
/// then the app cross-fades into the dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Same midnight blue as the native Android/iOS launch screens.
  static const background = Color(0xFF041329);
  static const gold = Color(0xFFF2CA50);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

  late final Animation<double> _glow = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );
  late final Animation<double> _title = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.15, 0.6, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tagline = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
  );
  late final Animation<double> _bar = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.3, 1, curve: Curves.easeInOut),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Warm up images the dashboard shows first, while the splash animates.
    for (final a in [Img.logo, Img.avatarRavi, Img.ringEmeraldCutWhite, Img.cadPendantSapphire, Img.ringOvalHalo]) {
      precacheImage(AssetImage(a), context);
    }
    _ctrl.forward().whenComplete(() => Future.delayed(const Duration(milliseconds: 350), _goHome));
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: Routes.home),
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const HomeShell(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: SplashScreen.background,
      ),
      child: Scaffold(
        backgroundColor: SplashScreen.background,
        body: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: [
              // Logo: exact centre, same size as the native splash, so there is no jump.
              Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: SplashScreen.gold.withValues(alpha: 0.28 * _glow.value),
                        blurRadius: 48 * _glow.value,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(24), child: Image.asset(Img.logo)),
                ),
              ),
              // Name + tagline under the logo.
              Center(
                child: Transform.translate(
                  offset: const Offset(0, 112),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: _title.value,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - _title.value)),
                          child: Text(
                            'DhanaOS',
                            style: AppText.display.copyWith(color: Colors.white, fontSize: 38, letterSpacing: -0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: _tagline.value,
                        child: Text(
                          'JEWELRY PRODUCTION OS',
                          style: AppText.monoCaps.copyWith(color: SplashScreen.gold, fontSize: 12, letterSpacing: 3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Thin gold loading line near the bottom.
              Positioned(
                left: 0,
                right: 0,
                bottom: 72,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Container(
                      width: 120,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _bar.value,
                        child: Container(
                          decoration: BoxDecoration(
                            color: SplashScreen.gold,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [BoxShadow(color: SplashScreen.gold.withValues(alpha: 0.6), blurRadius: 8)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

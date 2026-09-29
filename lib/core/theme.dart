import 'package:flutter/material.dart';

/// Semantic design tokens shared by both themes.
///
/// Light = "DhanaOS" system (navy / indigo / gold on cool white).
/// Dark  = "Industrial Precision" system (metallic gold on midnight blue).
@immutable
class DhColors extends ThemeExtension<DhColors> {
  const DhColors({
    required this.bg,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.border,
    required this.borderStrong,
    required this.action,
    required this.onAction,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.gold,
    required this.goldSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.navActive,
    required this.onNavActive,
    required this.isDark,
  });

  /// Page background.
  final Color bg;

  /// Cards and main surfaces.
  final Color surface;

  /// Subtle wells, input fills, inactive tiles.
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color surfaceHighest;

  final Color text;
  final Color textMuted;
  final Color textFaint;

  /// Hairline 1px borders.
  final Color border;
  final Color borderStrong;

  /// Primary call-to-action fill (black in light, gold in dark).
  final Color action;
  final Color onAction;

  /// Active state / links / progress (indigo in light, gold in dark).
  final Color accent;
  final Color accentSoft;
  final Color onAccent;

  /// Milestones, approvals, "high value".
  final Color gold;
  final Color goldSoft;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;

  final Color navActive;
  final Color onNavActive;
  final bool isDark;

  static const light = DhColors(
    bg: Color(0xFFF7F9FB),
    surface: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFF2F4F6),
    surfaceHigh: Color(0xFFE6E8EA),
    surfaceHighest: Color(0xFFE0E3E5),
    text: Color(0xFF191C1E),
    textMuted: Color(0xFF45464D),
    textFaint: Color(0xFF76777D),
    border: Color(0xFFE2E8F0),
    borderStrong: Color(0xFFC6C6CD),
    action: Color(0xFF000000),
    onAction: Color(0xFFFFFFFF),
    accent: Color(0xFF4648D4),
    accentSoft: Color(0xFFE1E0FF),
    onAccent: Color(0xFFFFFFFF),
    gold: Color(0xFFA67E00),
    goldSoft: Color(0xFFFFF4D6),
    success: Color(0xFF059669),
    successSoft: Color(0xFFD1FAE5),
    warning: Color(0xFFD97706),
    warningSoft: Color(0xFFFEF3C7),
    danger: Color(0xFFBA1A1A),
    dangerSoft: Color(0xFFFFDAD6),
    info: Color(0xFF0EA5E9),
    navActive: Color(0xFF131B2E),
    onNavActive: Color(0xFFFFFFFF),
    isDark: false,
  );

  static const dark = DhColors(
    bg: Color(0xFF041329),
    surface: Color(0xFF112036),
    surfaceLow: Color(0xFF0D1C32),
    surfaceHigh: Color(0xFF1C2A41),
    surfaceHighest: Color(0xFF27354C),
    text: Color(0xFFD6E3FF),
    textMuted: Color(0xFFD0C5AF),
    textFaint: Color(0xFF99907C),
    border: Color(0xFF27354C),
    borderStrong: Color(0xFF4D4635),
    action: Color(0xFFF2CA50),
    onAction: Color(0xFF3C2F00),
    accent: Color(0xFFF2CA50),
    accentSoft: Color(0x26F2CA50),
    onAccent: Color(0xFF3C2F00),
    gold: Color(0xFFF2CA50),
    goldSoft: Color(0x26F2CA50),
    success: Color(0xFF45E6C3),
    successSoft: Color(0x2645E6C3),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0x26FBBF24),
    danger: Color(0xFFFFB4AB),
    dangerSoft: Color(0x33FFB4AB),
    info: Color(0xFF7DD3FC),
    navActive: Color(0x33F2CA50),
    onNavActive: Color(0xFFF2CA50),
    isDark: true,
  );

  @override
  DhColors copyWith() => this;

  @override
  DhColors lerp(ThemeExtension<DhColors>? other, double t) => (other is DhColors && t > 0.5) ? other : this;
}

/// Type scale from the design systems. Colors are intentionally omitted so
/// text inherits the ambient [DefaultTextStyle] color.
class AppText {
  AppText._();

  static const String sans = 'HankenGrotesk';
  static const String mono = 'JetBrainsMono';

  static const display = TextStyle(
    fontFamily: sans,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );
  static const headlineLg = TextStyle(
    fontFamily: sans,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );
  static const headlineMd = TextStyle(fontFamily: sans, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600);
  static const headlineSm = TextStyle(fontFamily: sans, fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600);
  static const titleMd = TextStyle(fontFamily: sans, fontSize: 16, height: 22 / 16, fontWeight: FontWeight.w600);
  static const bodyLg = TextStyle(fontFamily: sans, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const bodyMd = TextStyle(fontFamily: sans, fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400);
  static const bodySm = TextStyle(fontFamily: sans, fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400);
  static const labelMd = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.24,
  );

  /// Uppercase section labels ("technical blueprint" look). Pass UPPERCASE text.
  static const labelSm = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  /// SKUs, IDs, weights, timestamps.
  static const monoMd = TextStyle(fontFamily: mono, fontSize: 13, height: 20 / 13, fontWeight: FontWeight.w400);
  static const monoLg = TextStyle(
    fontFamily: mono,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.28,
  );
  static const monoSm = TextStyle(fontFamily: mono, fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500);

  /// Uppercase mono labels with wide tracking (dark theme "label-caps").
  static const monoCaps = TextStyle(
    fontFamily: mono,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(DhColors.light, Brightness.light);
  static ThemeData dark() => _build(DhColors.dark, Brightness.dark);

  static ThemeData _build(DhColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.action,
      onPrimary: c.onAction,
      primaryContainer: c.navActive,
      onPrimaryContainer: c.onNavActive,
      secondary: c.accent,
      onSecondary: c.onAccent,
      secondaryContainer: c.accentSoft,
      onSecondaryContainer: c.text,
      tertiary: c.gold,
      onTertiary: c.onAction,
      error: c.danger,
      onError: b == Brightness.dark ? const Color(0xFF690005) : Colors.white,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.bg,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surfaceLow,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceHigh,
      surfaceContainerHighest: c.surfaceHighest,
      outline: c.borderStrong,
      outlineVariant: c.border,
      inverseSurface: c.text,
      onInverseSurface: c.bg,
      surfaceTint: Colors.transparent,
    );

    final radius6 = BorderRadius.circular(6);
    final radius8 = BorderRadius.circular(8);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: AppText.sans,
      splashFactory: InkSparkle.splashFactory,
      extensions: [c],
      textTheme: TextTheme(
        displaySmall: AppText.display,
        headlineMedium: AppText.headlineLg,
        headlineSmall: AppText.headlineMd,
        titleLarge: AppText.headlineSm,
        titleMedium: AppText.titleMd,
        titleSmall: AppText.labelMd,
        bodyLarge: AppText.bodyLg,
        bodyMedium: AppText.bodyMd,
        bodySmall: AppText.bodySm,
        labelLarge: AppText.labelMd.copyWith(fontSize: 14),
        labelMedium: AppText.labelMd,
        labelSmall: AppText.labelSm,
      ).apply(bodyColor: c.text, displayColor: c.text),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        titleTextStyle: AppText.headlineSm.copyWith(color: c.text),
        shape: Border(bottom: BorderSide(color: c.border)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius8,
          side: BorderSide(color: c.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.isDark ? c.surfaceLow : c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: AppText.bodyMd.copyWith(color: c.textFaint),
        labelStyle: AppText.bodyMd.copyWith(color: c.textMuted),
        floatingLabelStyle: AppText.labelMd.copyWith(color: c.accent),
        prefixIconColor: c.textFaint,
        suffixIconColor: c.textFaint,
        border: OutlineInputBorder(
          borderRadius: radius6,
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius6,
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius6,
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius6,
          borderSide: BorderSide(color: c.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: c.onAction,
          disabledBackgroundColor: c.surfaceHighest,
          disabledForegroundColor: c.textFaint,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius8),
          textStyle: AppText.titleMd.copyWith(fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: BorderSide(color: c.borderStrong),
          shape: RoundedRectangleBorder(borderRadius: radius8),
          textStyle: AppText.titleMd.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: AppText.labelMd.copyWith(fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: radius6),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.text)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.action,
        foregroundColor: c.onAction,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: radius8),
        extendedTextStyle: AppText.titleMd,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceLow,
        selectedColor: c.accentSoft,
        side: BorderSide(color: c.border),
        labelStyle: AppText.labelMd.copyWith(color: c.text),
        shape: RoundedRectangleBorder(borderRadius: radius6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.isDark ? c.surfaceLow : c.surface,
        indicatorColor: c.navActive,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppText.monoCaps.copyWith(
            fontSize: 10,
            color: s.contains(WidgetState.selected) ? (c.isDark ? c.gold : c.text) : c.textFaint,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? c.onNavActive : c.textFaint),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.isDark ? c.surfaceLow : c.surfaceLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.borderStrong,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius8),
        titleTextStyle: AppText.headlineSm.copyWith(color: c.text),
        contentTextStyle: AppText.bodyMd.copyWith(color: c.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.isDark ? c.surfaceHighest : const Color(0xFF131B2E),
        contentTextStyle: AppText.bodyMd.copyWith(color: c.isDark ? c.text : Colors.white),
        actionTextColor: c.gold,
        shape: RoundedRectangleBorder(borderRadius: radius8),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius8,
          side: BorderSide(color: c.border),
        ),
        textStyle: AppText.bodyMd.copyWith(color: c.text),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.textFaint),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.surfaceHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : null),
        checkColor: WidgetStatePropertyAll(c.onAccent),
        side: BorderSide(color: c.borderStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceHighest,
        circularTrackColor: c.surfaceHighest,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        textColor: c.text,
        titleTextStyle: AppText.titleMd.copyWith(color: c.text),
        subtitleTextStyle: AppText.bodySm.copyWith(color: c.textMuted),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.text,
        unselectedLabelColor: c.textFaint,
        indicatorColor: c.accent,
        dividerColor: c.border,
        labelStyle: AppText.labelMd.copyWith(fontSize: 13),
        unselectedLabelStyle: AppText.labelMd.copyWith(fontSize: 13),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.text, borderRadius: radius6),
        textStyle: AppText.bodySm.copyWith(color: c.bg),
      ),
    );
  }
}

extension DhThemeContext on BuildContext {
  /// Design tokens for the active theme: `context.c.accent`.
  DhColors get c => Theme.of(this).extension<DhColors>()!;
}

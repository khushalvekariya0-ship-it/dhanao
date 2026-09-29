import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'core/routes.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  runApp(const DhanaApp());
}

class DhanaApp extends StatelessWidget {
  const DhanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: app.themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'DhanaOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        initialRoute: Routes.splash,
        // Start on the splash alone (not '/' + '/splash'); it replaces itself with the dashboard.
        onGenerateInitialRoutes: (_) => [Routes.generate(const RouteSettings(name: Routes.splash))!],
        onGenerateRoute: Routes.generate,
        // iOS number pads have no Done key: tapping any empty area closes the keyboard.
        builder: (context, child) =>
            GestureDetector(onTap: () => FocusManager.instance.primaryFocus?.unfocus(), child: child),
      ),
    );
  }
}

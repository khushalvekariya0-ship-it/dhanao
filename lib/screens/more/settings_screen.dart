import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DetailScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DhCard(
            child: Row(children: [
              const DhAvatar(asset: Img.avatarRavi, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.userName, style: AppText.headlineSm),
                  Text(app.userRole, style: AppText.bodyMd.copyWith(color: c.textMuted)),
                  const SizedBox(height: 6),
                  Text('AuraForge India', style: AppText.monoSm.copyWith(color: c.textFaint)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Appearance'),
          const SizedBox(height: 10),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: app.themeMode,
            builder: (_, mode, _) => DhSegmented<ThemeMode>(
              options: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system],
              selected: mode,
              labelOf: (m) => switch (m) {
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
                ThemeMode.system => 'System',
              },
              onChanged: (m) => app.themeMode.value = m,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Light uses the DhanaOS system (navy + indigo). Dark uses Industrial Precision (gold on midnight blue).',
            style: AppText.bodySm.copyWith(color: c.textFaint),
          ),
          const SizedBox(height: 24),
          const SectionLabel('Preferences'),
          const SizedBox(height: 4),
          ToggleRow(
            icon: Icons.notifications_outlined,
            title: 'Push notifications',
            subtitle: 'Stage changes, delays and approvals',
            value: app.notificationsEnabled,
            onChanged: (v) => setState(() => app.notificationsEnabled = v),
          ),
          const SizedBox(height: 24),
          const SectionLabel('About'),
          const SizedBox(height: 8),
          DhCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              const KeyValueRow('App', 'DhanaOS', divider: true),
              const KeyValueRow('Version', '1.0.0 (1)', divider: true),
              KeyValueRow('Active jobs', '${app.activeJobs.length}', divider: true),
              KeyValueRow('Partners', '${app.partners.length}'),
            ]),
          ),
        ],
      ),
    );
  }
}

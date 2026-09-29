import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';
import '../jobs/jobs_screen.dart';
import '../shell/home_shell.dart';

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
            child: Row(
              children: [
                const DhAvatar(asset: Img.avatarRavi, size: 56),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.userName, style: AppText.headlineSm),
                      Text(app.userRole, style: AppText.bodyMd.copyWith(color: c.textMuted)),
                      const SizedBox(height: 6),
                      Text('AuraForge India', style: AppText.monoSm.copyWith(color: c.textFaint)),
                    ],
                  ),
                ),
              ],
            ),
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
          const SectionLabel('Workspace'),
          const SizedBox(height: 8),
          DhCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _LinkRow(
                  icon: Icons.precision_manufacturing_outlined,
                  label: 'Active jobs',
                  count: app.activeJobs.length,
                  onTap: () {
                    // Back to the shell's Orders tab, pre-filtered to active jobs.
                    jobsFilter.value = JobsFilter.active;
                    homeTab.value = HomeTabs.orders;
                    Navigator.popUntil(context, (r) => r.isFirst);
                  },
                ),
                Divider(height: 1, indent: 52, color: c.border),
                _LinkRow(
                  icon: Icons.hub_outlined,
                  label: 'Partners',
                  count: app.partners.length,
                  onTap: () => Navigator.pushNamed(context, Routes.partners),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable settings row: icon, label, count badge and a chevron.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c.textMuted),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: AppText.titleMd.copyWith(fontSize: 15))),
            Text('$count', style: AppText.monoLg.copyWith(color: c.textMuted)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: c.textFaint),
          ],
        ),
      ),
    );
  }
}

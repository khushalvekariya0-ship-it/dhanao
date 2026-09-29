import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_screen.dart';
import '../jobs/jobs_screen.dart';
import '../production/production_board_screen.dart';

/// Selected bottom-nav tab. Tabs can switch sections with `homeTab.value = 1`.
final ValueNotifier<int> homeTab = ValueNotifier(0);

class HomeTabs {
  HomeTabs._();

  static const dashboard = 0;
  static const production = 1;
  static const stock = 2;
  static const orders = 3;
}

/// Main app frame: top bar, drawer (the design's sidebar), bottom nav
/// (the design's mobile DASH / FLOW / STOCK / ORDERS bar).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _titles = ['Manufacturer Overview', 'Production Floor', 'Inventory', 'Orders'];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ValueListenableBuilder<int>(
      valueListenable: homeTab,
      builder: (context, tab, _) => PopScope(
        canPop: tab == HomeTabs.dashboard,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) homeTab.value = HomeTabs.dashboard;
        },
        child: Scaffold(
          drawer: const _AppDrawer(),
          appBar: AppBar(
            titleSpacing: 0,
            leading: Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.asset(Img.logo, width: 28, height: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DhanaOS', style: AppText.titleMd),
                  Text(_titles[tab].toUpperCase(), style: AppText.monoSm.copyWith(color: c.textFaint, fontSize: 10)),
                ]),
              ),
            ]),
            actions: [
              IconButton(
                tooltip: 'Search',
                icon: const Icon(Icons.search),
                onPressed: () => showSearch(context: context, delegate: JobSearchDelegate()),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => _showNotifications(context),
                icon: Badge(smallSize: 8, backgroundColor: c.danger, child: const Icon(Icons.notifications_none)),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, Routes.settings),
                  child: const DhAvatar(asset: Img.avatarRavi, size: 32),
                ),
              ),
            ],
          ),
          body: IndexedStack(
            index: tab,
            children: const [DashboardScreen(), ProductionBoardScreen(), InventoryScreen(), JobsScreen()],
          ),
          floatingActionButton: tab == HomeTabs.stock
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'new-job',
                  onPressed: () => Navigator.pushNamed(context, Routes.newJob),
                  icon: const Icon(Icons.add),
                  label: const Text('New Job'),
                ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
            child: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (i) => homeTab.value = i,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'DASH'),
                NavigationDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree), label: 'FLOW'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'STOCK'),
                NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'ORDERS'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final c = ctx.c;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (ctx, scroll) => ListenableBuilder(
            listenable: app,
            builder: (ctx, _) => ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                Text('Notifications', style: AppText.headlineSm),
                const SizedBox(height: 16),
                const SectionLabel('Needs your action'),
                const SizedBox(height: 8),
                for (final a in app.actions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.priority_high, color: a.kind == ActionKind.delay || a.kind == ActionKind.missing ? c.danger : c.accent),
                    title: Text(a.title, style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(a.subtitle),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, Routes.job, arguments: a.jobId);
                    },
                  ),
                const SizedBox(height: 12),
                const SectionLabel('Recent activity'),
                const SizedBox(height: 8),
                for (final a in app.activity.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.bolt_outlined, color: c.textFaint),
                    title: Text('${a.text} ${a.jobId}', style: AppText.bodyMd),
                    subtitle: Text('${Fmt.ago(a.time)} • ${a.by}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, Routes.job, arguments: a.jobId);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    void goTab(int i) {
      Navigator.pop(context);
      homeTab.value = i;
    }

    void push(String route) {
      Navigator.pop(context);
      Navigator.pushNamed(context, route);
    }

    Widget item(IconData icon, String label, VoidCallback onTap, {bool active = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: active ? c.navActive : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(icon, size: 22, color: active ? c.onNavActive : c.textMuted),
                const SizedBox(width: 14),
                Text(label, style: AppText.titleMd.copyWith(fontSize: 15, color: active ? c.onNavActive : c.text)),
              ]),
            ),
          ),
        ),
      );
    }

    final tab = homeTab.value;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.asset(Img.logo, width: 36, height: 36)),
                const SizedBox(width: 12),
                Text('DhanaOS', style: AppText.headlineSm),
              ]),
            ),
            item(Icons.dashboard_outlined, 'Dashboard', () => goTab(HomeTabs.dashboard), active: tab == HomeTabs.dashboard),
            item(Icons.account_tree_outlined, 'Production', () => goTab(HomeTabs.production), active: tab == HomeTabs.production),
            item(Icons.precision_manufacturing_outlined, 'Jobs', () => goTab(HomeTabs.orders), active: tab == HomeTabs.orders),
            item(Icons.inventory_2_outlined, 'Inventory', () => goTab(HomeTabs.stock), active: tab == HomeTabs.stock),
            item(Icons.hub_outlined, 'Partners', () => push(Routes.partners)),
            item(Icons.folder_shared_outlined, 'Files', () => push(Routes.files)),
            item(Icons.settings_outlined, 'Settings', () => push(Routes.settings)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Divider()),
            item(Icons.add_circle_outline, 'New Job', () => push(Routes.newJob)),
            item(Icons.edit_note, 'Create Inquiry', () => push(Routes.inquiry)),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
              child: Row(children: [
                const DhAvatar(asset: Img.avatarRavi, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.userName, style: AppText.titleMd),
                    Text(app.userRole, style: AppText.bodySm.copyWith(color: c.textMuted)),
                  ]),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: app.themeMode,
                  builder: (_, mode, _) => IconButton(
                    tooltip: 'Toggle theme',
                    icon: Icon(mode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                    onPressed: () => app.themeMode.value = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Global search over job id, title, customer and stage.
class JobSearchDelegate extends SearchDelegate<void> {
  JobSearchDelegate() : super(searchFieldLabel: 'Job ID, Customer, or Specialist');

  @override
  ThemeData appBarTheme(BuildContext context) {
    final t = Theme.of(context);
    return t.copyWith(inputDecorationTheme: t.inputDecorationTheme.copyWith(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none));
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty) IconButton(icon: const Icon(Icons.close), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) =>
      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final q = query.trim().toLowerCase();
    final list = app.jobs.where((j) {
      if (q.isEmpty) return true;
      return j.id.toLowerCase().contains(q) ||
          j.title.toLowerCase().contains(q) ||
          j.customer.toLowerCase().contains(q) ||
          j.stage.label.toLowerCase().contains(q) ||
          (j.assignee ?? '').toLowerCase().contains(q);
    }).toList();
    if (list.isEmpty) {
      return const EmptyState(icon: Icons.search_off, message: 'No jobs match your search.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => JobCard(
        job: list[i],
        onTap: () {
          close(context, null);
          Navigator.pushNamed(context, Routes.job, arguments: list[i].id);
        },
      ),
    );
  }
}

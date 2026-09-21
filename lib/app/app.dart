import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/dashboard/providers/reels_counter_provider.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/statistics/screens/statistics_screen.dart';
import 'theme.dart';

/// Root application widget. Wraps the app in [ChangeNotifierProvider] and
/// sets up Material 3 light/dark theming.
class ReelsCounterApp extends StatelessWidget {
  const ReelsCounterApp({
    super.key,
    required this.provider,
  });

  final ReelsCounterProvider provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReelsCounterProvider>.value(
      value: provider,
      child: MaterialApp(
        title: 'Reels Counter',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const _AppShell(),
      ),
    );
  }
}

/// Stateful shell that owns the bottom [NavigationBar] and switches between
/// the four top-level screens via an index. Screens are kept alive.
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    DashboardScreen(),
    HistoryScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Refresh permission statuses whenever the user returns from system
  /// settings screens (e.g., after granting Accessibility or overlay).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ReelsCounterProvider>().refreshOnResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Statistics',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

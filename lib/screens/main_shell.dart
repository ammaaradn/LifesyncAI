import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'health_tracker_screen.dart';
import 'insights_screen.dart';
import 'planner_screen.dart';
import 'smart_suggestions_screen.dart';

/// Persistent bottom navigation across the 5 main sections of the app.
///
/// Uses an [IndexedStack] rather than swapping widgets in and out, so each
/// tab keeps its scroll position and in-progress state when you switch away
/// and back. Profile isn't a tab here - it's reached via the icon in
/// [DashboardScreen]'s app bar, matching the usual "account/settings lives
/// off the main nav" convention.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(onNavigateToTab: _goToTab),
      const PlannerScreen(),
      const HealthTrackerScreen(),
      const InsightsScreen(),
      const SmartSuggestionsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Health',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Suggestions',
          ),
        ],
      ),
    );
  }
}

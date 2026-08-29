import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_log_model.dart';
import '../models/suggestion_model.dart';
import '../models/task_model.dart';
import '../providers/weather_provider.dart';
import '../routes.dart';
import '../services/firestore_service.dart';
import '../services/suggestion_engine.dart';
import '../theme.dart';

const _waterGoalGlasses = 8;
const _sleepGoalHours = 8.0;

/// Index of the Smart Suggestions tab within [MainShell] - used by the top
/// suggestion card to jump straight there.
const _suggestionsTabIndex = 4;

/// Today's summary + the single most important AI suggestion, up top.
///
/// Lives as the first tab of [MainShell]; [onNavigateToTab] lets it switch
/// the shell to another tab (e.g. tapping the top suggestion card jumps to
/// the full Smart Suggestions list) without pushing a new route.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onNavigateToTab});

  final ValueChanged<int>? onNavigateToTab;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService?>();
    final weatherProvider = context.watch<WeatherProvider>();
    final user = context.watch<User?>();
    final firstName = _firstNameOf(user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
          ),
        ],
      ),
      body: firestoreService == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<TaskModel>>(
              stream: firestoreService.tasksStream(),
              builder: (context, taskSnapshot) {
                final tasks = taskSnapshot.data ?? const <TaskModel>[];

                return StreamBuilder<HealthLogModel?>(
                  stream: firestoreService.todayHealthLogStream(),
                  builder: (context, healthSnapshot) {
                    final log = healthSnapshot.data;

                    return StreamBuilder<List<HealthLogModel>>(
                      stream: firestoreService.recentHealthLogsStream(),
                      builder: (context, recentSnapshot) {
                        final suggestions = SuggestionEngine.generate(
                          tasks: tasks,
                          todayLog: log,
                          recentLogs:
                              recentSnapshot.data ?? const <HealthLogModel>[],
                          weather: weatherProvider.weather,
                        );
                        final topSuggestion = suggestions.firstOrNull;
                        final completedTasks = tasks
                            .where((t) => t.completed)
                            .length;

                        return _DashboardBody(
                          firstName: firstName,
                          topSuggestion: topSuggestion,
                          onTopSuggestionTap: () =>
                              onNavigateToTab?.call(_suggestionsTabIndex),
                          log: log,
                          completedTasks: completedTasks,
                          totalTasks: tasks.length,
                          weatherProvider: weatherProvider,
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  String _firstNameOf(User? user) {
    final name = user?.displayName;
    if (name == null || name.trim().isEmpty) return 'there';
    return name.trim().split(' ').first;
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.firstName,
    required this.topSuggestion,
    required this.onTopSuggestionTap,
    required this.log,
    required this.completedTasks,
    required this.totalTasks,
    required this.weatherProvider,
  });

  final String firstName;
  final SuggestionModel? topSuggestion;
  final VoidCallback onTopSuggestionTap;
  final HealthLogModel? log;
  final int completedTasks;
  final int totalTasks;
  final WeatherProvider weatherProvider;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: weatherProvider.load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Hi, $firstName',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _TopSuggestionCard(
            suggestion: topSuggestion,
            onTap: onTopSuggestionTap,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Today's summary",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.3,
            children: [
              _StatTile(
                icon: Icons.water_drop_outlined,
                label: 'Water',
                value: '${log?.waterGlasses ?? 0}/$_waterGoalGlasses glasses',
                progress: (log?.waterGlasses ?? 0) / _waterGoalGlasses,
              ),
              _StatTile(
                icon: Icons.bedtime_outlined,
                label: 'Sleep',
                value: '${(log?.sleepHours ?? 0).toStringAsFixed(1)} hrs',
                progress: (log?.sleepHours ?? 0) / _sleepGoalHours,
              ),
              _StatTile(
                icon: Icons.mood_outlined,
                label: 'Mood',
                value: log?.mood?.emoji ?? '-',
              ),
              _StatTile(
                icon: Icons.directions_walk_outlined,
                label: 'Steps',
                value: '${log?.steps ?? 0}',
              ),
              _StatTile(
                icon: Icons.checklist_outlined,
                label: 'Tasks',
                value: '$completedTasks/$totalTasks done',
                progress: totalTasks == 0
                    ? 0
                    : completedTasks / totalTasks,
              ),
              _WeatherStatTile(weatherProvider: weatherProvider),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopSuggestionCard extends StatelessWidget {
  const _TopSuggestionCard({required this.suggestion, required this.onTap});

  final SuggestionModel? suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              suggestion?.icon ?? Icons.emoji_events_outlined,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOP SUGGESTION',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion?.title ?? "You're all caught up!",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestion?.message ??
                        'No suggestions right now - check back later.',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.progress,
  });

  final IconData icon;
  final String label;
  final String value;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (progress != null)
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: CircularProgressIndicator(
                      value: progress!.clamp(0, 1),
                      strokeWidth: 4,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.outlineVariant,
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                Icon(
                  icon,
                  color: AppColors.primary,
                  size: progress != null ? 18 : 26,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _WeatherStatTile extends StatelessWidget {
  const _WeatherStatTile({required this.weatherProvider});

  final WeatherProvider weatherProvider;

  @override
  Widget build(BuildContext context) {
    if (weatherProvider.isLoading) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final weather = weatherProvider.weather;
    if (weather == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: weatherProvider.load,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  color: context.textSecondaryColor,
                  size: 26,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Weather', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'Unavailable - tap to retry',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _StatTile(
      icon: weather.icon,
      label: weather.description,
      value: '${weather.currentTemperature.toStringAsFixed(0)}°C',
    );
  }
}

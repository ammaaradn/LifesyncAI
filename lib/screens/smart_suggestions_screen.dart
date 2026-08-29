import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_log_model.dart';
import '../models/suggestion_model.dart';
import '../models/task_model.dart';
import '../providers/weather_provider.dart';
import '../services/firestore_service.dart';
import '../services/suggestion_engine.dart';
import '../theme.dart';

/// Dedicated list of AI recommendations - the highlight feature. Combines
/// live task/health data (Firestore streams) with the shared [WeatherProvider]
/// and runs it all through [SuggestionEngine].
class SmartSuggestionsScreen extends StatelessWidget {
  const SmartSuggestionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService?>();
    final weatherProvider = context.watch<WeatherProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Suggestions'),
        actions: [
          IconButton(
            onPressed: weatherProvider.isLoading ? null : weatherProvider.load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh weather',
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
                    return StreamBuilder<List<HealthLogModel>>(
                      stream: firestoreService.recentHealthLogsStream(),
                      builder: (context, recentSnapshot) {
                        final suggestions = SuggestionEngine.generate(
                          tasks: tasks,
                          todayLog: healthSnapshot.data,
                          recentLogs:
                              recentSnapshot.data ?? const <HealthLogModel>[],
                          weather: weatherProvider.weather,
                        );

                        return RefreshIndicator(
                          onRefresh: weatherProvider.load,
                          child: ListView(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            children: [
                              if (weatherProvider.error != null)
                                _WeatherBanner(
                                  message: weatherProvider.error!,
                                  onRetry: weatherProvider.load,
                                ),
                              if (weatherProvider.isLoading)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                  ),
                                  child: LinearProgressIndicator(),
                                ),
                              if (suggestions.isEmpty &&
                                  !weatherProvider.isLoading)
                                const _EmptyState()
                              else
                                for (final suggestion in suggestions)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: _SuggestionCard(
                                      suggestion: suggestion,
                                    ),
                                  ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion});

  final SuggestionModel suggestion;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(suggestion.icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    suggestion.message,
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _WeatherBanner extends StatelessWidget {
  const _WeatherBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: context.textSecondaryColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$message Suggestions below are still based on your health '
              'and task data.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 56,
            color: context.textSecondaryColor,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No suggestions right now - log some health data or add tasks '
            'to get personalised advice.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

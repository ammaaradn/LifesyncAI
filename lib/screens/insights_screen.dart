import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/health_log_model.dart';
import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../theme.dart';

const _daysInWeek = 7;

/// One day's worth of combined stats, built locally from the health-logs
/// and tasks streams - used to feed every chart on this screen.
class _DayData {
  final DateTime date;
  final int waterGlasses;
  final double sleepHours;
  final Mood? mood;
  final int tasksCompleted;

  const _DayData({
    required this.date,
    required this.waterGlasses,
    required this.sleepHours,
    required this.mood,
    required this.tasksCompleted,
  });

  String get shortLabel => DateFormat('E').format(date);
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Charts for water, sleep, mood, and weekly task completion.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService?>();

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: firestoreService == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<HealthLogModel>>(
              stream: firestoreService.recentHealthLogsStream(
                days: _daysInWeek,
              ),
              builder: (context, healthSnapshot) {
                if (healthSnapshot.hasError) {
                  return const _MessageState(
                    icon: Icons.error_outline,
                    message:
                        'Could not load insights. Check your connection and '
                        'try again.',
                  );
                }
                if (!healthSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<List<TaskModel>>(
                  stream: firestoreService.tasksStream(),
                  builder: (context, taskSnapshot) {
                    final days = _buildWeekData(
                      healthSnapshot.data!,
                      taskSnapshot.data ?? const <TaskModel>[],
                    );

                    final hasAnyData = days.any(
                      (d) =>
                          d.waterGlasses > 0 ||
                          d.sleepHours > 0 ||
                          d.mood != null ||
                          d.tasksCompleted > 0,
                    );

                    if (!hasAnyData) {
                      return const _MessageState(
                        icon: Icons.bar_chart_outlined,
                        message:
                            'No data yet this week - log tasks and health '
                            'entries to see your trends here.',
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        _ChartCard(
                          title: 'Water intake this week',
                          takeaway: _waterTakeaway(days),
                          chart: _WaterBarChart(days: days),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ChartCard(
                          title: 'Sleep this week',
                          takeaway: _sleepTakeaway(days),
                          chart: _SleepLineChart(days: days),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ChartCard(
                          title: 'Mood trend',
                          takeaway: _moodTakeaway(days),
                          chart: _MoodChart(days: days),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _ChartCard(
                          title: 'Tasks completed',
                          takeaway: _tasksTakeaway(days),
                          chart: _TasksBarChart(days: days),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  List<_DayData> _buildWeekData(
    List<HealthLogModel> logs,
    List<TaskModel> tasks,
  ) {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);

    return List.generate(_daysInWeek, (index) {
      final date = startOfToday.subtract(
        Duration(days: _daysInWeek - 1 - index),
      );
      final log = logs.where((l) => _isSameDay(l.date, date)).firstOrNull;
      final completedThatDay = tasks
          .where((t) => t.completed && _isSameDay(t.time, date))
          .length;

      return _DayData(
        date: date,
        waterGlasses: log?.waterGlasses ?? 0,
        sleepHours: log?.sleepHours ?? 0,
        mood: log?.mood,
        tasksCompleted: completedThatDay,
      );
    });
  }
}

// ---------------------------------------------------------------------
// Takeaway text
// ---------------------------------------------------------------------

String _waterTakeaway(List<_DayData> days) {
  final total = days.fold<int>(0, (sum, d) => sum + d.waterGlasses);
  if (total == 0) return 'No water logged yet this week.';
  final avg = total / _daysInWeek;
  final goalDays = days.where((d) => d.waterGlasses >= 8).length;
  return 'You averaged ${avg.toStringAsFixed(1)} glasses/day this week, '
      'hitting your 8-glass goal on $goalDays of 7 days.';
}

String _sleepTakeaway(List<_DayData> days) {
  final logged = days.where((d) => d.sleepHours > 0).toList();
  if (logged.isEmpty) return 'No sleep logged yet this week.';
  final avg =
      logged.fold<double>(0, (sum, d) => sum + d.sleepHours) / logged.length;
  final goodDays = logged.where((d) => d.sleepHours >= 7).length;
  return 'Average sleep this week: ${avg.toStringAsFixed(1)} hrs - you got '
      '7+ hours on $goodDays of ${logged.length} logged days.';
}

String _moodTakeaway(List<_DayData> days) {
  final logged = days.where((d) => d.mood != null).toList();
  if (logged.isEmpty) return 'No mood logged yet this week.';
  final avgScore =
      logged.fold<int>(0, (sum, d) => sum + d.mood!.score) / logged.length;
  return 'You logged your mood on ${logged.length} of 7 days, averaging '
      '${avgScore.toStringAsFixed(1)}/5.';
}

String _tasksTakeaway(List<_DayData> days) {
  final total = days.fold<int>(0, (sum, d) => sum + d.tasksCompleted);
  if (total == 0) return 'No tasks completed yet this week.';
  var busiest = days.first;
  for (final d in days) {
    if (d.tasksCompleted > busiest.tasksCompleted) busiest = d;
  }
  return 'You completed $total task${total == 1 ? '' : 's'} this week - '
      'your busiest day was ${busiest.shortLabel}.';
}

// ---------------------------------------------------------------------
// Shared chart chrome
// ---------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.chart,
    required this.takeaway,
  });

  final String title;
  final Widget chart;
  final String takeaway;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            SizedBox(height: 160, child: chart),
            const SizedBox(height: AppSpacing.sm),
            Text(takeaway, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

AxisTitles _bottomDayLabels(BuildContext context, List<_DayData> days) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      getTitlesWidget: (value, meta) {
        final index = value.toInt();
        if (index < 0 || index >= days.length) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            days[index].shortLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        );
      },
    ),
  );
}

const _hiddenAxis = AxisTitles(sideTitles: SideTitles(showTitles: false));

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.textSecondaryColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Charts
// ---------------------------------------------------------------------

class _WaterBarChart extends StatelessWidget {
  const _WaterBarChart({required this.days});

  final List<_DayData> days;

  @override
  Widget build(BuildContext context) {
    final maxGlasses = days
        .map((d) => d.waterGlasses)
        .fold<int>(8, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxGlasses + 1,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: _hiddenAxis,
          topTitles: _hiddenAxis,
          rightTitles: _hiddenAxis,
          bottomTitles: _bottomDayLabels(context, days),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].waterGlasses.toDouble(),
                  color: AppColors.primary,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SleepLineChart extends StatelessWidget {
  const _SleepLineChart({required this.days});

  final List<_DayData> days;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < days.length; i++)
        if (days[i].sleepHours > 0) FlSpot(i.toDouble(), days[i].sleepHours),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 12,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: _hiddenAxis,
          topTitles: _hiddenAxis,
          rightTitles: _hiddenAxis,
          bottomTitles: _bottomDayLabels(context, days),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodChart extends StatelessWidget {
  const _MoodChart({required this.days});

  final List<_DayData> days;

  Color _colorForScore(int score) {
    if (score >= 4) return AppColors.success;
    if (score == 3) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < days.length; i++)
        if (days[i].mood != null)
          FlSpot(i.toDouble(), days[i].mood!.score.toDouble()),
    ];

    return LineChart(
      LineChartData(
        minY: 1,
        maxY: 5,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: _hiddenAxis,
          topTitles: _hiddenAxis,
          rightTitles: _hiddenAxis,
          bottomTitles: _bottomDayLabels(context, days),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Theme.of(context).colorScheme.outlineVariant,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 6,
                color: _colorForScore(spot.y.round()),
                strokeWidth: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksBarChart extends StatelessWidget {
  const _TasksBarChart({required this.days});

  final List<_DayData> days;

  @override
  Widget build(BuildContext context) {
    final maxTasks = days
        .map((d) => d.tasksCompleted)
        .fold<int>(3, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: maxTasks + 1,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: _hiddenAxis,
          topTitles: _hiddenAxis,
          rightTitles: _hiddenAxis,
          bottomTitles: _bottomDayLabels(context, days),
        ),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].tasksCompleted.toDouble(),
                  color: AppColors.secondary,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

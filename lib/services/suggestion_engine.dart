import 'package:flutter/material.dart';

import '../models/health_log_model.dart';
import '../models/suggestion_model.dart';
import '../models/task_model.dart';
import '../models/weather_model.dart';

/// LifeSync AI's "smart suggestions" feature - despite the name, this is
/// **not** machine learning. It's a plain rule-based recommendation engine:
/// a fixed set of if/then rules that read the user's logged health data,
/// their tasks, the weather, and the current time, and turn any matching
/// condition into a [SuggestionModel] the UI can display.
///
/// Every rule lives in its own private method below, each returning either
/// a suggestion (the rule fired) or `null` (it didn't apply right now).
/// [generate] just runs all of them and collects whichever aren't null.
class SuggestionEngine {
  /// Runs every rule and returns the suggestions that currently apply,
  /// most important first (see [SuggestionModel.priority]).
  ///
  /// - [tasks]: the user's tasks (used for pending-count and
  ///   completion-time-pattern rules).
  /// - [todayLog]: today's health log, or null if nothing's been logged yet.
  /// - [recentLogs]: the last several days of health logs (today included is
  ///   fine — the personal-baseline rules exclude it themselves). Used to
  ///   compute each user's own averages; rules that need it simply don't
  ///   fire until there's enough history (see "cold start" note below).
  /// - [weather]: current + today's forecast, or null if it couldn't be
  ///   fetched (weather-based rules are simply skipped in that case).
  /// - [now]: defaults to the real current time; overridable for testing.
  static List<SuggestionModel> generate({
    required List<TaskModel> tasks,
    HealthLogModel? todayLog,
    List<HealthLogModel> recentLogs = const [],
    WeatherModel? weather,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();

    final suggestions = <SuggestionModel?>[
      _lowSleepRule(todayLog),
      _lowMoodRule(todayLog),
      _noWaterInAWhileRule(todayLog, currentTime),
      _rainForecastRule(weather),
      _hotWeatherRule(weather),
      _coldWeatherRule(weather),
      _lowStepsByEveningRule(todayLog, currentTime),
      _noWorkoutByEveningRule(todayLog, currentTime),
      _manyPendingTasksRule(tasks),
      _eveningFocusPatternRule(tasks),
      _allTasksDoneRule(tasks),
      // Personal-baseline rules — these are the ones that make the engine
      // adapt to *this* user specifically, not just apply fixed thresholds.
      _belowPersonalWaterAverageRule(todayLog, recentLogs, currentTime),
      _belowPersonalSleepAverageRule(todayLog, recentLogs, currentTime),
      _belowPersonalStepsAverageRule(todayLog, recentLogs, currentTime),
    ].whereType<SuggestionModel>().toList();

    suggestions.sort((a, b) => a.priority.compareTo(b.priority));
    return suggestions;
  }

  static bool _isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Minimum number of past logged days before a personal-baseline rule
  /// will fire — without this, day one's average would just be that one
  /// day's value, which isn't a meaningful "usual" to compare against. This
  /// is the classic recommendation-system "cold start" problem: the engine
  /// needs some history before it can personalise.
  static const _minHistoryDaysForBaseline = 3;

  // ---------------------------------------------------------------------
  // Health-log rules
  // ---------------------------------------------------------------------

  /// Rule: slept under 6 hours -> suggest an easier day.
  static SuggestionModel? _lowSleepRule(HealthLogModel? todayLog) {
    final sleepHours = todayLog?.sleepHours ?? 0;
    if (sleepHours <= 0 || sleepHours >= 6) return null;

    return SuggestionModel(
      icon: Icons.bedtime_outlined,
      title: 'Low sleep last night',
      message:
          'You slept only ${sleepHours.toStringAsFixed(1)} hours. '
          'Schedule a lighter workout today.',
      priority: 1,
    );
  }

  /// Rule: logged mood is low/terrible -> suggest a mood-lifting break.
  static SuggestionModel? _lowMoodRule(HealthLogModel? todayLog) {
    final mood = todayLog?.mood;
    if (mood != Mood.low && mood != Mood.terrible) return null;

    return const SuggestionModel(
      icon: Icons.self_improvement_outlined,
      title: 'Feeling low?',
      message:
          'A short walk, some music, or a quick chat with a friend might '
          'help lift your mood.',
      priority: 1,
    );
  }

  /// Rule: no water logged in the last 4+ hours -> nudge a glass now.
  ///
  /// If nothing's been logged at all today, we approximate "day start" as
  /// 7 AM so the reminder can still fire before any water is ever logged.
  static SuggestionModel? _noWaterInAWhileRule(
    HealthLogModel? todayLog,
    DateTime now,
  ) {
    final lastLog = todayLog?.lastWaterLogAt;
    final hoursSinceLastDrink = lastLog != null
        ? now.difference(lastLog).inHours
        : now.hour - 7;

    if (hoursSinceLastDrink < 4) return null;

    return const SuggestionModel(
      icon: Icons.water_drop_outlined,
      title: 'Stay hydrated',
      message: "You haven't had water in a while. Drink a glass now.",
      priority: 2,
    );
  }

  /// Rule: hasn't hit 3000 steps by 5 PM -> suggest a short walk.
  static SuggestionModel? _lowStepsByEveningRule(
    HealthLogModel? todayLog,
    DateTime now,
  ) {
    if (now.hour < 17) return null;
    final steps = todayLog?.steps ?? 0;
    if (steps >= 3000) return null;

    return SuggestionModel(
      icon: Icons.directions_walk_outlined,
      title: 'Low activity today',
      message:
          "You've only logged $steps steps today. A short walk could help "
          'you hit your goal.',
      priority: 3,
    );
  }

  /// Rule: no workout logged by 6 PM -> suggest a quick session.
  static SuggestionModel? _noWorkoutByEveningRule(
    HealthLogModel? todayLog,
    DateTime now,
  ) {
    if (now.hour < 18) return null;
    if (todayLog?.workoutDone ?? false) return null;

    return const SuggestionModel(
      icon: Icons.fitness_center_outlined,
      title: 'No workout yet',
      message:
          "You haven't logged a workout today. Even a quick 15-minute "
          'session counts.',
      priority: 3,
    );
  }

  // ---------------------------------------------------------------------
  // Weather rules
  // ---------------------------------------------------------------------

  /// Rule: 50%+ chance of rain today -> suggest moving outdoor plans
  /// indoors.
  static SuggestionModel? _rainForecastRule(WeatherModel? weather) {
    if (weather == null || !weather.willLikelyRain) return null;

    return SuggestionModel(
      icon: Icons.umbrella,
      title: 'Rain expected',
      message:
          'It may rain near you today '
          '(${weather.todayMaxPrecipitationProbability}% chance). Consider '
          'moving your outdoor walk indoors.',
      priority: 2,
    );
  }

  /// Rule: current temperature is 30°C+ -> suggest avoiding peak heat.
  static SuggestionModel? _hotWeatherRule(WeatherModel? weather) {
    if (weather == null || weather.currentTemperature < 30) return null;

    return SuggestionModel(
      icon: Icons.wb_sunny,
      title: 'Hot outside',
      message:
          "It's ${weather.currentTemperature.toStringAsFixed(0)}°C right "
          'now. Stay hydrated and avoid outdoor activity during peak heat.',
      priority: 3,
    );
  }

  /// Rule: current temperature is 15°C or below -> suggest dressing warm.
  static SuggestionModel? _coldWeatherRule(WeatherModel? weather) {
    if (weather == null || weather.currentTemperature > 15) return null;

    return SuggestionModel(
      icon: Icons.ac_unit,
      title: 'Chilly today',
      message:
          "It's only ${weather.currentTemperature.toStringAsFixed(0)}°C. "
          "Dress warmly if you're heading out.",
      priority: 4,
    );
  }

  // ---------------------------------------------------------------------
  // Task rules
  // ---------------------------------------------------------------------

  /// Rule: 5+ tasks still pending -> suggest prioritising.
  static SuggestionModel? _manyPendingTasksRule(List<TaskModel> tasks) {
    final pending = tasks.where((t) => !t.completed).length;
    if (pending < 5) return null;

    return SuggestionModel(
      icon: Icons.checklist_outlined,
      title: 'Busy day ahead',
      message:
          'You have $pending tasks pending today. Try tackling the top 3 '
          'first.',
      priority: 3,
    );
  }

  /// Rule: most completed tasks were scheduled after 7 PM -> the user's
  /// habit is evening focus work, so suggest leaning into that.
  /// Needs at least 3 completed tasks to have a meaningful pattern.
  static SuggestionModel? _eveningFocusPatternRule(List<TaskModel> tasks) {
    final completed = tasks.where((t) => t.completed).toList();
    if (completed.length < 3) return null;

    final eveningCount = completed.where((t) => t.time.hour >= 19).length;
    if (eveningCount / completed.length <= 0.5) return null;

    return const SuggestionModel(
      icon: Icons.nightlight_outlined,
      title: 'Evening focus',
      message: 'You complete tasks best after 7 PM. Schedule focus work then.',
      priority: 4,
    );
  }

  /// Rule: every task today is completed -> celebrate instead of nagging.
  static SuggestionModel? _allTasksDoneRule(List<TaskModel> tasks) {
    if (tasks.isEmpty || !tasks.every((t) => t.completed)) return null;

    return const SuggestionModel(
      icon: Icons.celebration_outlined,
      title: 'All done!',
      message: "Great job - you've completed all your tasks today.",
      priority: 5,
    );
  }

  // ---------------------------------------------------------------------
  // Personal-baseline rules ("learns from user behaviour")
  //
  // Unlike the fixed-threshold rules above (e.g. "sleep < 6h"), these
  // compare today against *this user's own* recent average, computed from
  // their logged history. Each one only fires once the fixed rule for the
  // same metric didn't already — so a day is never flagged twice for the
  // same reason, just via two different kinds of reasoning: a clinical
  // threshold, or a personal pattern.
  // ---------------------------------------------------------------------

  /// Rule: by evening, today's water is meaningfully below this user's own
  /// recent average (and the fixed "no water in a while" rule didn't
  /// already cover it, since that only fires when nothing's been logged).
  static SuggestionModel? _belowPersonalWaterAverageRule(
    HealthLogModel? todayLog,
    List<HealthLogModel> recentLogs,
    DateTime now,
  ) {
    if (now.hour < 19) return null;
    final todayGlasses = todayLog?.waterGlasses ?? 0;
    if (todayGlasses == 0) return null;

    final history = recentLogs
        .where((l) => l.waterGlasses > 0 && !_isSameCalendarDay(l.date, now))
        .toList();
    if (history.length < _minHistoryDaysForBaseline) return null;

    final average =
        history.fold<int>(0, (sum, l) => sum + l.waterGlasses) /
        history.length;
    if (todayGlasses >= average * 0.7) return null;

    return SuggestionModel(
      icon: Icons.water_drop_outlined,
      title: 'Below your usual pace',
      message:
          "You've usually had about ${average.toStringAsFixed(1)} glasses "
          "by now, but you're at $todayGlasses today. Try to catch up "
          'before bed.',
      priority: 3,
    );
  }

  /// Rule: slept 6h+ (so the fixed low-sleep rule didn't fire), but still
  /// notably less than this user's own recent average.
  static SuggestionModel? _belowPersonalSleepAverageRule(
    HealthLogModel? todayLog,
    List<HealthLogModel> recentLogs,
    DateTime now,
  ) {
    final todaySleep = todayLog?.sleepHours ?? 0;
    if (todaySleep < 6) return null;

    final history = recentLogs
        .where((l) => l.sleepHours > 0 && !_isSameCalendarDay(l.date, now))
        .toList();
    if (history.length < _minHistoryDaysForBaseline) return null;

    final average =
        history.fold<double>(0, (sum, l) => sum + l.sleepHours) /
        history.length;
    if (todaySleep >= average - 1) return null;

    return SuggestionModel(
      icon: Icons.bedtime_outlined,
      title: 'Less sleep than usual',
      message:
          'You usually sleep about ${average.toStringAsFixed(1)} hours - '
          'last night was ${todaySleep.toStringAsFixed(1)}. Consider an '
          'earlier night tonight.',
      priority: 2,
    );
  }

  /// Rule: hit 3000+ steps (so the fixed low-activity rule didn't fire),
  /// but still notably below this user's own recent average by evening.
  static SuggestionModel? _belowPersonalStepsAverageRule(
    HealthLogModel? todayLog,
    List<HealthLogModel> recentLogs,
    DateTime now,
  ) {
    if (now.hour < 19) return null;
    final todaySteps = todayLog?.steps ?? 0;
    if (todaySteps < 3000) return null;

    final history = recentLogs
        .where((l) => l.steps > 0 && !_isSameCalendarDay(l.date, now))
        .toList();
    if (history.length < _minHistoryDaysForBaseline) return null;

    final average =
        history.fold<int>(0, (sum, l) => sum + l.steps) / history.length;
    if (todaySteps >= average * 0.7) return null;

    return SuggestionModel(
      icon: Icons.directions_walk_outlined,
      title: 'Below your usual activity',
      message:
          'You usually take about ${average.toStringAsFixed(0)} steps by '
          "now - today you're at $todaySteps. A short walk could help "
          'close the gap.',
      priority: 4,
    );
  }
}

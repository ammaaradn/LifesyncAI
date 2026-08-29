// Unit tests for SuggestionEngine — the rule-based "AI" at the core of the
// app. Pure Dart logic, no Firebase involved, so every rule can be tested
// in isolation with hand-built model instances and a fixed `now`.

import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_ai/models/health_log_model.dart';
import 'package:lifesync_ai/models/task_model.dart';
import 'package:lifesync_ai/models/weather_model.dart';
import 'package:lifesync_ai/services/suggestion_engine.dart';

HealthLogModel _log({
  DateTime? date,
  int water = 0,
  double sleep = 0,
  Mood? mood,
  int steps = 0,
  bool workout = false,
  DateTime? lastWaterLogAt,
}) {
  return HealthLogModel(
    id: 'log',
    date: date ?? DateTime(2026, 1, 8),
    waterGlasses: water,
    sleepHours: sleep,
    mood: mood,
    steps: steps,
    workoutDone: workout,
    lastWaterLogAt: lastWaterLogAt,
  );
}

TaskModel _task({
  required DateTime time,
  bool completed = false,
  bool reminder = true,
  String title = 'Task',
}) {
  return TaskModel(
    id: 'task',
    title: title,
    time: time,
    reminderEnabled: reminder,
    completed: completed,
  );
}

WeatherModel _weather({double temp = 20, int rainChance = 0}) {
  return WeatherModel(
    currentTemperature: temp,
    weatherCode: 0,
    isDay: true,
    todayMaxTemp: temp,
    todayMinTemp: temp,
    todayMaxPrecipitationProbability: rainChance,
    fetchedAt: DateTime(2026, 1, 8),
  );
}

bool _hasTitle(List<dynamic> suggestions, String title) =>
    suggestions.any((s) => s.title == title);

void main() {
  // A fixed "now" so time-of-day-gated rules are deterministic.
  final morning = DateTime(2026, 1, 8, 8, 0);
  final evening = DateTime(2026, 1, 8, 20, 0);

  group('low sleep rule', () {
    test('fires when sleep is between 0 and 6 hours', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(sleep: 4.5),
        now: morning,
      );
      expect(_hasTitle(result, 'Low sleep last night'), isTrue);
    });

    test('does not fire at exactly 6 hours or above', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(sleep: 6),
        now: morning,
      );
      expect(_hasTitle(result, 'Low sleep last night'), isFalse);
    });

    test('does not fire when nothing has been logged (sleep is 0)', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(sleep: 0),
        now: morning,
      );
      expect(_hasTitle(result, 'Low sleep last night'), isFalse);
    });
  });

  group('low mood rule', () {
    test('fires for low and terrible moods', () {
      for (final mood in [Mood.low, Mood.terrible]) {
        final result = SuggestionEngine.generate(
          tasks: const [],
          todayLog: _log(mood: mood),
          now: morning,
        );
        expect(_hasTitle(result, 'Feeling low?'), isTrue, reason: '$mood');
      }
    });

    test('does not fire for okay, good, or great moods', () {
      for (final mood in [Mood.okay, Mood.good, Mood.great]) {
        final result = SuggestionEngine.generate(
          tasks: const [],
          todayLog: _log(mood: mood),
          now: morning,
        );
        expect(_hasTitle(result, 'Feeling low?'), isFalse, reason: '$mood');
      }
    });
  });

  group('no water in a while rule', () {
    test('fires when nothing logged yet and it is well past 11 AM', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: null,
        now: DateTime(2026, 1, 8, 12, 0), // 12 - 7 (assumed day start) = 5h
      );
      expect(_hasTitle(result, 'Stay hydrated'), isTrue);
    });

    test('does not fire within 4 hours of the last logged glass', () {
      final now = DateTime(2026, 1, 8, 12, 0);
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(
          water: 3,
          lastWaterLogAt: now.subtract(const Duration(hours: 1)),
        ),
        now: now,
      );
      expect(_hasTitle(result, 'Stay hydrated'), isFalse);
    });

    test('fires 4+ hours after the last logged glass', () {
      final now = DateTime(2026, 1, 8, 12, 0);
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(
          water: 3,
          lastWaterLogAt: now.subtract(const Duration(hours: 5)),
        ),
        now: now,
      );
      expect(_hasTitle(result, 'Stay hydrated'), isTrue);
    });
  });

  group('weather rules', () {
    test('rain rule fires at 50%+ chance, not below', () {
      final rainy = SuggestionEngine.generate(
        tasks: const [],
        weather: _weather(rainChance: 60),
        now: morning,
      );
      final dry = SuggestionEngine.generate(
        tasks: const [],
        weather: _weather(rainChance: 40),
        now: morning,
      );
      expect(_hasTitle(rainy, 'Rain expected'), isTrue);
      expect(_hasTitle(dry, 'Rain expected'), isFalse);
    });

    test('hot weather rule fires at 30C+, cold rule at 15C or below', () {
      final hot = SuggestionEngine.generate(
        tasks: const [],
        weather: _weather(temp: 32),
        now: morning,
      );
      final cold = SuggestionEngine.generate(
        tasks: const [],
        weather: _weather(temp: 10),
        now: morning,
      );
      final mild = SuggestionEngine.generate(
        tasks: const [],
        weather: _weather(temp: 22),
        now: morning,
      );
      expect(_hasTitle(hot, 'Hot outside'), isTrue);
      expect(_hasTitle(cold, 'Chilly today'), isTrue);
      expect(_hasTitle(mild, 'Hot outside'), isFalse);
      expect(_hasTitle(mild, 'Chilly today'), isFalse);
    });

    test('no weather rules fire when weather is null (fetch failed)', () {
      final result = SuggestionEngine.generate(tasks: const [], now: morning);
      expect(_hasTitle(result, 'Rain expected'), isFalse);
      expect(_hasTitle(result, 'Hot outside'), isFalse);
      expect(_hasTitle(result, 'Chilly today'), isFalse);
    });
  });

  group('task rules', () {
    test('busy day rule fires at 5+ pending tasks', () {
      final tasks = List.generate(
        5,
        (i) => _task(time: morning, completed: false),
      );
      final result = SuggestionEngine.generate(tasks: tasks, now: morning);
      expect(_hasTitle(result, 'Busy day ahead'), isTrue);
    });

    test('evening focus pattern needs 3+ completed tasks, majority evening', () {
      final mostlyEvening = [
        _task(time: DateTime(2026, 1, 8, 20), completed: true),
        _task(time: DateTime(2026, 1, 8, 21), completed: true),
        _task(time: DateTime(2026, 1, 8, 9), completed: true),
      ];
      final tooFew = [
        _task(time: DateTime(2026, 1, 8, 20), completed: true),
        _task(time: DateTime(2026, 1, 8, 21), completed: true),
      ];
      expect(
        _hasTitle(
          SuggestionEngine.generate(tasks: mostlyEvening, now: morning),
          'Evening focus',
        ),
        isTrue,
      );
      expect(
        _hasTitle(
          SuggestionEngine.generate(tasks: tooFew, now: morning),
          'Evening focus',
        ),
        isFalse,
      );
    });

    test('all-done rule fires only when every task is completed', () {
      final allDone = [
        _task(time: morning, completed: true),
        _task(time: morning, completed: true),
      ];
      final oneLeft = [
        _task(time: morning, completed: true),
        _task(time: morning, completed: false),
      ];
      expect(
        _hasTitle(SuggestionEngine.generate(tasks: allDone, now: morning), 'All done!'),
        isTrue,
      );
      expect(
        _hasTitle(SuggestionEngine.generate(tasks: oneLeft, now: morning), 'All done!'),
        isFalse,
      );
      expect(
        _hasTitle(SuggestionEngine.generate(tasks: const [], now: morning), 'All done!'),
        isFalse,
        reason: 'an empty task list is not "all done"',
      );
    });
  });

  group('personal-baseline rules (learning from user behaviour)', () {
    List<HealthLogModel> historyOf(int days, {int water = 0, double sleep = 0, int steps = 0}) {
      return List.generate(
        days,
        (i) => _log(
          date: DateTime(2026, 1, 1 + i),
          water: water,
          sleep: sleep,
          steps: steps,
        ),
      );
    }

    test('water baseline rule needs 3+ days of history (cold start)', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(water: 2),
        recentLogs: historyOf(2, water: 10),
        now: evening,
      );
      expect(_hasTitle(result, 'Below your usual pace'), isFalse);
    });

    test('water baseline rule fires when notably below personal average', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(water: 3),
        recentLogs: historyOf(5, water: 10),
        now: evening,
      );
      expect(_hasTitle(result, 'Below your usual pace'), isTrue);
    });

    test('water baseline rule does not fire when close to the average', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(water: 8),
        recentLogs: historyOf(5, water: 10),
        now: evening,
      );
      expect(_hasTitle(result, 'Below your usual pace'), isFalse);
    });

    test('sleep baseline rule only applies once the fixed low-sleep rule '
        'has not already fired (sleep >= 6h)', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(sleep: 5), // fixed rule covers this instead
        recentLogs: historyOf(5, sleep: 8),
        now: evening,
      );
      expect(_hasTitle(result, 'Less sleep than usual'), isFalse);
      expect(_hasTitle(result, 'Low sleep last night'), isTrue);
    });

    test('sleep baseline rule fires for 6h+ sleep that is still notably '
        'below the personal average', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(sleep: 6.5),
        recentLogs: historyOf(5, sleep: 8.5),
        now: evening,
      );
      expect(_hasTitle(result, 'Less sleep than usual'), isTrue);
    });

    test("today's own entry inside recentLogs does not skew its own "
        'baseline (recentHealthLogsStream includes today) - chosen so the '
        'rule only fires if today is correctly excluded from the average', () {
      final today = DateTime(2026, 1, 8);
      final recentLogsIncludingToday = [
        ...historyOf(3, water: 20),
        _log(date: today, water: 13), // today's own entry
      ];
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(date: today, water: 13),
        recentLogs: recentLogsIncludingToday,
        now: DateTime(2026, 1, 8, 20),
      );
      // Correct: average of the 3 past days (20) -> threshold 14 -> 13 < 14
      // fires. Buggy (today wrongly included in its own average): average
      // 18.25 -> threshold ~12.8 -> 13 >= that -> would NOT fire.
      expect(_hasTitle(result, 'Below your usual pace'), isTrue);
    });

    test('steps baseline rule fires only in the evening and below average', () {
      final tooEarly = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(steps: 3500),
        recentLogs: historyOf(5, steps: 9000),
        now: morning,
      );
      final eveningBelowAverage = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(steps: 3500),
        recentLogs: historyOf(5, steps: 9000),
        now: evening,
      );
      expect(_hasTitle(tooEarly, 'Below your usual activity'), isFalse);
      expect(_hasTitle(eveningBelowAverage, 'Below your usual activity'), isTrue);
    });
  });

  group('generate() ordering', () {
    test('returns suggestions sorted by ascending priority', () {
      final result = SuggestionEngine.generate(
        tasks: const [],
        todayLog: _log(sleep: 4), // priority 1
        weather: _weather(rainChance: 80), // priority 2
        now: morning,
      );
      final priorities = result.map((s) => s.priority).toList();
      final sorted = [...priorities]..sort();
      expect(priorities, sorted);
    });
  });
}

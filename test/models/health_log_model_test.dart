import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_ai/models/health_log_model.dart';

void main() {
  group('Mood', () {
    test('score ranks great highest and terrible lowest, 5 down to 1', () {
      expect(Mood.great.score, 5);
      expect(Mood.good.score, 4);
      expect(Mood.okay.score, 3);
      expect(Mood.low.score, 2);
      expect(Mood.terrible.score, 1);
    });
  });

  group('HealthLogModel', () {
    test('toMap/fromMap round-trips all fields, including mood and '
        'lastWaterLogAt', () {
      final date = DateTime(2026, 3, 5);
      final lastWaterLogAt = DateTime(2026, 3, 5, 15, 0);
      final original = HealthLogModel(
        id: '2026-03-05',
        date: date,
        waterGlasses: 5,
        sleepHours: 7.5,
        mood: Mood.good,
        steps: 6200,
        workoutDone: true,
        lastWaterLogAt: lastWaterLogAt,
      );

      final restored = HealthLogModel.fromMap(original.id, original.toMap());

      expect(restored.id, original.id);
      expect(restored.date, date);
      expect(restored.waterGlasses, 5);
      expect(restored.sleepHours, 7.5);
      expect(restored.mood, Mood.good);
      expect(restored.steps, 6200);
      expect(restored.workoutDone, isTrue);
      expect(restored.lastWaterLogAt, lastWaterLogAt);
    });

    test('fromMap fills in sensible defaults for missing fields', () {
      final restored = HealthLogModel.fromMap('id', const {});

      expect(restored.waterGlasses, 0);
      expect(restored.sleepHours, 0);
      expect(restored.mood, isNull);
      expect(restored.steps, 0);
      expect(restored.workoutDone, isFalse);
      expect(restored.lastWaterLogAt, isNull);
    });

    test('fromMap falls back to okay for an unrecognised mood string', () {
      final restored = HealthLogModel.fromMap('id', {'mood': 'ecstatic'});
      expect(restored.mood, Mood.okay);
    });

    test('toMap omits lastWaterLogAt as null when never logged', () {
      final log = HealthLogModel(id: 'id', date: DateTime(2026, 1, 1));
      expect(log.toMap()['lastWaterLogAt'], isNull);
    });
  });
}

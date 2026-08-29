import 'package:flutter_test/flutter_test.dart';
import 'package:lifesync_ai/models/task_model.dart';

void main() {
  group('TaskModel', () {
    test('toMap/fromMap round-trips all fields', () {
      final time = DateTime(2026, 3, 5, 14, 30);
      final original = TaskModel(
        id: 'abc123',
        title: 'Buy groceries',
        time: time,
        reminderEnabled: true,
        completed: false,
      );

      final restored = TaskModel.fromMap(original.id, original.toMap());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.time, time);
      expect(restored.reminderEnabled, isTrue);
      expect(restored.completed, isFalse);
    });

    test('fromMap fills in sensible defaults for missing fields', () {
      final restored = TaskModel.fromMap('id', const {});

      expect(restored.title, '');
      expect(restored.reminderEnabled, isTrue);
      expect(restored.completed, isFalse);
    });

    test('copyWith only changes the given fields', () {
      final original = TaskModel(
        id: 'id',
        title: 'Original',
        time: DateTime(2026, 1, 1, 9),
        reminderEnabled: true,
        completed: false,
      );

      final updated = original.copyWith(completed: true);

      expect(updated.id, original.id);
      expect(updated.title, original.title);
      expect(updated.time, original.time);
      expect(updated.reminderEnabled, original.reminderEnabled);
      expect(updated.completed, isTrue);
    });
  });
}

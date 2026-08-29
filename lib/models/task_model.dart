import 'package:cloud_firestore/cloud_firestore.dart';

/// A single planner task, stored at `users/{uid}/tasks/{taskId}`.
class TaskModel {
  final String id;
  final String title;
  final DateTime time;
  final bool reminderEnabled;
  final bool completed;

  const TaskModel({
    required this.id,
    required this.title,
    required this.time,
    this.reminderEnabled = true,
    this.completed = false,
  });

  factory TaskModel.fromMap(String id, Map<String, dynamic> map) {
    return TaskModel(
      id: id,
      title: map['title'] as String? ?? '',
      time: (map['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reminderEnabled: map['reminderEnabled'] as bool? ?? true,
      completed: map['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'time': Timestamp.fromDate(time),
      'reminderEnabled': reminderEnabled,
      'completed': completed,
    };
  }

  TaskModel copyWith({
    String? title,
    DateTime? time,
    bool? reminderEnabled,
    bool? completed,
  }) {
    return TaskModel(
      id: id,
      title: title ?? this.title,
      time: time ?? this.time,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      completed: completed ?? this.completed,
    );
  }
}

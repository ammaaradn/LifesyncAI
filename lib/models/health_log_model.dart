import 'package:cloud_firestore/cloud_firestore.dart';

/// One recognised mood value, used by the mood emoji picker and Insights
/// charts. Kept as plain strings in Firestore for simplicity.
enum Mood { great, good, okay, low, terrible }

extension MoodX on Mood {
  String get emoji {
    switch (this) {
      case Mood.great:
        return '😄';
      case Mood.good:
        return '🙂';
      case Mood.okay:
        return '😐';
      case Mood.low:
        return '😔';
      case Mood.terrible:
        return '😣';
    }
  }

  /// Numeric score (1-5) so mood can be plotted on a line chart in Insights.
  int get score => 5 - Mood.values.indexOf(this);

  /// Human-readable label, used for screen readers on the mood picker
  /// (the emoji alone isn't a reliable accessible name).
  String get label {
    switch (this) {
      case Mood.great:
        return 'Great';
      case Mood.good:
        return 'Good';
      case Mood.okay:
        return 'Okay';
      case Mood.low:
        return 'Low';
      case Mood.terrible:
        return 'Terrible';
    }
  }
}

/// A day's worth of health tracking, stored at
/// `users/{uid}/healthLogs/{yyyy-MM-dd}` - one document per calendar day,
/// so logging throughout the day just updates fields on the same doc.
class HealthLogModel {
  final String id; // yyyy-MM-dd
  final DateTime date;
  final int waterGlasses;
  final double sleepHours;
  final Mood? mood;
  final int steps;
  final bool workoutDone;
  final DateTime? lastWaterLogAt;

  const HealthLogModel({
    required this.id,
    required this.date,
    this.waterGlasses = 0,
    this.sleepHours = 0,
    this.mood,
    this.steps = 0,
    this.workoutDone = false,
    this.lastWaterLogAt,
  });

  factory HealthLogModel.fromMap(String id, Map<String, dynamic> map) {
    final moodString = map['mood'] as String?;
    return HealthLogModel(
      id: id,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      waterGlasses: map['waterGlasses'] as int? ?? 0,
      sleepHours: (map['sleepHours'] as num?)?.toDouble() ?? 0,
      mood: moodString == null
          ? null
          : Mood.values.firstWhere(
              (m) => m.name == moodString,
              orElse: () => Mood.okay,
            ),
      steps: map['steps'] as int? ?? 0,
      workoutDone: map['workoutDone'] as bool? ?? false,
      lastWaterLogAt: (map['lastWaterLogAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'waterGlasses': waterGlasses,
      'sleepHours': sleepHours,
      'mood': mood?.name,
      'steps': steps,
      'workoutDone': workoutDone,
      'lastWaterLogAt': lastWaterLogAt == null
          ? null
          : Timestamp.fromDate(lastWaterLogAt!),
    };
  }
}

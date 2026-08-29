import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/health_log_model.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';

final _dayFormat = DateFormat('yyyy-MM-dd');

/// Reads/writes a single signed-in user's tasks and health logs.
///
/// Everything here is scoped under `users/{uid}/...`, matching the
/// Firestore security rules, so one instance is only ever valid for the
/// user it was created with. A new instance is created (via Provider) each
/// time the signed-in user changes.
class FirestoreService {
  final String uid;
  final FirebaseFirestore _firestore;

  FirestoreService({required this.uid, FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasksRef =>
      _firestore.collection('users').doc(uid).collection('tasks');

  CollectionReference<Map<String, dynamic>> get _healthLogsRef =>
      _firestore.collection('users').doc(uid).collection('healthLogs');

  DocumentReference<Map<String, dynamic>> get _userDocRef =>
      _firestore.collection('users').doc(uid);

  // ---------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------

  /// Real-time stream of the user's own profile document.
  Stream<UserModel?> userProfileStream() {
    return _userDocRef.snapshots().map(
      (doc) => doc.exists ? UserModel.fromMap(doc.id, doc.data()!) : null,
    );
  }

  Future<void> setNotificationsEnabled(bool enabled) => _userDocRef.set({
    'notificationsEnabled': enabled,
  }, SetOptions(merge: true));

  /// One-off read used to gate scheduling a task reminder - if the user has
  /// turned notifications off in Profile, new reminders shouldn't be
  /// scheduled even when a task's own reminder toggle is on.
  Future<bool> getNotificationsEnabled() async {
    final doc = await _userDocRef.get();
    return (doc.data()?['notificationsEnabled'] as bool?) ?? true;
  }

  // ---------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------

  /// Real-time stream of all tasks, soonest first.
  Stream<List<TaskModel>> tasksStream() {
    return _tasksRef
        .orderBy('time')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TaskModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Adds [task] and returns it with the id Firestore assigned, so the
  /// caller can schedule its reminder notification.
  Future<TaskModel> addTask(TaskModel task) async {
    final docRef = await _tasksRef.add(task.toMap());
    return TaskModel.fromMap(docRef.id, task.toMap());
  }

  Future<void> updateTask(TaskModel task) =>
      _tasksRef.doc(task.id).update(task.toMap());

  Future<void> setTaskCompleted(String taskId, bool completed) =>
      _tasksRef.doc(taskId).update({'completed': completed});

  Future<void> deleteTask(String taskId) => _tasksRef.doc(taskId).delete();

  // ---------------------------------------------------------------------
  // Health logs (one document per calendar day)
  // ---------------------------------------------------------------------

  String _idFor(DateTime date) => _dayFormat.format(date);

  /// Real-time stream of today's health log. Emits null until anything has
  /// been logged today.
  Stream<HealthLogModel?> todayHealthLogStream() {
    final id = _idFor(DateTime.now());
    return _healthLogsRef
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? HealthLogModel.fromMap(doc.id, doc.data()!) : null,
        );
  }

  /// Real-time stream of the last [days] health logs, most recent first -
  /// used for the Insights weekly charts.
  Stream<List<HealthLogModel>> recentHealthLogsStream({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days - 1));
    final cutoffAtMidnight = DateTime(cutoff.year, cutoff.month, cutoff.day);

    return _healthLogsRef
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffAtMidnight),
        )
        .orderBy('date')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HealthLogModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Merges partial fields into today's log, creating it if needed.
  Future<void> _updateToday(Map<String, dynamic> fields) {
    final today = DateTime.now();
    final todayAtMidnight = DateTime(today.year, today.month, today.day);
    return _healthLogsRef.doc(_idFor(today)).set({
      'date': Timestamp.fromDate(todayAtMidnight),
      ...fields,
    }, SetOptions(merge: true));
  }

  Future<void> addWaterGlass() => _updateToday({
    'waterGlasses': FieldValue.increment(1),
    // Powers the SuggestionEngine's "no water in a while" rule.
    'lastWaterLogAt': Timestamp.fromDate(DateTime.now()),
  });

  Future<void> setSleepHours(double hours) =>
      _updateToday({'sleepHours': hours});

  Future<void> setMood(Mood mood) => _updateToday({'mood': mood.name});

  Future<void> setSteps(int steps) => _updateToday({'steps': steps});

  Future<void> setWorkoutDone(bool done) => _updateToday({'workoutDone': done});

  // ---------------------------------------------------------------------
  // Demo data (Profile screen "Demo Mode" section)
  // ---------------------------------------------------------------------

  /// Seeds a realistic-looking day of tasks plus a week of health logs, so
  /// the app has something to show without days of real logging. Safe to
  /// call more than once - tasks are added fresh each time, and each demo
  /// day's health log simply overwrites that day's document.
  Future<void> seedDemoData() async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const demoTasks = [
      (
        title: 'Morning workout',
        hour: 7,
        minute: 0,
        completed: true,
        reminder: true,
      ),
      (
        title: 'Team stand-up',
        hour: 9,
        minute: 30,
        completed: true,
        reminder: true,
      ),
      (
        title: 'Grocery shopping',
        hour: 13,
        minute: 0,
        completed: false,
        reminder: true,
      ),
      (
        title: 'Read for 30 minutes',
        hour: 20,
        minute: 0,
        completed: false,
        reminder: true,
      ),
      (
        title: 'Plan tomorrow',
        hour: 21,
        minute: 30,
        completed: false,
        reminder: false,
      ),
    ];
    for (final t in demoTasks) {
      final ref = _tasksRef.doc();
      batch.set(
        ref,
        TaskModel(
          id: ref.id,
          title: t.title,
          time: DateTime(today.year, today.month, today.day, t.hour, t.minute),
          reminderEnabled: t.reminder,
          completed: t.completed,
        ).toMap(),
      );
    }

    // A varied week so every Insights chart and several suggestion rules
    // (low sleep, low mood, low water) have something to show.
    const demoDays = [
      (
        daysAgo: 6,
        water: 5,
        sleep: 6.5,
        mood: Mood.okay,
        steps: 4200,
        workout: false,
      ),
      (
        daysAgo: 5,
        water: 7,
        sleep: 7.0,
        mood: Mood.good,
        steps: 6100,
        workout: true,
      ),
      (
        daysAgo: 4,
        water: 4,
        sleep: 5.5,
        mood: Mood.low,
        steps: 3000,
        workout: false,
      ),
      (
        daysAgo: 3,
        water: 8,
        sleep: 8.0,
        mood: Mood.great,
        steps: 8200,
        workout: true,
      ),
      (
        daysAgo: 2,
        water: 6,
        sleep: 7.5,
        mood: Mood.good,
        steps: 5400,
        workout: false,
      ),
      (
        daysAgo: 1,
        water: 3,
        sleep: 6.0,
        mood: Mood.okay,
        steps: 2100,
        workout: false,
      ),
      (
        daysAgo: 0,
        water: 2,
        sleep: 5.0,
        mood: Mood.low,
        steps: 1200,
        workout: false,
      ),
    ];
    for (final d in demoDays) {
      final date = today.subtract(Duration(days: d.daysAgo));
      final ref = _healthLogsRef.doc(_idFor(date));
      batch.set(
        ref,
        HealthLogModel(
          id: ref.id,
          date: date,
          waterGlasses: d.water,
          sleepHours: d.sleep,
          mood: d.mood,
          steps: d.steps,
          workoutDone: d.workout,
          lastWaterLogAt: date.add(const Duration(hours: 9)),
        ).toMap(),
      );
    }

    await batch.commit();
  }

  /// Deletes every task and health log for this user - used to turn demo
  /// mode back off (or just start fresh). Does not touch the profile doc.
  Future<void> clearAllData() async {
    final tasksSnapshot = await _tasksRef.get();
    final healthLogsSnapshot = await _healthLogsRef.get();

    final batch = _firestore.batch();
    for (final doc in tasksSnapshot.docs) {
      batch.delete(doc.reference);
    }
    for (final doc in healthLogsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

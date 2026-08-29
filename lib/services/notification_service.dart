import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_model.dart';

const _androidChannelId = 'task_reminders';

const _notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _androidChannelId,
    'Task Reminders',
    channelDescription: 'Reminders for your LifeSync AI planner tasks',
    importance: Importance.high,
    priority: Priority.high,
  ),
  iOS: DarwinNotificationDetails(),
  macOS: DarwinNotificationDetails(),
);

// Fixed ids for the two diagnostic notifications below, well outside the
// range `_notificationIdFor` produces from a task id's hash, so they can
// never collide with a real task's reminder.
const _testNowId = -1;
const _testScheduledId = -2;

/// Wraps `flutter_local_notifications` for both permission handling
/// (Phase 2) and scheduling task reminders (Phase 4).
///
/// Local notifications aren't supported on Windows or web, so every method
/// here is a safe no-op on those platforms instead of throwing.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  Future<void> initialize() async {
    if (!_isSupportedPlatform || _initialized) return;

    // Android's status bar can't render the full-color adaptive launcher
    // icon — it needs a flat, single-color silhouette, so `ic_launcher`
    // here silently falls back to a generic grey placeholder. The
    // monochrome layer already generated for Android 13+ themed icons is
    // exactly that shape, so reuse it here instead of adding a new asset.
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher_monochrome',
    );
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);

    const androidChannel = AndroidNotificationChannel(
      _androidChannelId,
      'Task Reminders',
      description: 'Reminders for your LifeSync AI planner tasks',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // The `timezone` package needs a local [tz.Location] to convert
    // wall-clock times correctly. This must be a real IANA identifier (e.g.
    // "Asia/Colombo") — flutter_local_notifications' native Android code
    // re-resolves this same name via Java's ZoneId.of() when scheduling an
    // alarm, so a made-up name (a fixed-offset Location without a real
    // identifier) schedules fine in Dart but throws
    // "Unknown time-zone ID" natively for every single scheduled
    // notification, silently, unless the caller happens to catch it.
    tzdata.initializeTimeZones();
    final deviceTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTimezone.identifier));

    _initialized = true;
  }

  /// Requests notification permission from the user. Returns true if
  /// granted (or if the platform doesn't require an explicit prompt).
  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) return false;
    await initialize();

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImpl?.requestNotificationsPermission() ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await iosImpl?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final macImpl = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      return await macImpl?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  /// Whether the app is currently exempt from Android's battery
  /// optimization — i.e. the OS won't defer/kill its scheduled reminders
  /// while backgrounded. Always true on platforms other than Android, since
  /// this concept doesn't apply there.
  ///
  /// Note this only reflects standard Android's battery manager. Samsung's
  /// separate "sleeping apps" list isn't covered by this API at all — a
  /// device can report true here and still silently kill reminders if the
  /// user hasn't also allowlisted the app in Samsung's Device Care.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    return await ph.Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Shows the OS's one-tap dialog asking the user to exempt this app from
  /// battery optimization. Returns the resulting state, same caveats as
  /// [isIgnoringBatteryOptimizations]. A no-op returning true on platforms
  /// other than Android.
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!_isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final status = await ph.Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// Whether the OS currently lets this app schedule *exact*-time alarms
  /// (Android 12+ treats this as a separate, revocable permission from
  /// "notifications are allowed at all"). [scheduleTaskReminder] uses exact
  /// scheduling, so if this is false, every scheduled reminder throws
  /// instead of firing — see [scheduleTaskReminder]'s try/catch.
  Future<bool> isExactAlarmPermissionGranted() async {
    if (!_isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    return await ph.Permission.scheduleExactAlarm.isGranted;
  }

  /// Shows the OS's "Alarms & reminders" settings screen so the user can
  /// grant exact-alarm scheduling — Android doesn't offer a one-tap system
  /// dialog for this permission the way it does for notifications/battery,
  /// so this opens Settings directly instead.
  Future<bool> requestExactAlarmPermission() async {
    if (!_isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final status = await ph.Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  /// A stable per-task notification id, so scheduling the same task twice
  /// replaces the old reminder instead of duplicating it.
  int _notificationIdFor(String taskId) => taskId.hashCode & 0x7fffffff;

  /// Whether the OS will actually show notifications from this app right
  /// now — distinct from [requestPermission], which *asks*. A user can
  /// grant it once during onboarding and later revoke it from system
  /// settings (or an OEM battery manager can silently do so); `zonedSchedule`
  /// itself never reports that, it just never fires, so callers should
  /// check this before relying on a reminder actually appearing.
  Future<bool> arePermissionsGranted() async {
    if (!_isSupportedPlatform) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await androidImpl?.areNotificationsEnabled() ?? false;
    }
    // iOS/macOS/Linux don't expose a no-prompt permission query here;
    // requestPermission()'s last result is the closest signal we have.
    return true;
  }

  /// Schedules a local notification for [task] at its reminder time.
  /// Returns false (and schedules nothing) if reminders are disabled for
  /// the task, the time has already passed, the platform doesn't support
  /// local notifications, the OS notification permission isn't currently
  /// granted, or scheduling throws for any other reason (e.g. exact-alarm
  /// permission revoked) — callers get a clean bool either way instead of
  /// an exception breaking the task-save flow. Use the diagnostics methods
  /// below to see the actual failure reason when this returns false.
  Future<bool> scheduleTaskReminder(TaskModel task) async {
    if (!_isSupportedPlatform || !task.reminderEnabled) return false;
    await initialize();

    if (!await arePermissionsGranted()) return false;

    final scheduledTime = tz.TZDateTime.from(task.time, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return false;

    try {
      await _plugin.zonedSchedule(
        _notificationIdFor(task.id),
        'Task reminder',
        task.title,
        scheduledTime,
        _notificationDetails,
        // Uses the exact-alarm permission (already requested in the
        // manifest) instead of inexact delivery — inexact alarms can be
        // deferred well past their target time under Android's Doze/App
        // Standby batching, which OEM power management (e.g. Samsung)
        // makes considerably more aggressive. Falls back to inexact below
        // if exact-alarm permission has since been revoked, rather than
        // failing the reminder outright.
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return true;
    } catch (_) {
      if (!await isExactAlarmPermissionGranted()) {
        await _plugin.zonedSchedule(
          _notificationIdFor(task.id),
          'Task reminder',
          task.title,
          scheduledTime,
          _notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return true;
      }
      return false;
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!_isSupportedPlatform) return;
    await _plugin.cancel(_notificationIdFor(taskId));
  }

  // ---------------------------------------------------------------------
  // Diagnostics — for narrowing down "I never got the reminder" reports.
  // Not linked from anywhere in the normal task flow; only used from the
  // debug section in Profile.
  // ---------------------------------------------------------------------

  /// Shows a notification immediately (no scheduling involved at all).
  /// If this doesn't appear, the problem is permission/display itself —
  /// not scheduling, not battery optimization, not timezone math.
  Future<bool> showTestNotificationNow() async {
    if (!_isSupportedPlatform) return false;
    await initialize();
    if (!await arePermissionsGranted()) return false;

    await _plugin.show(
      _testNowId,
      'Test notification',
      'If you see this, notifications display fine on this device.',
      _notificationDetails,
    );
    return true;
  }

  /// Schedules a notification a short delay from now, through the exact
  /// same `zonedSchedule` path a real task reminder uses. If the immediate
  /// test above works but this one never appears, that isolates the cause
  /// to Android's scheduling/battery-management layer (e.g. Samsung's
  /// "sleeping apps"), not the app's permission or notification setup.
  Future<bool> scheduleTestNotification({
    Duration delay = const Duration(seconds: 15),
  }) async {
    if (!_isSupportedPlatform) return false;
    await initialize();
    if (!await arePermissionsGranted()) return false;

    final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      _testScheduledId,
      'Scheduled test notification',
      'If you see this, scheduled reminders work on this device.',
      scheduledTime,
      _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return true;
  }
}

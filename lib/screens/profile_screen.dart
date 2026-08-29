import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/theme_mode_provider.dart';
import '../routes.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';

/// Account info, notification toggle, privacy note, demo mode, and logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isBusyWithDemoData = false;
  bool? _notificationsPermitted;
  bool? _batteryOptimizationIgnored;
  bool? _exactAlarmPermitted;
  bool _checkingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkNotificationPermission(context.read<NotificationService>());
      }
    });
  }

  Future<void> _checkNotificationPermission(
    NotificationService notificationService,
  ) async {
    setState(() => _checkingPermission = true);
    final granted = await notificationService.arePermissionsGranted();
    final batteryIgnored =
        await notificationService.isIgnoringBatteryOptimizations();
    final exactAlarmGranted =
        await notificationService.isExactAlarmPermissionGranted();
    if (mounted) {
      setState(() {
        _notificationsPermitted = granted;
        _batteryOptimizationIgnored = batteryIgnored;
        _exactAlarmPermitted = exactAlarmGranted;
        _checkingPermission = false;
      });
    }
  }

  Future<void> _requestBatteryExemption(
    NotificationService notificationService,
  ) async {
    final ignored = await notificationService.requestIgnoreBatteryOptimizations();
    if (mounted) setState(() => _batteryOptimizationIgnored = ignored);
  }

  Future<void> _requestExactAlarmPermission(
    NotificationService notificationService,
  ) async {
    final granted = await notificationService.requestExactAlarmPermission();
    if (mounted) setState(() => _exactAlarmPermitted = granted);
  }

  Future<void> _loadDemoData(
    FirestoreService firestoreService,
    ScaffoldMessengerState messenger,
  ) async {
    setState(() => _isBusyWithDemoData = true);
    try {
      await firestoreService.seedDemoData();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Demo data loaded - check the Dashboard, Planner, and Insights.',
            ),
          ),
        );
    } catch (_) {
      showErrorSnackBarVia(messenger, 'Could not load demo data.');
    } finally {
      if (mounted) setState(() => _isBusyWithDemoData = false);
    }
  }

  Future<void> _clearData(
    FirestoreService firestoreService,
    ScaffoldMessengerState messenger,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'This permanently deletes every task and health log on your '
          'account - including real entries, not just demo data. This '
          "can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusyWithDemoData = true);
    try {
      await firestoreService.clearAllData();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('All data cleared.')));
    } catch (_) {
      showErrorSnackBarVia(messenger, 'Could not clear data.');
    } finally {
      if (mounted) setState(() => _isBusyWithDemoData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<User?>();
    final firestoreService = context.watch<FirestoreService?>();
    final authService = context.read<AuthService>();
    final notificationService = context.read<NotificationService>();
    final messenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                (user?.displayName?.isNotEmpty ?? false)
                    ? user!.displayName!
                    : 'LifeSync AI user',
              ),
              subtitle: Text(user?.email ?? ''),
            ),
          ),
          if (user != null && !user.emailVerified) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              margin: EdgeInsets.zero,
              color: AppColors.warning.withValues(alpha: 0.15),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_unread_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    const Expanded(
                      child: Text('Your email address is not verified yet.'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await authService.resendEmailVerification();
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Verification email sent — it'll take "
                                'effect next time you log in.',
                              ),
                            ),
                          );
                      },
                      child: const Text('Resend'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (firestoreService != null)
            StreamBuilder<UserModel?>(
              stream: firestoreService.userProfileStream(),
              builder: (context, snapshot) {
                final notificationsEnabled =
                    snapshot.data?.notificationsEnabled ?? true;
                return Card(
                  margin: EdgeInsets.zero,
                  child: SwitchListTile(
                    secondary: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    subtitle: const Text('Task reminders and alerts'),
                    value: notificationsEnabled,
                    onChanged: (value) => firestoreService
                        .setNotificationsEnabled(value)
                        .catchError((_) => showErrorSnackBarVia(messenger)),
                  ),
                );
              },
            ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bug_report_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Notification diagnostics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (_checkingPermission)
                        const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          tooltip: 'Re-check permission status',
                          onPressed: () =>
                              _checkNotificationPermission(notificationService),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        _notificationsPermitted == true
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 18,
                        color: _notificationsPermitted == true
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _notificationsPermitted == null
                            ? 'Checking permission…'
                            : _notificationsPermitted == true
                            ? 'OS permission: granted'
                            : 'OS permission: NOT granted',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        _batteryOptimizationIgnored == true
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 18,
                        color: _batteryOptimizationIgnored == true
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _batteryOptimizationIgnored == null
                              ? 'Checking battery optimization…'
                              : _batteryOptimizationIgnored == true
                              ? 'Battery optimization: exempt'
                              : 'Battery optimization: NOT exempt',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (_batteryOptimizationIgnored == false) ...[
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton(
                      onPressed: () =>
                          _requestBatteryExemption(notificationService),
                      child: const Text('Allow background reminders'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        _exactAlarmPermitted == true
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        size: 18,
                        color: _exactAlarmPermitted == true
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          _exactAlarmPermitted == null
                              ? 'Checking exact-alarm permission…'
                              : _exactAlarmPermitted == true
                              ? 'Exact alarms: allowed'
                              : 'Exact alarms: NOT allowed',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (_exactAlarmPermitted == false) ...[
                    const SizedBox(height: AppSpacing.xs),
                    OutlinedButton(
                      onPressed: () =>
                          _requestExactAlarmPermission(notificationService),
                      child: const Text('Allow exact alarms'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.brightness_6_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Theme',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Consumer<ThemeModeProvider>(
                    builder: (context, themeModeProvider, _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {themeModeProvider.themeMode},
                        onSelectionChanged: (selection) =>
                            themeModeProvider.setThemeMode(selection.first),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: context.textSecondaryColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your tasks and health logs are private to your '
                      'account. They\'re stored securely in Firebase and are '
                      'never shared with other users.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (firestoreService != null) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Demo mode',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'For presentations: fill your account with a realistic '
                      "week of tasks and health logs, so there's something "
                      "to show without days of real logging. Clear it any "
                      'time.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isBusyWithDemoData
                                ? null
                                : () => _loadDemoData(
                                    firestoreService,
                                    messenger,
                                  ),
                            child: const Text(
                              'Load Demo Data',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isBusyWithDemoData
                                ? null
                                : () => _clearData(firestoreService, messenger),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                            child: const Text(
                              'Clear My Data',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isBusyWithDemoData) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () => _logOut(context, authService),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text(
              'Log out',
              style: TextStyle(color: AppColors.error),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logOut(BuildContext context, AuthService authService) async {
    await authService.signOut();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.authGate, (route) => false);
  }
}

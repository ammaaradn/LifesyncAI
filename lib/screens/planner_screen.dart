import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';

/// Formats a task's scheduled time - just the time for today's tasks, or
/// date + time for anything scheduled on another day.
String _taskTimeLabel(DateTime time) {
  final now = DateTime.now();
  final isToday =
      time.year == now.year && time.month == now.month && time.day == now.day;
  return isToday
      ? DateFormat('h:mm a').format(time)
      : DateFormat('MMM d, h:mm a').format(time);
}

/// Add/edit/delete tasks, each with an optional reminder.
class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService?>();

    return Scaffold(
      appBar: AppBar(title: const Text('Planner')),
      floatingActionButton: FloatingActionButton(
        onPressed: firestoreService == null
            ? null
            : () => _openTaskForm(context),
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
      body: firestoreService == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<TaskModel>>(
              stream: firestoreService.tasksStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _MessageState(
                    icon: Icons.error_outline,
                    message:
                        'Could not load tasks. Check your connection and try again.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data!;
                if (tasks.isEmpty) {
                  return const _MessageState(
                    icon: Icons.checklist_outlined,
                    message: 'No tasks yet - add your first one.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: tasks.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskTile(
                      task: task,
                      onTap: () => _openTaskForm(context, existing: task),
                    );
                  },
                );
              },
            ),
    );
  }

  void _openTaskForm(BuildContext context, {TaskModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _TaskFormSheet(existing: existing),
    );
  }
}

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

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.onTap});

  final TaskModel task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService?>();
    final notificationService = context.read<NotificationService>();
    final messenger = ScaffoldMessenger.of(context);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete task?'),
          content: Text('Delete "${task.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ).then((confirmed) => confirmed ?? false),
      onDismissed: (_) {
        firestoreService
            ?.deleteTask(task.id)
            .catchError((_) => showErrorSnackBarVia(messenger));
        notificationService.cancelTaskReminder(task.id);
      },
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Checkbox(
            value: task.completed,
            onChanged: (value) => firestoreService
                ?.setTaskCompleted(task.id, value ?? false)
                .catchError((_) => showErrorSnackBarVia(messenger)),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.completed ? TextDecoration.lineThrough : null,
              color: task.completed
                  ? context.textSecondaryColor
                  : context.textPrimaryColor,
            ),
          ),
          subtitle: Row(
            children: [
              Text(_taskTimeLabel(task.time)),
              if (task.reminderEnabled) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.notifications_active_outlined,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet({this.existing});

  final TaskModel? existing;

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late DateTime _date = _dateOnly(widget.existing?.time ?? DateTime.now());
  late TimeOfDay _time = widget.existing != null
      ? TimeOfDay.fromDateTime(widget.existing!.time)
      : TimeOfDay.now();
  late bool _reminderEnabled = widget.existing?.reminderEnabled ?? true;

  bool _isSaving = false;
  String? _titleError;

  bool get _isEditing => widget.existing != null;

  static DateTime _dateOnly(DateTime dateTime) =>
      DateTime(dateTime.year, dateTime.month, dateTime.day);

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _date = _dateOnly(picked));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  /// Turning the reminder switch on is the natural moment to actually ask
  /// for notification permission — rather than silently scheduling
  /// something that may never show, prompt right here if it isn't granted
  /// yet, and let the user know immediately if they decline.
  Future<void> _onReminderToggled(bool value) async {
    setState(() => _reminderEnabled = value);
    if (!value) return;

    final notificationService = context.read<NotificationService>();
    if (await notificationService.arePermissionsGranted()) return;

    final granted = await notificationService.requestPermission();
    if (!mounted || granted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            "Notifications are off for this app, so this reminder won't "
            'show. Enable them in system settings to fix that.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
  }

  DateTime _combinedDateTime() {
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter a task title');
      return;
    }

    final firestoreService = context.read<FirestoreService?>();
    if (firestoreService == null) return;
    final notificationService = context.read<NotificationService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    final time = _combinedDateTime();

    try {
      // Respect the user's global notification toggle in Profile - even if
      // this task's own reminder switch is on, don't schedule anything if
      // they've turned notifications off for the whole app.
      final notificationsAllowed =
          _reminderEnabled && await firestoreService.getNotificationsEnabled();

      var reminderScheduled = false;
      if (_isEditing) {
        final updated = widget.existing!.copyWith(
          title: title,
          time: time,
          reminderEnabled: _reminderEnabled,
        );
        await firestoreService.updateTask(updated);
        await notificationService.cancelTaskReminder(updated.id);
        if (notificationsAllowed) {
          reminderScheduled = await notificationService.scheduleTaskReminder(
            updated,
          );
        }
      } else {
        final saved = await firestoreService.addTask(
          TaskModel(
            id: '',
            title: title,
            time: time,
            reminderEnabled: _reminderEnabled,
          ),
        );
        if (notificationsAllowed) {
          reminderScheduled = await notificationService.scheduleTaskReminder(
            saved,
          );
        }
      }

      // The task saved fine either way — only warn about the reminder
      // itself, and only when one was actually requested for a future time.
      if (notificationsAllowed &&
          !reminderScheduled &&
          !time.isBefore(DateTime.now()) &&
          !await notificationService.arePermissionsGranted()) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Task saved, but notifications are turned off for this app '
                "in system settings — enable them to get this reminder.",
              ),
              duration: Duration(seconds: 5),
            ),
          );
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final firestoreService = context.read<FirestoreService?>();
    final notificationService = context.read<NotificationService>();

    await firestoreService?.deleteTask(existing.id);
    await notificationService.cancelTaskReminder(existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? 'Edit Task' : 'New Task',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _titleController,
            autofocus: !_isEditing,
            decoration: InputDecoration(
              labelText: 'Title',
              prefixIcon: const Icon(Icons.task_alt_outlined),
              errorText: _titleError,
            ),
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Date'),
            trailing: Text(
              DateFormat('EEE, MMM d, yyyy').format(_date),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time_outlined),
            title: const Text('Time'),
            trailing: Text(
              _time.format(context),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            onTap: _pickTime,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Reminder'),
            value: _reminderEnabled,
            onChanged: _onReminderToggled,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isEditing ? 'Save Changes' : 'Add Task'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _delete,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete Task'),
            ),
          ],
        ],
      ),
    );
  }
}

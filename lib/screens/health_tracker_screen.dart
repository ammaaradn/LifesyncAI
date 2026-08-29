import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/health_log_model.dart';
import '../services/firestore_service.dart';
import '../theme.dart';
import '../widgets/error_snackbar.dart';

/// Log water, sleep, mood, steps, and workout status for today.
///
/// Health logs are one document per day, so every widget here reads and
/// writes the same "today" log via [FirestoreService.todayHealthLogStream].
class HealthTrackerScreen extends StatelessWidget {
  const HealthTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<FirestoreService?>();

    return Scaffold(
      appBar: AppBar(title: const Text('Health Tracker')),
      body: firestoreService == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<HealthLogModel?>(
              stream: firestoreService.todayHealthLogStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Could not load today\'s log. Check your connection and try again.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // No document yet today == everything at its default value.
                final log = snapshot.data;

                final messenger = ScaffoldMessenger.of(context);

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    _WaterCard(
                      glasses: log?.waterGlasses ?? 0,
                      onAddGlass: () => firestoreService
                          .addWaterGlass()
                          .catchError((_) => showErrorSnackBarVia(messenger)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SleepCard(
                      hours: log?.sleepHours ?? 0,
                      onChanged: (hours) => firestoreService
                          .setSleepHours(hours)
                          .catchError((_) => showErrorSnackBarVia(messenger)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _MoodCard(
                      selected: log?.mood,
                      onSelected: (mood) => firestoreService
                          .setMood(mood)
                          .catchError((_) => showErrorSnackBarVia(messenger)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StepsCard(
                      steps: log?.steps ?? 0,
                      onSaved: (steps) => firestoreService
                          .setSteps(steps)
                          .catchError((_) => showErrorSnackBarVia(messenger)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _WorkoutCard(
                      done: log?.workoutDone ?? false,
                      onChanged: (done) => firestoreService
                          .setWorkoutDone(done)
                          .catchError((_) => showErrorSnackBarVia(messenger)),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.glasses, required this.onAddGlass});

  final int glasses;
  final VoidCallback onAddGlass;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const Icon(Icons.water_drop_outlined, color: AppColors.primary, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '$glasses glass${glasses == 1 ? '' : 'es'} today',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAddGlass,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Glass'),
          ),
        ],
      ),
    );
  }
}

class _SleepCard extends StatefulWidget {
  const _SleepCard({required this.hours, required this.onChanged});

  final double hours;
  final ValueChanged<double> onChanged;

  @override
  State<_SleepCard> createState() => _SleepCardState();
}

class _SleepCardState extends State<_SleepCard> {
  late double _value = widget.hours;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant _SleepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.hours != widget.hours) {
      _value = widget.hours;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bedtime_outlined, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('Sleep', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text(
                '${_value.toStringAsFixed(1)} hrs',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          Slider(
            value: _value.clamp(0, 12),
            min: 0,
            max: 12,
            divisions: 24,
            label: '${_value.toStringAsFixed(1)} hrs',
            onChangeStart: (_) => setState(() => _dragging = true),
            onChanged: (value) => setState(() => _value = value),
            onChangeEnd: (value) {
              setState(() => _dragging = false);
              widget.onChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.selected, required this.onSelected});

  final Mood? selected;
  final ValueChanged<Mood> onSelected;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mood', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: Mood.values.map((mood) {
              final isSelected = mood == selected;
              return Semantics(
                label: 'Mood: ${mood.label}',
                selected: isSelected,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => onSelected(mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      mood.emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatefulWidget {
  const _StepsCard({required this.steps, required this.onSaved});

  final int steps;
  final ValueChanged<int> onSaved;

  @override
  State<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends State<_StepsCard> {
  late final _controller = TextEditingController(
    text: widget.steps == 0 ? '' : '${widget.steps}',
  );
  final _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant _StepsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.steps != widget.steps) {
      _controller.text = widget.steps == 0 ? '' : '${widget.steps}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final parsed = int.tryParse(_controller.text) ?? 0;
    widget.onSaved(parsed);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Row(
        children: [
          const Icon(Icons.directions_walk_outlined, color: AppColors.primary, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Steps today'),
              onSubmitted: (_) => _save(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Save steps',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.done, required this.onChanged});

  final bool done;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.fitness_center_outlined, color: AppColors.primary),
        title: const Text('Workout done today'),
        value: done,
        onChanged: onChanged,
      ),
    );
  }
}

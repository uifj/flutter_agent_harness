// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Tasks — see the enum `_Section` for what points at it.
extension _TaskSections on _SettingsPanelState {
  /// Scheduled tasks (ADR-0069): the list plus a create dialog. Enable
  /// writes straight to the store — the scheduler reads it live; a disabled
  /// task keeps its definition for later.
  List<Widget> _tasksSection(BuildContext context, DswAlias color) {
    final store = widget.scheduledTasks;
    return [
      _heading(
        color,
        AppLocalizations.of(context).settingsTasks,
        AppLocalizations.of(context).settingsTasksIntro,
      ),
      const SizedBox(height: 12),
      SettingsCard(
        dividers: true,
        children: [
          FutureBuilder<List<ScheduledTask>>(
            future: store.tasks(),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? const <ScheduledTask>[];
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context).tasksEmpty,
                          style: DswType.xxs12.copyWith(
                            color: color.labelTertiary,
                          ),
                        ),
                      ),
                    ),
                  for (final task in tasks)
                    _TaskRow(
                      task: task,
                      onToggle: (value) =>
                          store.setEnabled(task.id, enabled: value),
                      onDelete: () => store.remove(task.id),
                    ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: CapsuleButton(
              label: AppLocalizations.of(context).taskAdd,
              onTap: () => _addTask(context, store),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _addTask(BuildContext context, ScheduledTaskStore store) async {
    final color = context.dsw;
    final name = TextEditingController();
    final prompt = TextEditingController();
    final hour = TextEditingController(text: '9');
    final minute = TextEditingController(text: '0');
    final weekdays = <int>{};
    final step = MediaQuery.textScalerOf(context).scale(1);
    final saved = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => ShadDialog(
          radius: BorderRadius.circular(DswShape.float),
          title: Text(
            AppLocalizations.of(context).taskAdd,
            style: DswType.sStrong14,
          ),
          actions: [
            ShadButton.outline(
              height: 24 * step,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(AppLocalizations.of(context).cancel),
            ),
            ShadButton(
              height: 24 * step,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(AppLocalizations.of(context).save),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShadInput(
                controller: name,
                placeholder: Text(AppLocalizations.of(context).taskNameHint),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              ShadInput(
                controller: prompt,
                placeholder: Text(AppLocalizations.of(context).taskPromptHint),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: ShadInput(
                      controller: hour,
                      placeholder: Text(
                        AppLocalizations.of(context).taskHourHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: ShadInput(
                      controller: minute,
                      placeholder: Text(
                        AppLocalizations.of(context).taskMinuteHint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  for (final weekday in const [1, 2, 3, 4, 5, 6, 7])
                    DswHoverTap(
                      onTap: () => setDialogState(() {
                        weekdays.contains(weekday)
                            ? weekdays.remove(weekday)
                            : weekdays.add(weekday);
                      }),
                      toggled: weekdays.contains(weekday),
                      semanticLabel: AppLocalizations.of(
                        context,
                      ).taskWeekday('$weekday'),
                      builder: (context, hovered, focused) => ShadBadge(
                        backgroundColor: weekdays.contains(weekday)
                            ? color.interactiveSelected
                            : hovered
                            ? color.interactiveBgHover
                            : Colors.transparent,
                        child: Text(
                          AppLocalizations.of(context).taskWeekday('$weekday'),
                          style: DswType.xxs12.copyWith(
                            color: weekdays.contains(weekday)
                                ? color.labelPrimary
                                : color.labelSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    for (final controller in [name, prompt, hour, minute]) {
      controller.dispose();
    }
    if (saved != true) return;
    final hourValue = int.tryParse(hour.text.trim());
    final minuteValue = int.tryParse(minute.text.trim());
    if (hourValue == null || minuteValue == null) return;
    await store.add(
      name: name.text,
      prompt: prompt.text,
      hour: hourValue,
      minute: minuteValue,
      weekdaysMask: weekdays.isEmpty
          ? 0
          : weekdays.fold(0, (mask, day) => mask | (1 << (day - 1))),
    );
  }
}

/// One scheduled task of the list: name over the schedule summary, with the
/// enable switch and delete.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  final ScheduledTask task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final time =
        '${task.hour.toString().padLeft(2, '0')}:'
        '${task.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: DswType.s14.copyWith(color: color.labelPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: DswType.xxs12.copyWith(color: color.labelTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DswIconButton(
            icon: LucideIcons.trash,
            tooltip: AppLocalizations.of(context).taskDelete,
            onTap: onDelete,
          ),
          const SizedBox(width: 4),
          ShadSwitch(value: task.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

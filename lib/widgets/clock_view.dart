import 'package:flutter/material.dart';
import 'package:omoji/main.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/models/todo_item.dart';
import 'package:omoji/services/alarm_service.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/services/stopwatch_service.dart';
import 'package:omoji/services/timer_service.dart';

class ClockView extends StatefulWidget {
  final List<AlarmItem> alarms;
  final ValueChanged<List<AlarmItem>> onAlarmsChanged;
  final List<TodoItem> todos;
  final ValueChanged<List<TodoItem>> onTodosChanged;

  const ClockView({
    super.key,
    required this.alarms,
    required this.onAlarmsChanged,
    this.todos = const [],
    required this.onTodosChanged,
  });

  @override
  State<ClockView> createState() => _ClockViewState();
}

class _ClockViewState extends State<ClockView> {
  String _subTab = 'alarms'; // 'alarms', 'stopwatch', 'timer', 'todo'
  late String _todoFilter; // initialized from todoDefaultViewNotifier
  final Set<String> _expandedTodoIds = {};

  @override
  void initState() {
    super.initState();
    _todoFilter = todoDefaultViewNotifier.value;
  }

  String _formatTimerDisplay(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // --- Alarm Add/Edit Dialog ---
  void _showAddAlarmDialog() async {
    TimeOfDay selectedTime = TimeOfDay.now();
    String label = 'Alarm';
    List<int> selectedDays = [];
    int autoSilenceMins = 5;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).colorScheme.primary;
            final timeStr =
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
            const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2E2E2E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Alarm', style: TextStyle(fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        border: Border.all(color: primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => label = val,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Auto-silence after:',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      DropdownButton<int>(
                        value: autoSilenceMins,
                        isDense: true,
                        dropdownColor:
                            isDark ? const Color(0xFF3A3A3A) : Colors.white,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1 min')),
                          DropdownMenuItem(value: 2, child: Text('2 mins')),
                          DropdownMenuItem(value: 3, child: Text('3 mins')),
                          DropdownMenuItem(value: 5, child: Text('5 mins (Default)')),
                          DropdownMenuItem(value: 10, child: Text('10 mins')),
                          DropdownMenuItem(value: 15, child: Text('15 mins')),
                          DropdownMenuItem(value: 30, child: Text('30 mins')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              autoSilenceMins = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (idx) {
                          final dayNum = idx + 1;
                          final isSelected = selectedDays.contains(dayNum);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Text(dayNames[idx], style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              labelPadding: EdgeInsets.zero,
                              onSelected: (val) {
                                setDialogState(() {
                                  if (val) {
                                    selectedDays.add(dayNum);
                                  } else {
                                    selectedDays.remove(dayNum);
                                  }
                                  selectedDays.sort();
                                });
                              },
                              selectedColor: primaryColor,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (idx) {
                          final dayIdx = idx + 4;
                          final dayNum = dayIdx + 1;
                          final isSelected = selectedDays.contains(dayNum);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Text(dayNames[dayIdx], style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              labelPadding: EdgeInsets.zero,
                              onSelected: (val) {
                                setDialogState(() {
                                  if (val) {
                                    selectedDays.add(dayNum);
                                  } else {
                                    selectedDays.remove(dayNum);
                                  }
                                  selectedDays.sort();
                                });
                              },
                              selectedColor: primaryColor,
                              visualDensity: VisualDensity.compact,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    final timeHHmm =
                        '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                    final newAlarm = AlarmItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      time: timeHHmm,
                      label: label.trim().isEmpty ? 'Alarm' : label.trim(),
                      isEnabled: true,
                      repeatDays: selectedDays,
                      autoSilenceMinutes: autoSilenceMins,
                    );
                    final updated = List<AlarmItem>.from(widget.alarms)..add(newAlarm);
                    widget.onAlarmsChanged(updated);
                    AppSettings.saveSettings(alarms: updated);
                    AlarmService.updateAlarms(updated);
                    Navigator.pop(context);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- To-Do / Event Reminder Add/Edit Dialog ---
  void _showAddEditTodoDialog([TodoItem? existing]) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descController = TextEditingController(text: existing?.description ?? '');
    DateTime selectedDateTime = existing?.targetDateTime ?? DateTime.now().add(const Duration(days: 7));
    String selectedRecurrence = existing?.recurrence ?? 'none';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).colorScheme.primary;
            final textColor = isDark ? Colors.white : Colors.black87;

            final dateFormatted =
                '${selectedDateTime.year}-${selectedDateTime.month.toString().padLeft(2, '0')}-${selectedDateTime.day.toString().padLeft(2, '0')}';
            final timeFormatted =
                '${selectedDateTime.hour.toString().padLeft(2, '0')}:${selectedDateTime.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2E2E2E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.event_note_rounded, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    existing == null ? 'Add Event Reminder' : 'Edit Event Reminder',
                    style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Event Title / Task',
                        hintText: 'e.g. Meeting next week, Doctor appointment',
                        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      style: TextStyle(color: textColor, fontSize: 13),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Add notes or location info',
                        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Quick Presets:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildPresetChip('+1 Day', const Duration(days: 1), selectedDateTime, (newDate) {
                          setDialogState(() => selectedDateTime = newDate);
                        }),
                        _buildPresetChip('+1 Week', const Duration(days: 7), selectedDateTime, (newDate) {
                          setDialogState(() => selectedDateTime = newDate);
                        }),
                        _buildPresetChip('+2 Weeks', const Duration(days: 14), selectedDateTime, (newDate) {
                          setDialogState(() => selectedDateTime = newDate);
                        }),
                        _buildPresetChip('+1 Month', const Duration(days: 30), selectedDateTime, (newDate) {
                          setDialogState(() => selectedDateTime = newDate);
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Event Date & Time:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: Text(dateFormatted, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDateTime,
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                              );
                              if (pickedDate != null) {
                                setDialogState(() {
                                  selectedDateTime = DateTime(
                                    pickedDate.year,
                                    pickedDate.month,
                                    pickedDate.day,
                                    selectedDateTime.hour,
                                    selectedDateTime.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            icon: const Icon(Icons.access_time_rounded, size: 16),
                            label: Text(timeFormatted, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: selectedDateTime.hour,
                                  minute: selectedDateTime.minute,
                                ),
                              );
                              if (pickedTime != null) {
                                setDialogState(() {
                                  selectedDateTime = DateTime(
                                    selectedDateTime.year,
                                    selectedDateTime.month,
                                    selectedDateTime.day,
                                    pickedTime.hour,
                                    pickedTime.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Recurrence / Repeat:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedRecurrence,
                      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('Does not repeat')),
                        DropdownMenuItem(value: 'daily', child: Text('Every day (Daily)')),
                        DropdownMenuItem(value: 'weekly', child: Text('Every week (Weekly)')),
                        DropdownMenuItem(value: 'monthly', child: Text('Every month (Monthly)')),
                        DropdownMenuItem(value: 'yearly', child: Text('Every year (Yearly)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRecurrence = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    List<TodoItem> updated = List<TodoItem>.from(widget.todos);
                    if (existing != null) {
                      existing.title = title;
                      existing.description = descController.text.trim();
                      existing.targetDateTime = selectedDateTime;
                      existing.recurrence = selectedRecurrence;
                      existing.hasNotified = false;
                    } else {
                      final newTodo = TodoItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        description: descController.text.trim(),
                        targetDateTime: selectedDateTime,
                        recurrence: selectedRecurrence,
                      );
                      updated.add(newTodo);
                    }

                    widget.onTodosChanged(updated);
                    AppSettings.saveSettings(todos: updated);
                    AlarmService.updateTodos(updated);
                    Navigator.pop(context);
                  },
                  child: const Text('Save Event', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, Duration duration, DateTime currentSelection, Function(DateTime) onSelect) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () {
        onSelect(DateTime.now().add(duration));
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
        ),
      ),
    );
  }

  Widget _buildSubTabButton(String id, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _subTab == id;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Focus(
      canRequestFocus: false,
      child: InkWell(
        onTap: () => setState(() {
            _subTab = id;
            // Reset to the user's preferred default view each time they open To-Do
            if (id == 'todo') _todoFilter = todoDefaultViewNotifier.value;
          }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            border: Border.all(
              color: isActive ? Theme.of(context).colorScheme.primary : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isActive ? Theme.of(context).colorScheme.primary : textColor.withValues(alpha: 0.6)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? Theme.of(context).colorScheme.primary : textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final cardBorder = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Column(
      children: [
        // Sub-tabs header: Alarms | Stopwatch | Timer | To-Do
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSubTabButton('alarms', 'Alarms', Icons.alarm),
            const SizedBox(width: 6),
            _buildSubTabButton('stopwatch', 'Stopwatch', Icons.timer_outlined),
            const SizedBox(width: 6),
            _buildSubTabButton('timer', 'Timer', Icons.hourglass_bottom_rounded),
            const SizedBox(width: 6),
            _buildSubTabButton('todo', 'To-Do', Icons.event_note_rounded),
          ],
        ),
        const SizedBox(height: 12),

        // --- SUB TAB CONTENTS ---
        Expanded(
          child: _subTab == 'alarms'
              ? _buildAlarmsView(cardBg, cardBorder, textColor)
              : _subTab == 'stopwatch'
                  ? _buildStopwatchView(cardBg, cardBorder, textColor)
                  : _subTab == 'timer'
                      ? _buildTimerView(cardBg, cardBorder, textColor)
                      : _buildTodoView(cardBg, cardBorder, textColor),
        ),
      ],
    );
  }

  // --- ALARMS VIEW ---
  Widget _buildAlarmsView(Color cardBg, Color cardBorder, Color textColor) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Alarms',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary, size: 20),
              onPressed: _showAddAlarmDialog,
              tooltip: 'Add Alarm',
            ),
          ],
        ),
        Expanded(
          child: widget.alarms.isEmpty
              ? Center(
                  child: Text(
                    'No alarms set.\nClick + to create an alarm.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: widget.alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = widget.alarms[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: cardBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alarm.time,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: alarm.isEnabled
                                        ? textColor
                                        : textColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      alarm.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textColor.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '• ${alarm.repeatSummary} (${alarm.autoSilenceMinutes}m auto-silence)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: alarm.isEnabled,
                            activeThumbColor: Theme.of(context).colorScheme.primary,
                            onChanged: (val) {
                              setState(() {
                                alarm.isEnabled = val;
                              });
                              widget.onAlarmsChanged(widget.alarms);
                              AppSettings.saveSettings(alarms: widget.alarms);
                              AlarmService.updateAlarms(widget.alarms);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.redAccent.withValues(alpha: 0.7),
                            onPressed: () {
                              final updated = List<AlarmItem>.from(widget.alarms)
                                ..removeAt(index);
                              widget.onAlarmsChanged(updated);
                              AppSettings.saveSettings(alarms: updated);
                              AlarmService.updateAlarms(updated);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- STOPWATCH VIEW ---
  Widget _buildStopwatchView(Color cardBg, Color cardBorder, Color textColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: StopwatchService.runningNotifier,
      builder: (context, isRunning, _) {
        return ValueListenableBuilder<int>(
          valueListenable: StopwatchService.elapsedNotifier,
          builder: (context, elapsedMs, _) {
            final displayStr = StopwatchService.formatStopwatchTime(elapsedMs);

            return ValueListenableBuilder<List<String>>(
              valueListenable: StopwatchService.lapsNotifier,
              builder: (context, lapsList, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: cardBorder),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        displayStr,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRunning
                                ? Colors.orangeAccent
                                : Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: StopwatchService.toggle,
                          icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                          label: Text(isRunning ? 'Pause' : 'Start'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.1),
                            foregroundColor: textColor,
                          ),
                          onPressed: isRunning ? StopwatchService.recordLap : null,
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('Lap'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                            foregroundColor: Colors.redAccent,
                          ),
                          onPressed: StopwatchService.reset,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: lapsList.isEmpty
                          ? Center(
                              child: Text(
                                'No laps recorded',
                                style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              itemCount: lapsList.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    lapsList[index],
                                    style: TextStyle(color: textColor, fontSize: 13, fontFamily: 'monospace'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // --- TIMER VIEW ---
  String _formatOvertimeDisplay(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '+${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '+${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _showCustomTimeDialog() async {
    if (TimerService.isRunning) return;

    final initialDuration = TimerService.durationSeconds;
    final initialHours = initialDuration ~/ 3600;
    final initialMinutes = (initialDuration % 3600) ~/ 60;
    final initialSeconds = initialDuration % 60;

    final hoursController = TextEditingController(text: initialHours.toString());
    final minutesController = TextEditingController(text: initialMinutes.toString());
    final secondsController = TextEditingController(text: initialSeconds.toString());

    await showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF2E2E2E) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.timer_outlined, color: primaryColor),
              const SizedBox(width: 8),
              Text('Set Custom Timer', style: TextStyle(color: textColor, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter duration (Hours, Minutes, Seconds):',
                style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeUnitInput(hoursController, 'Hours', textColor, primaryColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  ),
                  _buildTimeUnitInput(minutesController, 'Mins', textColor, primaryColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  ),
                  _buildTimeUnitInput(secondsController, 'Secs', textColor, primaryColor),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final h = int.tryParse(hoursController.text.trim()) ?? 0;
                final m = int.tryParse(minutesController.text.trim()) ?? 0;
                final s = int.tryParse(secondsController.text.trim()) ?? 0;
                final total = (h * 3600) + (m * 60) + s;
                if (total > 0) {
                  TimerService.setDuration(total);
                  Navigator.pop(context);
                }
              },
              child: const Text('Set Timer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeUnitInput(TextEditingController controller, String label, Color textColor, Color primaryColor) {
    return SizedBox(
      width: 65,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: textColor.withValues(alpha: 0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerView(Color cardBg, Color cardBorder, Color textColor) {
    return ValueListenableBuilder<bool>(
      valueListenable: TimerService.runningNotifier,
      builder: (context, isRunning, _) {
        return ValueListenableBuilder<int>(
          valueListenable: TimerService.remainingNotifier,
          builder: (context, remainingSeconds, _) {
            final canEdit = !isRunning;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Tooltip(
                  message: canEdit ? 'Click to set custom time' : 'Timer is active',
                  child: InkWell(
                    onTap: canEdit ? _showCustomTimeDialog : null,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(
                            color: canEdit
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
                                : cardBorder),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTimerDisplay(remainingSeconds),
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: remainingSeconds == 0
                                  ? Colors.redAccent
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if (canEdit) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: TimerService.overtimeNotifier,
                  builder: (context, overtimeSecs, _) {
                    if (overtimeSecs <= 0) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alarm_on_rounded, size: 14, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Ringing: ${_formatOvertimeDisplay(overtimeSecs)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (!isRunning) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPresetTimerChip(60, '1m'),
                      const SizedBox(width: 6),
                      _buildPresetTimerChip(300, '5m'),
                      const SizedBox(width: 6),
                      _buildPresetTimerChip(600, '10m'),
                      const SizedBox(width: 6),
                      _buildPresetTimerChip(900, '15m'),
                      const SizedBox(width: 6),
                      _buildPresetTimerChip(1800, '30m'),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isRunning ? Colors.orangeAccent : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isRunning
                          ? TimerService.pause
                          : TimerService.start,
                      icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(isRunning ? 'Pause' : 'Start'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.redAccent.withValues(alpha: 0.2),
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: TimerService.reset,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPresetTimerChip(int seconds, String label) {
    final isSelected = TimerService.durationSeconds == seconds;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (val) {
        if (val) {
          TimerService.setDuration(seconds);
        }
      },
    );
  }

  // --- TO-DO / EVENT REMINDERS VIEW ---
  Widget _buildTodoView(Color cardBg, Color cardBorder, Color textColor) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final now = DateTime.now();
    final upcomingCount = widget.todos.where((t) => !t.isCompleted && (t.targetDateTime.isAfter(now) || t.targetDateTime.isAtSameMomentAs(now))).length;
    final missedCount = widget.todos.where((t) => !t.isCompleted && t.targetDateTime.isBefore(now)).length;
    final completedCount = widget.todos.where((t) => t.isCompleted).length;

    List<TodoItem> filteredTodos = widget.todos.where((item) {
      if (_todoFilter == 'upcoming') {
        return !item.isCompleted && (item.targetDateTime.isAfter(now) || item.targetDateTime.isAtSameMomentAs(now));
      }
      if (_todoFilter == 'missed') {
        return !item.isCompleted && item.targetDateTime.isBefore(now);
      }
      if (_todoFilter == 'completed') return item.isCompleted;
      return true;
    }).toList();

    // Sort chronologically by targetDateTime
    filteredTodos.sort((a, b) => a.targetDateTime.compareTo(b.targetDateTime));

    return Column(
      children: [
        // Header Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTodoFilterChip('all', 'All (${widget.todos.length})'),
                    const SizedBox(width: 4),
                    _buildTodoFilterChip('upcoming', 'Upcoming ($upcomingCount)'),
                    const SizedBox(width: 4),
                    _buildTodoFilterChip('missed', 'Missed ($missedCount)'),
                    const SizedBox(width: 4),
                    _buildTodoFilterChip('completed', 'Done ($completedCount)'),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: primaryColor, size: 20),
              onPressed: () => _showAddEditTodoDialog(),
              tooltip: 'Add Event Reminder',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filteredTodos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available_rounded, size: 36, color: textColor.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text(
                        _todoFilter == 'completed'
                            ? 'No completed tasks yet.'
                            : 'No upcoming event reminders.\nClick + to set a reminder for a week later or custom date.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : ValueListenableBuilder<String>(
                  valueListenable: dateFormatNotifier,
                  builder: (context, dateFormat, _) {
                    return ListView.builder(
                      itemCount: filteredTodos.length,
                      itemBuilder: (context, index) {
                    final todo = filteredTodos[index];
                    final isOverdue = !todo.isCompleted && DateTime.now().isAfter(todo.targetDateTime);
                    final isExpanded = _expandedTodoIds.contains(todo.id);
                    final isDark = Theme.of(context).brightness == Brightness.dark;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? (isDark
                                ? primaryColor.withValues(alpha: 0.1)
                                : primaryColor.withValues(alpha: 0.06))
                            : cardBg,
                        border: Border.all(
                          color: isOverdue
                              ? Colors.redAccent.withValues(alpha: 0.5)
                              : isExpanded
                                  ? primaryColor.withValues(alpha: 0.6)
                                  : todo.isCompleted
                                      ? cardBorder
                                      : primaryColor.withValues(alpha: 0.3),
                          width: isExpanded ? 1.5 : 1.0,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isExpanded
                            ? [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            if (_expandedTodoIds.contains(todo.id)) {
                              _expandedTodoIds.remove(todo.id);
                            } else {
                              _expandedTodoIds.add(todo.id);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Main Header Row
                              Row(
                                children: [
                                  Checkbox(
                                    value: todo.isCompleted,
                                    activeColor: primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        todo.isCompleted = val ?? false;
                                      });
                                      widget.onTodosChanged(widget.todos);
                                      AppSettings.saveSettings(todos: widget.todos);
                                      AlarmService.updateTodos(widget.todos);
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          todo.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                                            color: todo.isCompleted
                                                ? textColor.withValues(alpha: 0.4)
                                                : textColor,
                                          ),
                                        ),
                                        if (!isExpanded && todo.description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            todo.description,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textColor.withValues(alpha: 0.6),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        if (!isExpanded) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.schedule_rounded,
                                                size: 12,
                                                color: isOverdue
                                                    ? Colors.redAccent
                                                    : todo.isCompleted
                                                        ? textColor.withValues(alpha: 0.3)
                                                        : primaryColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                todo.formattedTargetDate,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isOverdue
                                                      ? Colors.redAccent
                                                      : textColor.withValues(alpha: 0.6),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: isOverdue
                                                      ? Colors.redAccent.withValues(alpha: 0.15)
                                                      : todo.isCompleted
                                                          ? textColor.withValues(alpha: 0.1)
                                                          : primaryColor.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  todo.timeRemainingSummary,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isOverdue
                                                        ? Colors.redAccent
                                                        : todo.isCompleted
                                                            ? textColor.withValues(alpha: 0.4)
                                                            : primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                    ),
                                    color: primaryColor,
                                    onPressed: () {
                                      setState(() {
                                        if (_expandedTodoIds.contains(todo.id)) {
                                          _expandedTodoIds.remove(todo.id);
                                        } else {
                                          _expandedTodoIds.add(todo.id);
                                        }
                                      });
                                    },
                                    tooltip: isExpanded ? 'Collapse Details' : 'Expand Details',
                                  ),
                                ],
                              ),

                              // Expanded Details View
                              if (isExpanded) ...[
                                const SizedBox(height: 8),
                                Divider(color: cardBorder, height: 1),
                                const SizedBox(height: 10),

                                // Full Description Box
                                Text(
                                  'DETAILS & NOTES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: textColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.25)
                                        : Colors.white.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: SelectableText(
                                    todo.description.isNotEmpty
                                        ? todo.description
                                        : 'No additional details provided.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: todo.description.isNotEmpty
                                          ? textColor
                                          : textColor.withValues(alpha: 0.4),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Event Date & Countdown Cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.04)
                                              : Colors.black.withValues(alpha: 0.03),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'SCHEDULED DATE',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor.withValues(alpha: 0.5)),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(Icons.event_note_rounded, size: 13, color: primaryColor),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    todo.formattedTargetDate,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: textColor),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isOverdue
                                              ? Colors.redAccent.withValues(alpha: 0.15)
                                              : primaryColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'COUNTDOWN',
                                              style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor.withValues(alpha: 0.5)),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  isOverdue
                                                      ? Icons.warning_amber_rounded
                                                      : Icons.hourglass_top_rounded,
                                                  size: 13,
                                                  color: isOverdue ? Colors.redAccent : primaryColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    todo.timeRemainingSummary,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isOverdue ? Colors.redAccent : primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Action Buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: textColor,
                                        side: BorderSide(color: cardBorder),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: const Text('Edit', style: TextStyle(fontSize: 11)),
                                      onPressed: () => _showAddEditTodoDialog(todo),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.delete_outline, size: 14),
                                      label: const Text('Delete', style: TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        final updated = List<TodoItem>.from(widget.todos)..remove(todo);
                                        widget.onTodosChanged(updated);
                                        AppSettings.saveSettings(todos: updated);
                                        AlarmService.updateTodos(updated);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildTodoFilterChip(String id, String label) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSelected = _todoFilter == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : textColor.withValues(alpha: 0.7),
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      onSelected: (val) {
        if (val) {
          setState(() => _todoFilter = id);
        }
      },
    );
  }
}

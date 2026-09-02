// lib/widgets/clock_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/services/alarm_service.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/services/timer_service.dart';

class ClockView extends StatefulWidget {
  final List<AlarmItem> alarms;
  final ValueChanged<List<AlarmItem>> onAlarmsChanged;

  const ClockView({
    super.key,
    required this.alarms,
    required this.onAlarmsChanged,
  });

  @override
  State<ClockView> createState() => _ClockViewState();
}

class _ClockViewState extends State<ClockView> {
  String _subTab = 'alarms'; // 'alarms', 'stopwatch', 'timer'

  // --- Stopwatch State ---
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _stopwatchTimer;
  final List<String> _laps = [];

  @override
  void dispose() {
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  // --- Stopwatch Handlers ---
  void _toggleStopwatch() {
    setState(() {
      if (_stopwatch.isRunning) {
        _stopwatch.stop();
        _stopwatchTimer?.cancel();
      } else {
        _stopwatch.start();
        _stopwatchTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  void _resetStopwatch() {
    setState(() {
      _stopwatch.stop();
      _stopwatch.reset();
      _stopwatchTimer?.cancel();
      _laps.clear();
    });
  }

  void _recordLap() {
    if (!_stopwatch.isRunning) return;
    final formatted = _formatStopwatchTime(_stopwatch.elapsedMilliseconds);
    setState(() {
      _laps.insert(0, 'Lap ${_laps.length + 1}: $formatted');
    });
  }

  String _formatStopwatchTime(int milliseconds) {
    final hundredths = (milliseconds ~/ 10) % 100;
    final seconds = (milliseconds ~/ 1000) % 60;
    final minutes = (milliseconds ~/ (1000 * 60)) % 60;
    final hours = (milliseconds ~/ (1000 * 60 * 60));

    final hStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    return '$hStr${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
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
                        color: Colors.teal.withValues(alpha: 0.15),
                        border: Border.all(color: Colors.teal),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(7, (idx) {
                        final dayNum = idx + 1;
                        final isSelected = selectedDays.contains(dayNum);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ChoiceChip(
                            label: Text(dayNames[idx], style: const TextStyle(fontSize: 11)),
                            selected: isSelected,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
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
                            selectedColor: Colors.teal,
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
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

  Widget _buildSubTabButton(String id, String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _subTab == id;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Focus(
      canRequestFocus: false,
      child: InkWell(
        onTap: () => setState(() => _subTab = id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              const SizedBox(width: 6),
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
        // Sub-tabs header: Alarms | Stopwatch | Timer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSubTabButton('alarms', 'Alarms', Icons.alarm),
            const SizedBox(width: 8),
            _buildSubTabButton('stopwatch', 'Stopwatch', Icons.timer_outlined),
            const SizedBox(width: 8),
            _buildSubTabButton('timer', 'Timer', Icons.hourglass_bottom_rounded),
          ],
        ),
        const SizedBox(height: 12),

        // --- SUB TAB CONTENTS ---
        Expanded(
          child: _subTab == 'alarms'
              ? _buildAlarmsView(cardBg, cardBorder, textColor)
              : _subTab == 'stopwatch'
                  ? _buildStopwatchView(cardBg, cardBorder, textColor)
                  : _buildTimerView(cardBg, cardBorder, textColor),
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
    final displayStr = _formatStopwatchTime(_stopwatch.elapsedMilliseconds);

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
                backgroundColor: _stopwatch.isRunning
                    ? Colors.orangeAccent
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _toggleStopwatch,
              icon: Icon(_stopwatch.isRunning ? Icons.pause : Icons.play_arrow),
              label: Text(_stopwatch.isRunning ? 'Pause' : 'Start'),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: textColor,
              ),
              onPressed: _recordLap,
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Lap'),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent,
              ),
              onPressed: _resetStopwatch,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _laps.isEmpty
              ? Center(
                  child: Text(
                    'No laps recorded',
                    style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: _laps.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _laps[index],
                        style: TextStyle(color: textColor, fontSize: 13, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- TIMER VIEW ---
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

        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.teal),
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
                  _buildTimeUnitInput(hoursController, 'Hours', textColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  ),
                  _buildTimeUnitInput(minutesController, 'Mins', textColor),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  ),
                  _buildTimeUnitInput(secondsController, 'Secs', textColor),
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
                backgroundColor: Colors.teal,
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

  Widget _buildTimeUnitInput(TextEditingController controller, String label, Color textColor) {
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
            borderSide: const BorderSide(color: Colors.teal, width: 1.5),
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
}

// lib/services/alarm_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/models/todo_item.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/services/audio_ducking_service.dart';
import 'package:omoji/services/logger_service.dart';
import 'package:omoji/services/timer_service.dart';
import 'package:window_manager/window_manager.dart';

class AlarmService {
  static Timer? _timer;
  static Timer? _audioLoopTimer;
  static Timer? _alarmRingingTimeoutTimer;
  static List<AlarmItem> _alarms = [];
  static List<TodoItem> _todos = [];
  static String? customAlarmSoundPath;
  static bool useSystemDefaultSound = true;
  static int audioLoopIntervalSeconds = 10;
  static bool enableAudioDucking = true;
  static Process? _currentAudioProcess;

  static final ValueNotifier<AlarmItem?> activeRingingAlarm = ValueNotifier(null);
  static final ValueNotifier<String?> activeRingingTimer = ValueNotifier(null);
  static final ValueNotifier<String?> silencedAlarmNotice = ValueNotifier(null);

  static Future<void> init(
    List<AlarmItem> alarms, {
    List<TodoItem>? todos,
    String? customSoundPath,
    bool? useSystemDefault,
    int? loopIntervalSeconds,
    bool? enableDucking,
  }) async {
    _alarms = alarms;
    if (todos != null) _todos = todos;
    customAlarmSoundPath = customSoundPath;
    if (useSystemDefault != null) useSystemDefaultSound = useSystemDefault;
    if (loopIntervalSeconds != null) audioLoopIntervalSeconds = loopIntervalSeconds.clamp(10, 93);
    if (enableDucking != null) enableAudioDucking = enableDucking;
    LoggerService.info('AlarmService initialized with ${_alarms.length} alarm(s) and ${_todos.length} todo(s).');
    _startMonitoring();
  }

  static void updateAlarms(List<AlarmItem> alarms) {
    _alarms = alarms;
  }

  static void updateTodos(List<TodoItem> todos) {
    _todos = todos;
  }

  static void updateCustomSoundPath(String? path) {
    customAlarmSoundPath = path;
  }

  static void updateAudioConfig({
    bool? useSystemDefault,
    String? customPath,
    int? loopIntervalSeconds,
    bool? enableDucking,
  }) {
    if (useSystemDefault != null) useSystemDefaultSound = useSystemDefault;
    if (customPath != null) customAlarmSoundPath = customPath;
    if (loopIntervalSeconds != null) audioLoopIntervalSeconds = loopIntervalSeconds.clamp(10, 93);
    if (enableDucking != null) enableAudioDucking = enableDucking;
  }

  static void _startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkAlarms();
    });
  }

  static Future<void> _checkAlarms() async {
    final now = DateTime.now();
    final currentHHmm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final currentDateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final currentWeekday = now.weekday; // 1 = Mon, ..., 7 = Sun

    for (var alarm in _alarms) {
      if (!alarm.isEnabled) continue;
      if (alarm.lastFiredDate == currentDateStr && alarm.time == currentHHmm) continue;

      if (alarm.time == currentHHmm) {
        bool shouldFire = false;
        if (alarm.repeatDays.isEmpty) {
          shouldFire = true;
        } else if (alarm.repeatDays.contains(currentWeekday)) {
          shouldFire = true;
        }

        if (shouldFire) {
          alarm.lastFiredDate = currentDateStr;
          LoggerService.info('Alarm triggered: "${alarm.label}" at $currentHHmm');
          triggerAlarm(alarm);
          break; // Trigger one alarm at a time
        }
      }
    }

    // Check To-Do Reminders
    for (var todo in _todos) {
      if (todo.isCompleted || todo.hasNotified) continue;
      if (now.isAfter(todo.targetDateTime) || now.isAtSameMomentAs(todo.targetDateTime)) {
        LoggerService.info('To-Do reminder triggered: "${todo.title}" (Recurrence: ${todo.recurrence})');
        if (todo.recurrence != 'none') {
          todo.advanceToNextRecurrence();
          LoggerService.info('Advanced recurring To-Do "${todo.title}" to ${todo.formattedTargetDate}');
        } else {
          todo.hasNotified = true;
        }
        AppSettings.saveSettings(todos: _todos);
        triggerTodoNotification(todo);
        break;
      }
    }
  }

  static Future<void> triggerTodoNotification(TodoItem todo) async {
    silencedAlarmNotice.value = null;
    activeRingingTimer.value = '📌 To-Do Reminder: ${todo.title}';
    _startAudioLoop();
    _startTimeoutTimer(300, isAlarm: false, label: 'To-Do: ${todo.title}');
    _sendSystemNotification(
      title: '📌 Reminder: ${todo.title}',
      body: todo.description.isNotEmpty ? todo.description : 'Scheduled event reminder',
    );
    _unminimizeWindow();
  }

  static Future<void> triggerAlarm(AlarmItem alarm) async {
    silencedAlarmNotice.value = null;
    activeRingingAlarm.value = alarm;
    TimerService.startOvertimeForAlarm();
    _startAudioLoop();
    final timeoutSecs = alarm.autoSilenceMinutes * 60;
    _startTimeoutTimer(timeoutSecs, isAlarm: true, alarm: alarm);
    _sendSystemNotification(
      title: '⏰ Alarm: ${alarm.label}',
      body: 'Time: ${alarm.time} (${alarm.repeatSummary})',
    );
    _unminimizeWindow();
  }

  static Future<void> triggerTimerFinished(String label) async {
    silencedAlarmNotice.value = null;
    activeRingingTimer.value = label;
    _startAudioLoop();
    _startTimeoutTimer(300, isAlarm: false, label: label);
    _sendSystemNotification(
      title: '⏳ Timer Finished!',
      body: label,
    );
    _unminimizeWindow();
  }

  static void _startTimeoutTimer(int seconds, {required bool isAlarm, AlarmItem? alarm, String? label}) {
    _alarmRingingTimeoutTimer?.cancel();
    _alarmRingingTimeoutTimer = Timer(Duration(seconds: seconds), () {
      _autoSilenceRinging(isAlarm: isAlarm, alarm: alarm, label: label);
    });
  }

  static void _autoSilenceRinging({required bool isAlarm, AlarmItem? alarm, String? label}) {
    _audioLoopTimer?.cancel();
    _audioLoopTimer = null;
    _alarmRingingTimeoutTimer = null;
    killAudioProcess();
    AudioDuckingService.restoreAudio();

    try {
      windowManager.setAlwaysOnTop(false);
    } catch (_) {}

    if (isAlarm && alarm != null) {
      if (alarm.repeatDays.isEmpty) {
        alarm.isEnabled = false;
        AppSettings.saveSettings(alarms: _alarms);
      }
      silencedAlarmNotice.value =
          "Alarm '${alarm.label}' (${alarm.time}) was automatically silenced after ${alarm.autoSilenceMinutes} min(s).";
      LoggerService.info('Alarm "${alarm.label}" automatically silenced.');
    } else {
      silencedAlarmNotice.value =
          "Timer '${label ?? 'Finished'}' was automatically silenced after 5 min(s).";
      LoggerService.info('Timer "${label ?? 'Finished'}" automatically silenced.');
    }

    activeRingingAlarm.value = null;
    activeRingingTimer.value = null;
  }

  static void _startAudioLoop() {
    _audioLoopTimer?.cancel();
    AudioDuckingService.duckAudio(enabled: enableAudioDucking);
    playAlertSound();
    final intervalSecs = audioLoopIntervalSeconds.clamp(10, 93);
    _audioLoopTimer = Timer.periodic(Duration(seconds: intervalSecs), (_) {
      playAlertSound();
    });
  }

  static void killAudioProcess() {
    if (_currentAudioProcess != null) {
      try {
        _currentAudioProcess!.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _currentAudioProcess = null;
    }
    if (Platform.isLinux) {
      try {
        Process.run('pkill', ['-9', '-f', 'pw-play']);
        Process.run('pkill', ['-9', '-f', 'ffplay']);
        Process.run('pkill', ['-9', '-f', 'mpg123']);
        Process.run('pkill', ['-9', '-f', 'paplay']);
        Process.run('pkill', ['-9', '-f', 'aplay']);
        Process.run('pkill', ['-9', '-f', 'cvlc']);
        Process.run('pkill', ['-9', '-f', 'canberra-gtk-play']);
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        Process.run('pkill', ['-9', 'afplay']);
      } catch (_) {}
    }
  }

  static Future<void> playAlertSound({String? customPath}) async {
    killAudioProcess();
    final soundPath = customPath ?? customAlarmSoundPath;
    LoggerService.info('Playing alert sound (CustomPath: $soundPath, UseDefault: $useSystemDefaultSound)');

    // Play custom audio file if enabled and exists
    if (!useSystemDefaultSound && soundPath != null && soundPath.isNotEmpty && File(soundPath).existsSync()) {
      if (Platform.isLinux) {
        try {
          _currentAudioProcess = await Process.start(
            'pw-play',
            [soundPath],
          );
          return;
        } catch (_) {}

        try {
          _currentAudioProcess = await Process.start(
            'ffplay',
            ['-nodisp', '-autoexit', '-loglevel', 'quiet', soundPath],
          );
          return;
        } catch (_) {}

        try {
          _currentAudioProcess = await Process.start('paplay', [soundPath]);
          return;
        } catch (_) {}

        try {
          _currentAudioProcess = await Process.start(
            'cvlc',
            ['--play-and-exit', soundPath],
          );
          return;
        } catch (_) {}

        try {
          _currentAudioProcess = await Process.start('mpg123', ['-q', soundPath]);
          return;
        } catch (_) {}

        try {
          _currentAudioProcess = await Process.start(
            'canberra-gtk-play',
            ['--file=$soundPath'],
          );
          return;
        } catch (_) {}
      } else if (Platform.isMacOS) {
        try {
          _currentAudioProcess = await Process.start('afplay', [soundPath]);
          return;
        } catch (_) {}
      }
    }

    // Default System Fallback Sound
    if (Platform.isLinux) {
      try {
        _currentAudioProcess = await Process.start(
          'canberra-gtk-play',
          ['--id=alarm-clock-elapsed'],
        );
      } catch (_) {
        try {
          _currentAudioProcess = await Process.start('paplay', [
            '/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga'
          ]);
        } catch (_) {}
      }
    } else if (Platform.isMacOS) {
      try {
        _currentAudioProcess = await Process.start('afplay', [
          '/System/Library/Sounds/Glass.aiff'
        ]);
      } catch (_) {}
    }
  }

  static Future<void> _sendSystemNotification({
    required String title,
    required String body,
  }) async {
    if (Platform.isLinux) {
      try {
        await Process.run('notify-send', [
          '-u',
          'critical',
          '-i',
          'alarm-clock',
          title,
          body,
        ]);
      } catch (e) {
        debugPrint('Failed notify-send: $e');
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('osascript', [
          '-e',
          'display notification "$body" with title "$title" sound name "Glass"'
        ]);
      } catch (e) {
        debugPrint('Failed macOS notification: $e');
      }
    }
  }

  static Future<void> _unminimizeWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
    } catch (e) {
      debugPrint('Failed to unminimize window on alarm: $e');
    }
  }

  static void stopRinging() {
    _audioLoopTimer?.cancel();
    _audioLoopTimer = null;
    _alarmRingingTimeoutTimer?.cancel();
    _alarmRingingTimeoutTimer = null;
    killAudioProcess();
    AudioDuckingService.restoreAudio();
    TimerService.reset();

    try {
      windowManager.setAlwaysOnTop(false);
    } catch (_) {}

    final alarm = activeRingingAlarm.value;
    if (alarm != null) {
      if (alarm.repeatDays.isEmpty) {
        alarm.isEnabled = false;
        AppSettings.saveSettings(alarms: _alarms);
      }
      LoggerService.info('User stopped alarm ringing: "${alarm.label}"');
    }

    activeRingingAlarm.value = null;
    activeRingingTimer.value = null;
  }

  static void dispose() {
    _timer?.cancel();
    _audioLoopTimer?.cancel();
    _alarmRingingTimeoutTimer?.cancel();
    killAudioProcess();
    AudioDuckingService.restoreAudio();
  }
}

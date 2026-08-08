// lib/services/alarm_service.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:window_manager/window_manager.dart';

class AlarmService {
  static Timer? _timer;
  static Timer? _audioLoopTimer;
  static Timer? _alarmRingingTimeoutTimer;
  static List<AlarmItem> _alarms = [];
  static String? customAlarmSoundPath;
  static Process? _currentAudioProcess;

  static final ValueNotifier<AlarmItem?> activeRingingAlarm = ValueNotifier(null);
  static final ValueNotifier<String?> activeRingingTimer = ValueNotifier(null);

  static Future<void> init(List<AlarmItem> alarms, {String? customSoundPath}) async {
    _alarms = alarms;
    customAlarmSoundPath = customSoundPath;
    _startMonitoring();
  }

  static void updateAlarms(List<AlarmItem> alarms) {
    _alarms = alarms;
  }

  static void updateCustomSoundPath(String? path) {
    customAlarmSoundPath = path;
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
          triggerAlarm(alarm);
          break; // Trigger one alarm at a time
        }
      }
    }
  }

  static Future<void> triggerAlarm(AlarmItem alarm) async {
    activeRingingAlarm.value = alarm;
    _startAudioLoop();
    _startTimeoutTimer();
    _sendSystemNotification(
      title: '⏰ Alarm: ${alarm.label}',
      body: 'Time: ${alarm.time} (${alarm.repeatSummary})',
    );
    _unminimizeWindow();
  }

  static Future<void> triggerTimerFinished(String label) async {
    activeRingingTimer.value = label;
    _startAudioLoop();
    _startTimeoutTimer();
    _sendSystemNotification(
      title: '⏳ Timer Finished!',
      body: label,
    );
    _unminimizeWindow();
  }

  static void _startTimeoutTimer() {
    _alarmRingingTimeoutTimer?.cancel();
    // Auto-stop ringing after 60 seconds if unattended
    _alarmRingingTimeoutTimer = Timer(const Duration(seconds: 60), () {
      stopRinging();
    });
  }

  static void _startAudioLoop() {
    _audioLoopTimer?.cancel();
    playAlertSound();
    _audioLoopTimer = Timer.periodic(const Duration(seconds: 4), (_) {
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
        Process.run('pkill', ['-9', '-f', 'ffplay']);
        Process.run('pkill', ['-9', '-f', 'mpg123']);
        Process.run('pkill', ['-9', '-f', 'paplay']);
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

    if (soundPath != null && soundPath.isNotEmpty && File(soundPath).existsSync()) {
      if (Platform.isLinux) {
        try {
          _currentAudioProcess = await Process.start(
            'ffplay',
            ['-nodisp', '-autoexit', '-loglevel', 'quiet', soundPath],
          );
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
          _currentAudioProcess = await Process.start('paplay', [soundPath]);
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

    try {
      windowManager.setAlwaysOnTop(false);
    } catch (_) {}

    final alarm = activeRingingAlarm.value;
    if (alarm != null) {
      if (alarm.repeatDays.isEmpty) {
        alarm.isEnabled = false;
        AppSettings.saveSettings(alarms: _alarms);
      }
    }

    activeRingingAlarm.value = null;
    activeRingingTimer.value = null;
  }

  static void dispose() {
    _timer?.cancel();
    _audioLoopTimer?.cancel();
    _alarmRingingTimeoutTimer?.cancel();
    killAudioProcess();
  }
}

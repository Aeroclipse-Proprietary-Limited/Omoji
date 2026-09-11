// lib/services/app_settings.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/models/clipboard_item.dart';
import 'package:omoji/models/todo_item.dart';

class AppSettings {
  static File get _configFile {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.config/omoji/settings.json');
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final file = _configFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
    return {};
  }

  static Future<void> saveSettings({
    ThemeMode? theme,
    List<ClipboardItem>? clipboardHistory,
    bool? privateMode,
    bool? autoPaste,
    bool? ignoreEmojisInClipboard,
    List<AlarmItem>? alarms,
    List<TodoItem>? todos,
    String? customAlarmSoundPath,
    bool clearCustomAlarmSound = false,
    int? timerDurationSeconds,
    int? timerTargetTimestampMs,
    bool? timerIsRunning,
    bool? timerIsPaused,
    int? timerRemainingSeconds,
    int? accentColorValue,
    int? timerOvertimeStartTimestampMs,
    bool? stopwatchIsRunning,
    int? stopwatchStartTimestampMs,
    int? stopwatchAccumulatedMs,
    List<String>? stopwatchLaps,
    bool? enableEmojiPredictions,
    String? primaryTrigger,
    String? secondaryTrigger,
    bool? useSystemDefaultSound,
    int? audioLoopIntervalSeconds,
  }) async {
    try {
      final file = _configFile;
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      Map<String, dynamic> current = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          current = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (theme != null) {
        String themeName;
        switch (theme) {
          case ThemeMode.light:
            themeName = 'light';
            break;
          case ThemeMode.dark:
            themeName = 'dark';
            break;
          case ThemeMode.system:
            themeName = 'system';
            break;
        }
        current['theme'] = themeName;
      }
      if (clipboardHistory != null) {
        current['clipboardHistory'] =
            clipboardHistory.map((item) => item.toJson()).toList();
      }
      if (privateMode != null) {
        current['privateMode'] = privateMode;
      }
      if (autoPaste != null) {
        current['autoPaste'] = autoPaste;
      }
      if (ignoreEmojisInClipboard != null) {
        current['ignoreEmojisInClipboard'] = ignoreEmojisInClipboard;
      }
      if (alarms != null) {
        current['alarms'] = alarms.map((item) => item.toJson()).toList();
      }
      if (todos != null) {
        current['todos'] = todos.map((item) => item.toJson()).toList();
      }
      if (clearCustomAlarmSound) {
        current.remove('customAlarmSoundPath');
      } else if (customAlarmSoundPath != null) {
        current['customAlarmSoundPath'] = customAlarmSoundPath;
      }
      if (timerDurationSeconds != null) {
        current['timerDurationSeconds'] = timerDurationSeconds;
      }
      if (timerTargetTimestampMs != null) {
        current['timerTargetTimestampMs'] = timerTargetTimestampMs;
      } else if (timerIsRunning == false) {
        current.remove('timerTargetTimestampMs');
      }
      if (timerIsRunning != null) {
        current['timerIsRunning'] = timerIsRunning;
      }
      if (timerIsPaused != null) {
        current['timerIsPaused'] = timerIsPaused;
      }
      if (timerRemainingSeconds != null) {
        current['timerRemainingSeconds'] = timerRemainingSeconds;
      }
      if (accentColorValue != null) {
        current['accentColor'] = accentColorValue;
      }
      if (timerOvertimeStartTimestampMs != null) {
        current['timerOvertimeStartTimestampMs'] = timerOvertimeStartTimestampMs;
      } else {
        current.remove('timerOvertimeStartTimestampMs');
      }
      if (stopwatchIsRunning != null) {
        current['stopwatchIsRunning'] = stopwatchIsRunning;
      }
      if (stopwatchStartTimestampMs != null) {
        current['stopwatchStartTimestampMs'] = stopwatchStartTimestampMs;
      } else if (stopwatchIsRunning == false) {
        current.remove('stopwatchStartTimestampMs');
      }
      if (stopwatchAccumulatedMs != null) {
        current['stopwatchAccumulatedMs'] = stopwatchAccumulatedMs;
      }
      if (stopwatchLaps != null) {
        current['stopwatchLaps'] = stopwatchLaps;
      }
      if (enableEmojiPredictions != null) {
        current['enableEmojiPredictions'] = enableEmojiPredictions;
      }
      if (primaryTrigger != null) {
        current['primaryTrigger'] = primaryTrigger;
      }
      if (secondaryTrigger != null) {
        current['secondaryTrigger'] = secondaryTrigger;
      }
      if (useSystemDefaultSound != null) {
        current['useSystemDefaultSound'] = useSystemDefaultSound;
      }
      if (audioLoopIntervalSeconds != null) {
        current['audioLoopIntervalSeconds'] = audioLoopIntervalSeconds;
      }

      await file.writeAsString(jsonEncode(current));
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }
}

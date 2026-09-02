// lib/services/app_settings.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/models/clipboard_item.dart';

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
    String? customAlarmSoundPath,
    bool clearCustomAlarmSound = false,
    int? timerDurationSeconds,
    int? timerTargetTimestampMs,
    bool? timerIsRunning,
    bool? timerIsPaused,
    int? timerRemainingSeconds,
    int? accentColorValue,
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

      await file.writeAsString(jsonEncode(current));
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }
}

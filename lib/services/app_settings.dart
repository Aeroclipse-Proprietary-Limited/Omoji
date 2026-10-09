// lib/services/app_settings.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/models/clipboard_item.dart';
import 'package:omoji/models/todo_item.dart';

class AppSettings {
  static const String _backupFormat = 'omoji-backup';
  static const int _backupVersion = 1;
  static final ValueNotifier<int> dataImportRevision = ValueNotifier(0);

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

  static Future<void> exportBackup(String path) async {
    final settingsFile = _configFile;
    final settings = await settingsFile.exists()
        ? jsonDecode(await settingsFile.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{};
    final backup = {
      'format': _backupFormat,
      'version': _backupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': settings,
    };
    await File(path).writeAsString(
      const JsonEncoder.withIndent('  ').convert(backup),
      flush: true,
    );
  }

  static Map<String, dynamic> decodeBackup(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != _backupFormat ||
        decoded['version'] != _backupVersion ||
        decoded['settings'] is! Map) {
      throw const FormatException('This file is not a supported Omoji backup.');
    }

    final settings = Map<String, dynamic>.from(decoded['settings'] as Map);
    _validateBackupSettings(settings);
    return settings;
  }

  static Future<void> importBackup(
    String path, {
    void Function()? beforeReplace,
  }) async {
    final settings = decodeBackup(await File(path).readAsString());
    final file = _configFile;
    await file.parent.create(recursive: true);
    final temporaryFile = File('${file.path}.importing');
    try {
      await temporaryFile.writeAsString(jsonEncode(settings), flush: true);
      beforeReplace?.call();
      await temporaryFile.rename(file.path);
    } catch (_) {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      rethrow;
    }
    dataImportRevision.value++;
  }

  static void _validateBackupSettings(Map<String, dynamic> settings) {
    const booleanKeys = {
      'privateMode',
      'autoPaste',
      'ignoreEmojisInClipboard',
      'timerIsRunning',
      'timerIsPaused',
      'stopwatchIsRunning',
      'enableEmojiPredictions',
      'useSystemDefaultSound',
      'enableAudioDucking',
    };
    const integerKeys = {
      'timerDurationSeconds',
      'timerTargetTimestampMs',
      'timerRemainingSeconds',
      'accentColor',
      'timerOvertimeStartTimestampMs',
      'stopwatchStartTimestampMs',
      'stopwatchAccumulatedMs',
      'audioLoopIntervalSeconds',
    };
    const stringKeys = {
      'theme',
      'customAlarmSoundPath',
      'primaryTrigger',
      'secondaryTrigger',
      'dateFormat',
      'todoDefaultView',
    };

    for (final key in booleanKeys) {
      if (settings.containsKey(key) && settings[key] is! bool) {
        throw FormatException('Invalid "$key" value in Omoji backup.');
      }
    }
    for (final key in integerKeys) {
      if (settings.containsKey(key) &&
          settings[key] != null &&
          settings[key] is! int) {
        throw FormatException('Invalid "$key" value in Omoji backup.');
      }
    }
    for (final key in stringKeys) {
      if (settings.containsKey(key) &&
          settings[key] != null &&
          settings[key] is! String) {
        throw FormatException('Invalid "$key" value in Omoji backup.');
      }
    }

    for (final key in ['alarms', 'todos', 'clipboardHistory']) {
      final value = settings[key];
      if (value == null) continue;
      if (value is! List) {
        throw FormatException('Invalid "$key" list in Omoji backup.');
      }
      for (final item in value) {
        if (item is! Map) {
          throw FormatException('Invalid item in "$key" list in Omoji backup.');
        }
        final json = Map<String, dynamic>.from(item);
        switch (key) {
          case 'alarms':
            final alarm = AlarmItem.fromJson(json);
            if (alarm.repeatDays.any((day) => day < 1 || day > 7) ||
                alarm.autoSilenceMinutes < 1) {
              throw const FormatException('Invalid alarm data in Omoji backup.');
            }
            break;
          case 'todos':
            TodoItem.fromJson(json);
            break;
          case 'clipboardHistory':
            ClipboardItem.fromJson(json);
            break;
        }
      }
    }

    final laps = settings['stopwatchLaps'];
    if (laps != null &&
        (laps is! List || laps.any((lap) => lap is! String))) {
      throw const FormatException('Invalid stopwatch laps in Omoji backup.');
    }

    if ((settings['timerDurationSeconds'] as int? ?? 1) < 1 ||
        (settings['timerRemainingSeconds'] as int? ?? 0) < 0 ||
        (settings['stopwatchAccumulatedMs'] as int? ?? 0) < 0) {
      throw const FormatException('Invalid timer or stopwatch value in Omoji backup.');
    }
  }

  static Future<void> saveSettings({
    //An imaginary A4 paper
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
    String? dateFormat,
    bool? enableAudioDucking,
    String? todoDefaultView,
  }) async {
    // I Imagine something/ convert a hater from thin air and materialize it into a file (app. (see policy))
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
      if (dateFormat != null) {
        current['dateFormat'] = dateFormat;
      }
      if (enableAudioDucking != null) {
        current['enableAudioDucking'] = enableAudioDucking;
      }
      if (todoDefaultView != null) {
        current['todoDefaultView'] = todoDefaultView;
      }

      await file.writeAsString(jsonEncode(current));
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }
}

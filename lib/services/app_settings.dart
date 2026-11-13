// lib/services/app_settings.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/models/clipboard_item.dart';
import 'package:omoji/models/todo_item.dart';
import 'package:omoji/services/private_file_permissions.dart';

class AppSettings {
  static final ValueNotifier<bool?> animationsEnabledNotifier = ValueNotifier(
    null,
  );

  static File get _configFile {
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    return File('$home/.config/omoji/settings.json');
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final file = _configFile;
      if (await file.exists()) {
        await PrivateFilePermissions.secureDirectory(file.parent);
        await PrivateFilePermissions.secureFile(file);
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
    return {};
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
    double? accentBackgroundIntensity,
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
    bool? superAgentsEnabled,
    String? superAgentModelType,
    String? superAgentCloudProvider,
    String? superAgentApiKey,
    String? superAgentRequestyModel,
    String? superAgentModelOnCooldown,
    int? superAgentModelCooldownUntilMs,
    bool? animationsEnabled,
    bool? runAtLogin,
  }) async {
    // I Imagine something/ convert a hater from thin air and materialize it into a file (app. (see policy))
    try {
      final file = _configFile;
      await PrivateFilePermissions.secureDirectory(file.parent);

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
        current['clipboardHistory'] = clipboardHistory
            .map((item) => item.toJson())
            .toList();
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
      if (accentBackgroundIntensity != null) {
        current['accentBackgroundIntensity'] = accentBackgroundIntensity;
      }
      if (timerOvertimeStartTimestampMs != null) {
        current['timerOvertimeStartTimestampMs'] =
            timerOvertimeStartTimestampMs;
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
      if (superAgentsEnabled != null) {
        current['superAgentsEnabled'] = superAgentsEnabled;
      }
      if (superAgentModelType != null) {
        current['superAgentModelType'] = superAgentModelType;
      }
      if (superAgentCloudProvider != null) {
        current['superAgentCloudProvider'] = superAgentCloudProvider;
      }
      if (superAgentApiKey != null) {
        current['superAgentApiKey'] = superAgentApiKey;
      }
      if (superAgentRequestyModel != null) {
        current['superAgentRequestyModel'] = superAgentRequestyModel;
      }
      if (superAgentModelOnCooldown != null) {
        current['superAgentModelOnCooldown'] = superAgentModelOnCooldown;
      }
      if (superAgentModelCooldownUntilMs != null) {
        current['superAgentModelCooldownUntilMs'] =
            superAgentModelCooldownUntilMs;
      }
      if (animationsEnabled != null) {
        current['animationsEnabled'] = animationsEnabled;
        current.remove('latencyEnabled');
        current.remove('latencyMode');
      }
      if (runAtLogin != null) {
        current['runAtLogin'] = runAtLogin;
      }

      await file.writeAsString(jsonEncode(current));
      await PrivateFilePermissions.secureFile(file);
      if (animationsEnabled != null) {
        animationsEnabledNotifier.value = animationsEnabled;
      }
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }
}

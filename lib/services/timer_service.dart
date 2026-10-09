// lib/services/timer_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:omoji/services/alarm_service.dart';
import 'package:omoji/services/app_settings.dart';

class TimerService {
  static int durationSeconds = 300; // Default 5 minutes
  static int remainingSeconds = 300;
  static bool isRunning = false;
  static bool isPaused = false;
  static int? targetTimestampMs;
  static int? overtimeStartTimestampMs;

  static Timer? _periodicTimer;
  static Timer? _overtimeTimer;
  static final ValueNotifier<int> remainingNotifier = ValueNotifier(300);
  static final ValueNotifier<bool> runningNotifier = ValueNotifier(false);
  static final ValueNotifier<int> overtimeNotifier = ValueNotifier(0);

  static Future<void> init() async {
    _periodicTimer?.cancel();
    _overtimeTimer?.cancel();
    durationSeconds = 300;
    remainingSeconds = 300;
    isRunning = false;
    isPaused = false;
    targetTimestampMs = null;
    overtimeStartTimestampMs = null;
    overtimeNotifier.value = 0;

    final settings = await AppSettings.loadSettings();
    durationSeconds = settings['timerDurationSeconds'] as int? ?? 300;
    final savedTargetMs = settings['timerTargetTimestampMs'] as int?;
    final savedIsRunning = settings['timerIsRunning'] as bool? ?? false;
    final savedIsPaused = settings['timerIsPaused'] as bool? ?? false;
    final savedRemaining = settings['timerRemainingSeconds'] as int? ?? durationSeconds;
    final savedOvertimeStartMs = settings['timerOvertimeStartTimestampMs'] as int?;

    if (savedOvertimeStartMs != null) {
      overtimeStartTimestampMs = savedOvertimeStartMs;
      _startOvertimeTimer();
    }

    if (savedIsRunning && savedTargetMs != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = ((savedTargetMs - nowMs) / 1000).ceil();
      if (diffSeconds > 0) {
        targetTimestampMs = savedTargetMs;
        remainingSeconds = diffSeconds;
        isRunning = true;
        isPaused = false;
        _startTimerLoop();
      } else {
        remainingSeconds = 0;
        isRunning = false;
        isPaused = false;
        if (overtimeStartTimestampMs == null) {
          overtimeStartTimestampMs = savedTargetMs;
          _startOvertimeTimer();
        }
        _saveState();
      }
    } else if (savedIsPaused) {
      isRunning = false;
      isPaused = true;
      remainingSeconds = savedRemaining;
    } else {
      isRunning = false;
      isPaused = false;
      remainingSeconds = savedRemaining;
    }

    _notify();
  }

  static void startOvertimeForAlarm() {
    overtimeStartTimestampMs = DateTime.now().millisecondsSinceEpoch;
    _startOvertimeTimer();
  }

  static void setDuration(int seconds) {
    if (isRunning) return;
    _clearOvertime();
    durationSeconds = seconds;
    remainingSeconds = seconds;
    isPaused = false;
    _notify();
    _saveState();
  }

  static void start() {
    if (remainingSeconds <= 0) return;
    _clearOvertime();
    isRunning = true;
    isPaused = false;
    targetTimestampMs = DateTime.now().millisecondsSinceEpoch + (remainingSeconds * 1000);
    _startTimerLoop();
    _notify();
    _saveState();
  }

  static void pause() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    isRunning = false;
    isPaused = true;
    _notify();
    _saveState();
  }

  static void reset() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _clearOvertime();
    isRunning = false;
    isPaused = false;
    targetTimestampMs = null;
    remainingSeconds = durationSeconds;
    _notify();
    _saveState();
  }

  static void _clearOvertime() {
    _overtimeTimer?.cancel();
    _overtimeTimer = null;
    overtimeStartTimestampMs = null;
    overtimeNotifier.value = 0;
  }

  static void _startOvertimeTimer() {
    _overtimeTimer?.cancel();
    if (overtimeStartTimestampMs == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSecs = (nowMs - overtimeStartTimestampMs!) ~/ 1000;
    overtimeNotifier.value = elapsedSecs > 0 ? elapsedSecs : 0;

    _overtimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (overtimeStartTimestampMs == null) return;
      final curMs = DateTime.now().millisecondsSinceEpoch;
      final secs = (curMs - overtimeStartTimestampMs!) ~/ 1000;
      overtimeNotifier.value = secs > 0 ? secs : 0;
    });
  }

  static void _startTimerLoop() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (targetTimestampMs == null) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final diffMs = targetTimestampMs! - nowMs;
      final currentRemaining = (diffMs / 1000.0).ceil();

      if (currentRemaining > 0) {
        remainingSeconds = currentRemaining;
        _notify();
      } else {
        _periodicTimer?.cancel();
        _periodicTimer = null;
        remainingSeconds = 0;
        isRunning = false;
        isPaused = false;
        targetTimestampMs = null;
        overtimeStartTimestampMs = nowMs;
        _startOvertimeTimer();
        _notify();
        _saveState();
        AlarmService.triggerTimerFinished('Timer Elapsed!');
      }
    });
  }

  static void _notify() {
    remainingNotifier.value = remainingSeconds;
    runningNotifier.value = isRunning;
  }

  static Future<void> _saveState() async {
    await AppSettings.saveSettings(
      timerDurationSeconds: durationSeconds,
      timerTargetTimestampMs: targetTimestampMs,
      timerIsRunning: isRunning,
      timerIsPaused: isPaused,
      timerRemainingSeconds: remainingSeconds,
      timerOvertimeStartTimestampMs: overtimeStartTimestampMs,
    );
  }
}

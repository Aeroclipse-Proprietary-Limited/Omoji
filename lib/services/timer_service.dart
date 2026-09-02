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

  static Timer? _periodicTimer;
  static final ValueNotifier<int> remainingNotifier = ValueNotifier(300);
  static final ValueNotifier<bool> runningNotifier = ValueNotifier(false);

  static Future<void> init() async {
    final settings = await AppSettings.loadSettings();
    durationSeconds = settings['timerDurationSeconds'] as int? ?? 300;
    final savedTargetMs = settings['timerTargetTimestampMs'] as int?;
    final savedIsRunning = settings['timerIsRunning'] as bool? ?? false;
    final savedIsPaused = settings['timerIsPaused'] as bool? ?? false;
    final savedRemaining = settings['timerRemainingSeconds'] as int? ?? durationSeconds;

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
        _saveState();
      }
    } else if (savedIsPaused) {
      isRunning = false;
      isPaused = true;
      remainingSeconds = savedRemaining;
    } else {
      isRunning = false;
      isPaused = false;
      remainingSeconds = durationSeconds;
    }

    _notify();
  }

  static void setDuration(int seconds) {
    if (isRunning) return;
    durationSeconds = seconds;
    remainingSeconds = seconds;
    isPaused = false;
    _notify();
    _saveState();
  }

  static void start() {
    if (remainingSeconds <= 0) return;
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
    isRunning = false;
    isPaused = false;
    targetTimestampMs = null;
    remainingSeconds = durationSeconds;
    _notify();
    _saveState();
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
    );
  }
}

// lib/services/stopwatch_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:omoji/services/app_settings.dart';

class StopwatchService {
  static bool isRunning = false;
  static int accumulatedMs = 0;
  static int? startTimestampMs;
  static List<String> laps = [];

  static Timer? _tickerTimer;

  static final ValueNotifier<int> elapsedNotifier = ValueNotifier(0);
  static final ValueNotifier<bool> runningNotifier = ValueNotifier(false);
  static final ValueNotifier<List<String>> lapsNotifier = ValueNotifier([]);

  static Future<void> init() async {
    _tickerTimer?.cancel();
    isRunning = false;
    accumulatedMs = 0;
    startTimestampMs = null;
    laps = [];

    final settings = await AppSettings.loadSettings();
    final savedIsRunning = settings['stopwatchIsRunning'] as bool? ?? false;
    final savedStartMs = settings['stopwatchStartTimestampMs'] as int?;
    final savedAccumulatedMs = settings['stopwatchAccumulatedMs'] as int? ?? 0;
    final rawLaps = settings['stopwatchLaps'] as List<dynamic>?;

    if (rawLaps != null) {
      laps = rawLaps.map((e) => e.toString()).toList();
    }

    accumulatedMs = savedAccumulatedMs;

    if (savedIsRunning && savedStartMs != null) {
      isRunning = true;
      startTimestampMs = savedStartMs;
      _startTicker();
    } else {
      isRunning = false;
      startTimestampMs = null;
      elapsedNotifier.value = accumulatedMs;
    }

    _notify();
  }

  static int get elapsedMilliseconds {
    if (isRunning && startTimestampMs != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      return accumulatedMs + (nowMs - startTimestampMs!);
    }
    return accumulatedMs;
  }

  static void start() {
    if (isRunning) return;
    isRunning = true;
    startTimestampMs = DateTime.now().millisecondsSinceEpoch;
    _startTicker();
    _notify();
    _saveState();
  }

  static void pause() {
    if (!isRunning) return;
    if (startTimestampMs != null) {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      accumulatedMs += (nowMs - startTimestampMs!);
    }
    startTimestampMs = null;
    isRunning = false;
    _tickerTimer?.cancel();
    _tickerTimer = null;
    elapsedNotifier.value = accumulatedMs;
    _notify();
    _saveState();
  }

  static void toggle() {
    if (isRunning) {
      pause();
    } else {
      start();
    }
  }

  static void reset() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
    isRunning = false;
    startTimestampMs = null;
    accumulatedMs = 0;
    laps.clear();
    elapsedNotifier.value = 0;
    _notify();
    _saveState();
  }

  static void recordLap() {
    if (elapsedMilliseconds <= 0) return;
    final formatted = formatStopwatchTime(elapsedMilliseconds);
    laps.insert(0, 'Lap ${laps.length + 1}: $formatted');
    lapsNotifier.value = List.from(laps);
    _saveState();
  }

  static String formatStopwatchTime(int milliseconds) {
    final hundredths = (milliseconds ~/ 10) % 100;
    final seconds = (milliseconds ~/ 1000) % 60;
    final minutes = (milliseconds ~/ (1000 * 60)) % 60;
    final hours = (milliseconds ~/ (1000 * 60 * 60));

    final hStr = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    return '$hStr${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  static void _startTicker() {
    _tickerTimer?.cancel();
    elapsedNotifier.value = elapsedMilliseconds;
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      elapsedNotifier.value = elapsedMilliseconds;
    });
  }

  static void _notify() {
    runningNotifier.value = isRunning;
    lapsNotifier.value = List.from(laps);
  }

  static Future<void> _saveState() async {
    await AppSettings.saveSettings(
      stopwatchIsRunning: isRunning,
      stopwatchStartTimestampMs: startTimestampMs,
      stopwatchAccumulatedMs: accumulatedMs,
      stopwatchLaps: laps,
    );
  }
}

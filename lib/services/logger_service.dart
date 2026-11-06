// lib/services/logger_service.dart

import 'dart:io';
import 'package:flutter/material.dart';

class LoggerService {
  static File get _logFile {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.config/omoji/omoji.log');
  }

  static Future<void> info(String message) async {
    await _writeLog('INFO', message);
  }

  static Future<void> warn(String message) async {
    await _writeLog('WARN', message);
  }

  static Future<void> error(
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) async {
    final errStr = error != null ? ' | Error: $error' : '';
    final stackStr = stackTrace != null ? '\n$stackTrace' : '';
    await _writeLog('ERROR', '$message$errStr$stackStr');
  }

  static Future<void> _writeLog(String level, String message) async {
    final now = DateTime.now().toIso8601String();
    final logLine = '[$now] [$level] $message\n';

    try {
      final file = _logFile;
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
    } catch (e) {
      debugPrint('Failed to write to omoji.log: $e');
    }
  }

  static Future<String> readLog({Set<String>? levels}) async {
    try {
      final file = _logFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (levels == null || levels.length == 3) return content;

        final selected = <String>[];
        String? currentLevel;
        final currentLines = <String>[];
        void flushEntry() {
          if (currentLevel != null && levels.contains(currentLevel)) {
            selected.addAll(currentLines);
          }
          currentLines.clear();
        }

        for (final line in content.split('\n')) {
          final match = RegExp(
            r'^\[[^]]+\] \[(INFO|WARN|ERROR)\]',
          ).firstMatch(line);
          if (match != null) {
            flushEntry();
            currentLevel = match.group(1);
          }
          if (currentLevel != null) currentLines.add(line);
        }
        flushEntry();
        return selected.isEmpty
            ? 'No log entries match the selected filters.'
            : selected.join('\n');
      }
    } catch (e) {
      debugPrint('Failed to read log file: $e');
    }
    return 'No log file found at ~/.config/omoji/omoji.log';
  }

  static Future<void> clearLog() async {
    try {
      final file = _logFile;
      if (await file.exists()) {
        await file.writeAsString('');
      }
    } catch (e) {
      debugPrint('Failed to clear log file: $e');
    }
  }
}

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

  static Future<void> error(String message, [Object? error, StackTrace? stackTrace]) async {
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

  static Future<String> readLog() async {
    try {
      final file = _logFile;
      if (await file.exists()) {
        return await file.readAsString();
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

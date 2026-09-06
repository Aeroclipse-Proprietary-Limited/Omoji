// lib/services/emoji_prediction_service.dart
// ignore_for_file: unused_field, unused_element, prefer_final_fields

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

class PredictionEvent {
  final String type; // 'prediction', 'clear', 'autofill'
  final String word;
  final List<Map<String, String>> predictions;
  final String? emoji;
  final int? x;
  final int? y;

  PredictionEvent({
    required this.type,
    this.word = '',
    this.predictions = const [],
    this.emoji,
    this.x,
    this.y,
  });
}

class EmojiPredictionService {
  static final ValueNotifier<PredictionEvent?> currentEvent = ValueNotifier(null);
  static Process? _daemonProcess;
  static Socket? _socket;
  static Timer? _reconnectTimer;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _startDaemon();
    await Future.delayed(const Duration(milliseconds: 400));
    _connectSocket();
  }

  static Future<void> _startDaemon() async {
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidates = [
        '$exeDir/lib/scripts/emoji_prediction_daemon.py',
        '${Directory.current.path}/lib/scripts/emoji_prediction_daemon.py',
        '/home/uninterested_k/.local/share/omoji/lib/scripts/emoji_prediction_daemon.py',
        '/home/uninterested_k/Documents/Omoji/lib/scripts/emoji_prediction_daemon.py',
        '/usr/lib/omoji/lib/scripts/emoji_prediction_daemon.py',
      ];
      for (final path in candidates) {
        if (await File(path).exists()) {
          _daemonProcess = await Process.start(
            'python3',
            [path],
            mode: ProcessStartMode.detached,
          );
          break;
        }
      }
    } catch (e) {
      debugPrint('Failed to start emoji prediction daemon: $e');
    }
  }

  static void _connectSocket() async {
    _reconnectTimer?.cancel();
    try {
      _socket = await Socket.connect('127.0.0.1', 18942, timeout: const Duration(seconds: 2));
      utf8.decoder.bind(_socket!).transform(const LineSplitter()).listen(
        (line) {
          try {
            final data = jsonDecode(line) as Map<String, dynamic>;
            final type = data['type'] as String? ?? 'clear';

            if (type == 'prediction') {
              final word = data['word'] as String? ?? '';
              final rawPreds = data['predictions'] as List<dynamic>? ?? [];
              final predictions = rawPreds.map((p) => {
                'char': (p['char'] as String? ?? ''),
                'name': (p['name'] as String? ?? ''),
              }).toList();
              final posX = data['x'] as int?;
              final posY = data['y'] as int?;

              currentEvent.value = PredictionEvent(
                type: 'prediction',
                word: word,
                predictions: predictions,
                x: posX,
                y: posY,
              );
            } else if (type == 'autofill') {
              final emoji = data['emoji'] as String? ?? '';
              final word = data['word'] as String? ?? '';
              currentEvent.value = PredictionEvent(
                type: 'autofill',
                word: word,
                emoji: emoji,
              );
            } else {
              currentEvent.value = PredictionEvent(type: 'clear');
            }
          } catch (e) {
            debugPrint('Error parsing prediction payload: $e');
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  static void _scheduleReconnect() {
    _socket?.destroy();
    _socket = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _connectSocket();
    });
  }

  static void requestAutofillBackspaces(int count) {
    if (_socket != null && count > 0) {
      try {
        _socket!.writeln(jsonEncode({'type': 'backspace', 'count': count}));
      } catch (e) {
        debugPrint('Failed to send backspace request: $e');
      }
    }
  }

  static void dispose() {
    _reconnectTimer?.cancel();
    _socket?.destroy();
    _socket = null;
    try {
      _daemonProcess?.kill();
    } catch (_) {}
    _daemonProcess = null;
  }
}

// lib/services/audio_ducking_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:omoji/services/logger_service.dart';

class AudioDuckingService {
  static bool _isDucked = false;
  static Map<int, String> _previousSinkInputVolumes = {};

  static Future<void> duckAudio({bool enabled = true}) async {
    if (!enabled || _isDucked || !Platform.isLinux) return;

    try {
      LoggerService.info('Initiating audio ducking...');
      final result = await Process.run('pactl', ['list', 'sink-inputs']);
      if (result.exitCode != 0) {
        LoggerService.warn('pactl command failed with exit code ${result.exitCode}');
        return;
      }

      final output = result.stdout as String;
      final sinkInputBlocks = output.split(RegExp(r'Sink Input #'));
      _previousSinkInputVolumes.clear();

      for (var block in sinkInputBlocks) {
        if (block.trim().isEmpty) continue;

        final lines = block.split('\n');
        final idMatch = RegExp(r'^(\d+)').firstMatch(lines.first.trim());
        if (idMatch == null) continue;

        final sinkInputId = int.parse(idMatch.group(1)!);

        // Check application name to avoid ducking Omoji itself
        final isOmoji = block.contains('omoji') || block.contains('pw-play') || block.contains('canberra');
        if (isOmoji) continue;

        // Find volume percentage string
        final volumeMatch = RegExp(r'Volume:.*?\s(\d+%)').firstMatch(block);
        if (volumeMatch != null) {
          final originalVol = volumeMatch.group(1)!;
          _previousSinkInputVolumes[sinkInputId] = originalVol;

          // Duck stream volume down to 15%
          await Process.run('pactl', ['set-sink-input-volume', '$sinkInputId', '15%']);
          LoggerService.info('Ducked sink-input #$sinkInputId from $originalVol to 15%');
        }
      }

      _isDucked = true;
    } catch (e, stack) {
      LoggerService.error('Failed to duck audio', e, stack);
    }
  }

  static Future<void> restoreAudio() async {
    if (!_isDucked || !Platform.isLinux) return;

    try {
      LoggerService.info('Restoring audio ducking volumes...');
      for (var entry in _previousSinkInputVolumes.entries) {
        final id = entry.key;
        final vol = entry.value;
        await Process.run('pactl', ['set-sink-input-volume', '$id', vol]);
        LoggerService.info('Restored sink-input #$id to $vol');
      }

      _previousSinkInputVolumes.clear();
      _isDucked = false;
    } catch (e, stack) {
      LoggerService.error('Failed to restore audio volume', e, stack);
      _isDucked = false;
    }
  }
}

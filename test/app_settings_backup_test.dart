import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omoji/services/app_settings.dart';

void main() {
  group('AppSettings.decodeBackup', () {
    test('accepts a backup containing persisted app data', () {
      final settings = AppSettings.decodeBackup(
        jsonEncode({
          'format': 'omoji-backup',
          'version': 1,
          'settings': {
            'theme': 'dark',
            'secondaryTrigger': 'Ctrl + Alt + O',
            'alarms': [
              {
                'id': 'alarm-1',
                'time': '08:00',
                'repeatDays': [1, 3, 5],
                'autoSilenceMinutes': 5,
              },
            ],
            'todos': [
              {
                'id': 'todo-1',
                'title': 'Review',
                'targetDateTime': '2026-01-01T12:00:00.000',
              },
            ],
            'clipboardHistory': [
              {'text': 'hello', 'isPinned': true, 'timestamp': 100},
            ],
            'timerDurationSeconds': 300,
            'timerRemainingSeconds': 120,
            'stopwatchAccumulatedMs': 4500,
            'stopwatchLaps': ['Lap 1: 00:04.50'],
          },
        }),
      );

      expect(settings['theme'], 'dark');
      expect(settings['alarms'], hasLength(1));
      expect(settings['todos'], hasLength(1));
      expect(settings['clipboardHistory'], hasLength(1));
      expect(settings['stopwatchLaps'], ['Lap 1: 00:04.50']);
    });

    test('rejects unsupported backup formats and versions', () {
      expect(
        () => AppSettings.decodeBackup(
          jsonEncode({'format': 'other', 'version': 1, 'settings': {}}),
        ),
        throwsFormatException,
      );
      expect(
        () => AppSettings.decodeBackup(
          jsonEncode({'format': 'omoji-backup', 'version': 2, 'settings': {}}),
        ),
        throwsFormatException,
      );
    });

    test('rejects invalid persisted timer values before import', () {
      expect(
        () => AppSettings.decodeBackup(
          jsonEncode({
            'format': 'omoji-backup',
            'version': 1,
            'settings': {'timerRemainingSeconds': -1},
          }),
        ),
        throwsFormatException,
      );
    });
  });
}

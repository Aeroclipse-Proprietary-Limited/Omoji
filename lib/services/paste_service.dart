import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:omoji/services/logger_service.dart';

class PasteService {
  static Future<bool> setClipboard(String text) async {
    final payloadLength = text.runes.length;
    await LoggerService.info(
      'PasteService: setClipboard initiated (payloadLength: $payloadLength, isWayland: $_isWayland)',
    );
    try {
      if (_isWayland) {
        await Clipboard.setData(ClipboardData(text: text));

        final copyProcess = await Process.start('wl-copy', [
          '--type',
          'text/plain;charset=utf-8',
          '--',
          text,
        ]);
        final stderr = StringBuffer();
        final stdoutSubscription = copyProcess.stdout.listen((_) {});
        final stderrSubscription = copyProcess.stderr
            .transform(utf8.decoder)
            .listen(stderr.write);
        late final int copyExitCode;
        try {
          copyExitCode = await copyProcess.exitCode.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              copyProcess.kill();
              throw TimeoutException('wl-copy did not start in time.');
            },
          );
        } finally {
          await stdoutSubscription.cancel();
          await stderrSubscription.cancel();
        }

        if (copyExitCode != 0) {
          final errorMessage = stderr.toString().trim();
          await LoggerService.warn(
            'PasteService: wl-copy exited with code $copyExitCode${errorMessage.isEmpty ? '' : ': $errorMessage'}',
          );
          throw StateError(
            'wl-copy exited with code $copyExitCode'
            '${errorMessage.isEmpty ? '' : ': $errorMessage'}',
          );
        }

        final verifyResult = await Process.run('wl-paste', [
          '--no-newline',
        ]).timeout(const Duration(seconds: 2));
        if (verifyResult.exitCode != 0) {
          final errorMessage = (verifyResult.stderr as String).trim();
          await LoggerService.warn(
            'PasteService: wl-paste verification exited with code ${verifyResult.exitCode}${errorMessage.isEmpty ? '' : ': $errorMessage'}',
          );
          throw StateError(
            'wl-paste exited with code ${verifyResult.exitCode}'
            '${errorMessage.isEmpty ? '' : ': $errorMessage'}',
          );
        }
        if (verifyResult.stdout != text) {
          await LoggerService.warn(
            'PasteService: Clipboard read-back mismatch (expectedLength: ${text.runes.length}, receivedLength: ${(verifyResult.stdout as String).runes.length})',
          );
          throw StateError(
            'Clipboard read-back did not match the selected text '
            '(expected ${text.runes.length} characters, '
            'received ${(verifyResult.stdout as String).runes.length}).',
          );
        }
        await LoggerService.info(
          'PasteService: Wayland clipboard set and verified successfully.',
        );
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        await LoggerService.info(
          'PasteService: Standard clipboard set successfully.',
        );
      }

      return true;
    } catch (error, stackTrace) {
      await LoggerService.error(
        'PasteService: Clipboard update failed',
        error,
        stackTrace,
      );
      return false;
    }
  }

  static Future<bool> pasteText(String text, {required bool enabled}) async {
    final payloadLength = text.runes.length;
    await LoggerService.info(
      'PasteService: pasteText initiated (enabled: $enabled, payloadLength: $payloadLength, platform: ${Platform.operatingSystem}, isWayland: $_isWayland)',
    );

    if (!enabled) {
      await LoggerService.info(
        'PasteService: Auto-paste skipped because it is disabled.',
      );
      return true;
    }

    bool success = false;
    if (Platform.isLinux) {
      success = await _pasteOnLinux(text);
    } else if (Platform.isMacOS) {
      success = await _runPasteTool('macOS paste (osascript)', 'osascript', [
        '-e',
        'tell application "System Events" to keystroke "v" using command down',
      ]);
    } else if (Platform.isWindows) {
      success = await _runPasteTool('Windows paste (powershell)', 'powershell', [
        '-c',
        "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('^v')",
      ]);
    }

    if (success) {
      await LoggerService.info(
        'PasteService: pasteText completed successfully.',
      );
    } else {
      await LoggerService.warn(
        'PasteService: pasteText failed to inject text via any available method.',
      );
    }
    return success;
  }

  static bool get _isWayland =>
      Platform.isLinux &&
      (Platform.environment['WAYLAND_DISPLAY']?.isNotEmpty == true ||
          Platform.environment['XDG_SESSION_TYPE'] == 'wayland');

  static Future<bool> _pasteOnLinux(String text) async {
    await LoggerService.info('PasteService: _pasteOnLinux started.');
    try {
      final executableDirectory = File(Platform.resolvedExecutable).parent.path;
      final home = Platform.environment['HOME'] ?? '';
      final scriptLocations = <String>[
        '$executableDirectory/lib/scripts/omoji_paste.py',
        '$home/.local/lib/omoji/lib/scripts/omoji_paste.py',
        'scripts/omoji_paste.py',
      ];
      for (final location in scriptLocations) {
        if (!File(location).existsSync()) {
          await LoggerService.info(
            'PasteService: omoji_paste.py not found at $location',
          );
          continue;
        }
        await LoggerService.info(
          'PasteService: Attempting omoji_paste.py at $location',
        );
        final result = await Process.run('python3', [
          location,
          text,
        ]).timeout(const Duration(seconds: 2));
        if (result.exitCode == 0) {
          await LoggerService.info(
            'PasteService: Auto-paste command succeeded: omoji_paste.py ($location)',
          );
          return true;
        }
        await LoggerService.warn(
          'PasteService: Auto-paste command failed: omoji_paste.py ($location) exited '
                  '${result.exitCode}: ${result.stderr}'
              .trim(),
        );
      }
    } on TimeoutException {
      await LoggerService.warn(
        'PasteService: Auto-paste command timed out: omoji_paste.py',
      );
    } on ProcessException catch (error) {
      await LoggerService.warn(
        'PasteService: Could not start omoji_paste.py: $error',
      );
    } catch (error, stackTrace) {
      await LoggerService.error(
        'PasteService: omoji_paste.py failed',
        error,
        stackTrace,
      );
    }

    final pasteCommands = _isWayland
        ? <(String, String, List<String>)>[
            ('ydotool', 'ydotool', ['key', 'ctrl+v']),
            ('wtype', 'wtype', ['-M', 'ctrl', '-k', 'v', '-m', 'ctrl']),
          ]
        : <(String, String, List<String>)>[
            ('xdotool', 'xdotool', ['key', '--clearmodifiers', 'ctrl+v']),
            ('wtype', 'wtype', ['-M', 'ctrl', '-k', 'v', '-m', 'ctrl']),
            ('ydotool', 'ydotool', ['key', 'ctrl+v']),
          ];

    for (final (label, executable, arguments) in pasteCommands) {
      if (await _runPasteTool(label, executable, arguments)) return true;
    }

    if (await _runPasteTool('wtype text fallback', 'wtype', ['--', text])) {
      return true;
    }
    if (!_isWayland &&
        await _runPasteTool('xdotool text fallback', 'xdotool', [
          'type',
          '--clearmodifiers',
          text,
        ])) {
      return true;
    }

    if (await _runPasteTool('ydotool', 'ydotool', ['key', 'ctrl+v'])) {
      return true;
    }

    await LoggerService.error(
      'PasteService: Auto-paste failed on Linux: no available input method could send the selection. '
      'The selected text remains on the clipboard.',
    );
    return false;
  }

  static Future<bool> _runPasteTool(
    String label,
    String executable,
    List<String> arguments,
  ) async {
    await LoggerService.info(
      'PasteService: attempting tool: $label ($executable)',
    );
    try {
      final result = await Process.run(
        executable,
        arguments,
      ).timeout(const Duration(seconds: 2));
      if (result.exitCode == 0) {
        await LoggerService.info(
          'PasteService: Auto-paste command succeeded: $label',
        );
        return true;
      }
      await LoggerService.warn(
        'PasteService: Auto-paste command failed: $label exited ${result.exitCode}: '
                '${result.stderr}'
            .trim(),
      );
    } on ProcessException {
      await LoggerService.warn(
        'PasteService: Auto-paste command unavailable: $label is not installed or could not be started.',
      );
    } on TimeoutException {
      await LoggerService.warn(
        'PasteService: Auto-paste command timed out: $label',
      );
    } catch (error, stackTrace) {
      await LoggerService.error(
        'PasteService: Auto-paste command failed: $label',
        error,
        stackTrace,
      );
    }
    return false;
  }
}

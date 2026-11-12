import 'dart:io';

import 'package:flutter/material.dart';

class HotkeyService {
  static const _settingsSchema = 'org.gnome.settings-daemon.plugins.media-keys';
  static const _bindingSchema =
      'org.gnome.settings-daemon.plugins.media-keys.custom-keybinding';
  static const _primaryPath =
      '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/omoji-primary/';
  static const _secondaryPath =
      '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/omoji-secondary/';

  static Future<bool> registerTriggers({
    required String primaryTrigger,
    required String secondaryTrigger,
  }) async {
    if (!Platform.isLinux) return true;

    try {
      final primary = _convertToGsettingsFormat(primaryTrigger);
      final secondary = _convertToGsettingsFormat(secondaryTrigger);
      if (primary == null || secondary == null) {
        debugPrint('Ignored invalid hotkey binding.');
        return false;
      }

      final home = Platform.environment['HOME'] ?? '';
      final omojiBin = '$home/.local/bin/omoji';
      for (final (path, label, binding) in [
        (_primaryPath, 'Omoji Launcher (Primary)', primary),
        (_secondaryPath, 'Omoji Launcher (Secondary)', secondary),
      ]) {
        await _setBinding(path, 'name', label);
        await _setBinding(path, 'command', omojiBin);
        await _setBinding(path, 'binding', binding);
      }

      final listResult = await Process.run('gsettings', [
        'get',
        _settingsSchema,
        'custom-keybindings',
      ]);
      if (listResult.exitCode != 0) return false;
      final paths = RegExp(r"'([^']+)'")
          .allMatches(listResult.stdout.toString())
          .map((match) => match.group(1)!)
          .toList();
      if (!paths.contains(_primaryPath)) paths.add(_primaryPath);
      if (!paths.contains(_secondaryPath)) paths.add(_secondaryPath);
      final encodedPaths = '[${paths.map((path) => "'$path'").join(', ')}]';
      final update = await Process.run('gsettings', [
        'set',
        _settingsSchema,
        'custom-keybindings',
        encodedPaths,
      ]);
      return update.exitCode == 0;
    } catch (error) {
      debugPrint('Failed to register system hotkeys: $error');
      return false;
    }
  }

  static Future<void> _setBinding(String path, String key, String value) async {
    final result = await Process.run('gsettings', [
      'set',
      '$_bindingSchema:$path',
      key,
      value,
    ]);
    if (result.exitCode != 0) {
      throw ProcessException('gsettings', [
        'set',
        key,
      ], result.stderr.toString());
    }
  }

  static String? _convertToGsettingsFormat(String input) {
    final parts = input.trim().split(RegExp(r'\s*\+\s*'));
    if (parts.isEmpty || parts.any((part) => part.isEmpty)) return null;
    final modifiers = <String>[];
    String? key;
    for (final rawPart in parts) {
      final part = rawPart.toLowerCase();
      final modifier = switch (part) {
        'super' || 'cmd' || 'meta' => '<Super>',
        'ctrl' || 'control' => '<Primary>',
        'alt' || 'option' => '<Alt>',
        'shift' => '<Shift>',
        _ => null,
      };
      if (modifier != null) {
        if (key != null || modifiers.contains(modifier)) return null;
        modifiers.add(modifier);
        continue;
      }
      if (key != null) return null;
      key = switch (part) {
        '.' => 'period',
        ',' => 'comma',
        '/' => 'slash',
        '-' => 'minus',
        'space' => 'space',
        _ when RegExp(r'^[a-z0-9]$').hasMatch(part) => part,
        _ => null,
      };
      if (key == null) return null;
    }
    if (key == null) return null;
    return '${modifiers.join()}$key';
  }
}

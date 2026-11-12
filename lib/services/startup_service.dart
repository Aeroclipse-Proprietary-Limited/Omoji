import 'dart:io';

/// Manages Omoji's per-user login startup entry.
class StartupService {
  StartupService._();

  static Future<void> setEnabled(bool enabled) async {
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return;
      final snapUserData = Platform.environment['SNAP_USER_DATA'];
      final configHome = Platform.environment['XDG_CONFIG_HOME'];
      final configDirectory = snapUserData != null && snapUserData.isNotEmpty
          ? '$snapUserData/.config'
          : configHome == null || configHome.isEmpty
          ? '$home/.config'
          : configHome;
      final autostartDirectory = Directory('$configDirectory/autostart');
      final entry = File('${autostartDirectory.path}/omoji.desktop');
      if (!enabled) {
        if (await entry.exists()) await entry.delete();
        return;
      }
      await autostartDirectory.create(recursive: true);
      final executable = Platform.environment.containsKey('SNAP')
          ? 'omoji'
          : Platform.resolvedExecutable;
      final desktopExec = executable == 'omoji'
          ? executable
          : '"${executable.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
      await entry.writeAsString('''
[Desktop Entry]
Type=Application
Name=Omoji
Comment=Start Omoji when I log in
Exec=$desktopExec --background
X-GNOME-Autostart-enabled=true
''');
      return;
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) return;
      final agentsDirectory = Directory('$home/Library/LaunchAgents');
      final entry = File('${agentsDirectory.path}/com.aeroclipse.omoji.plist');
      if (!enabled) {
        if (await entry.exists()) await entry.delete();
        return;
      }
      await agentsDirectory.create(recursive: true);
      final executable = _xmlEscape(Platform.resolvedExecutable);
      await entry.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.aeroclipse.omoji</string>
  <key>ProgramArguments</key>
  <array><string>$executable</string><string>--background</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
''');
      return;
    }

    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData == null || appData.isEmpty) return;
      final startupDirectory = Directory(
        '$appData/Microsoft/Windows/Start Menu/Programs/Startup',
      );
      final entry = File('${startupDirectory.path}/Omoji.cmd');
      if (!enabled) {
        if (await entry.exists()) await entry.delete();
        return;
      }
      await startupDirectory.create(recursive: true);
      final executable = Platform.resolvedExecutable.replaceAll('"', '""');
      await entry.writeAsString(
        '@echo off\r\nstart "" "$executable" --background\r\n',
      );
    }
  }

  static String _xmlEscape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

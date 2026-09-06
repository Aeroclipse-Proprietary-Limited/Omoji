// lib/main.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omoji/screens/home_screen.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/services/stopwatch_service.dart';
import 'package:omoji/services/timer_service.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(const Color(0xFF009688));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Single Instance Guard: ensure only 1 window of Omoji runs
  try {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 49876);
    server.listen((Socket client) {
      client.listen((data) async {
        final message = String.fromCharCodes(data).trim();
        if (message == 'SHOW_WINDOW') {
          try {
            const MethodChannel('com.aeroclipse.omoji/window').invokeMethod('setAcceptFocus', true);
          } catch (_) {}
          if (await windowManager.isMinimized()) {
            await windowManager.restore();
          }
          await windowManager.setOpacity(1.0);
          await windowManager.setSize(const Size(420, 540));
          await windowManager.setSkipTaskbar(false);
          await windowManager.center();
          await windowManager.show();
          await windowManager.focus();
        }
      });
    });
  } catch (_) {
    try {
      final client = await Socket.connect(InternetAddress.loopbackIPv4, 49876);
      client.write('SHOW_WINDOW');
      await client.flush();
      client.destroy();
    } catch (_) {}
    exit(0);
  }

  await windowManager.ensureInitialized();

  final settings = await AppSettings.loadSettings();
  await TimerService.init();
  await StopwatchService.init();

  ThemeMode initialTheme = ThemeMode.dark;
  final themeName = settings['theme'] as String?;
  if (themeName == 'light') initialTheme = ThemeMode.light;
  if (themeName == 'system') initialTheme = ThemeMode.system;

  themeNotifier.value = initialTheme;

  final accentVal = settings['accentColor'] as int?;
  if (accentVal != null) {
    accentColorNotifier.value = Color(accentVal);
  }

  const windowOptions = WindowOptions(
    size: Size(420, 540),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    try {
      await windowManager.setIcon('lib/assets/imgs/app-logo.png');
    } catch (_) {}
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const OmojiApp());
}

class OmojiApp extends StatelessWidget {
  const OmojiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentTheme, child) {
        return ValueListenableBuilder<Color>(
          valueListenable: accentColorNotifier,
          builder: (context, accentColor, child) {
            return MaterialApp(
              title: 'Omoji',
              debugShowCheckedModeBanner: false,
              themeMode: currentTheme,
              theme: ThemeData.light().copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: accentColor,
                  brightness: Brightness.light,
                ),
                scaffoldBackgroundColor: Colors.transparent,
              ),
              darkTheme: ThemeData.dark().copyWith(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: accentColor,
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: Colors.transparent,
              ),
              home: const OmojiHomeScreen(),
            );
          },
        );
      },
    );
  }
}
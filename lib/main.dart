// lib/main.dart

import 'package:flutter/material.dart';
import 'package:omoji/screens/home_screen.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final settings = await AppSettings.loadSettings();

  ThemeMode initialTheme = ThemeMode.dark;
  final themeName = settings['theme'] as String?;
  if (themeName == 'light') initialTheme = ThemeMode.light;
  if (themeName == 'system') initialTheme = ThemeMode.system;

  themeNotifier.value = initialTheme;

  const windowOptions = WindowOptions(
    size: Size(380, 520),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
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
        return MaterialApp(
          title: 'Omoji',
          debugShowCheckedModeBanner: false,
          themeMode: currentTheme,
          theme: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.transparent,
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.transparent,
          ),
          home: const OmojiHomeScreen(),
        );
      },
    );
  }
}
// lib/main.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omoji/screens/home_screen.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/services/startup_service.dart';
import 'package:omoji/services/stopwatch_service.dart';
import 'package:omoji/services/timer_service.dart';
import 'package:omoji/services/update_check_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:omoji/services/tray_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
final ValueNotifier<Color> accentColorNotifier = ValueNotifier(
  const Color(0xFFB91C1C),
);
final ValueNotifier<double> accentBackgroundIntensityNotifier = ValueNotifier(
  0.0,
);
final ValueNotifier<String> dateFormatNotifier = ValueNotifier('dd/mm/yyyy');
final ValueNotifier<String> todoDefaultViewNotifier = ValueNotifier('upcoming');
final ValueNotifier<void> omojiSummonedNotifier = ValueNotifier(null);
final ValueNotifier<int> trayPrivateModeRequestNotifier = ValueNotifier(0);
final ValueNotifier<int> trayChatRequestNotifier = ValueNotifier(0);
final ValueNotifier<bool> trayPrivateModeNotifier = ValueNotifier(false);
final ValueNotifier<bool> traySuperAgentsNotifier = ValueNotifier(false);
bool _startInBackground = false;

Future<void> showOmojiWindow() async {
  try {
    const MethodChannel('com.aeroclipse.omoji/window')
        .invokeMethod('setAcceptFocus', true);
  } catch (_) {}
  if (await windowManager.isMinimized()) await windowManager.restore();
  await windowManager.setOpacity(1.0);
  await windowManager.setSize(const Size(460, 600));
  await windowManager.setSkipTaskbar(false);
  await windowManager.center();
  await windowManager.show();
  await windowManager.focus();
  omojiSummonedNotifier.value = null;
}

Color applyAccentBackgroundEffect(Color background) {
  final intensity = accentBackgroundIntensityNotifier.value;
  if (intensity <= 0) return background;
  final tint = accentColorNotifier.value.withValues(alpha: background.a);
  return Color.lerp(background, tint, intensity)!;
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  _startInBackground = args.contains('--background');

  // Single Instance Guard: ensure only 1 window of Omoji runs
  try {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 49876);
    server.listen((Socket client) {
      client.listen((data) async {
        final message = String.fromCharCodes(data).trim();
        if (message == 'SHOW_WINDOW') showOmojiWindow();
      });
    });
  } catch (_) {
    try {
      final client = await Socket.connect(InternetAddress.loopbackIPv4, 49876);
      client.write(_startInBackground ? 'BACKGROUND_INSTANCE' : 'SHOW_WINDOW');
      await client.flush();
      client.destroy();
    } catch (_) {}
    exit(0);
  }

  await windowManager.ensureInitialized();

  final settings = await AppSettings.loadSettings();
  AppSettings.animationsEnabledNotifier.value =
      settings['animationsEnabled'] as bool? ?? true;
  trayPrivateModeNotifier.value = settings['privateMode'] as bool? ?? false;
  traySuperAgentsNotifier.value =
      settings['superAgentsEnabled'] as bool? ?? false;
  try {
    await StartupService.setEnabled(settings['runAtLogin'] as bool? ?? true);
  } catch (error) {
    debugPrint('Could not update login startup: $error');
  }
  await TimerService.init();
  await StopwatchService.init();

  ThemeMode initialTheme = ThemeMode.system;
  final themeName = settings['theme'] as String?;
  if (themeName == 'light') initialTheme = ThemeMode.light;
  if (themeName == 'dark') initialTheme = ThemeMode.dark;
  if (themeName == 'system') initialTheme = ThemeMode.system;

  themeNotifier.value = initialTheme;

  final accentVal = settings['accentColor'] as int?;
  if (accentVal != null) {
    accentColorNotifier.value = Color(accentVal);
  }
  accentBackgroundIntensityNotifier.value =
      (settings['accentBackgroundIntensity'] as num?)?.toDouble() ??
      ((settings['accentBackgroundEffects'] as bool? ?? false) ? 0.35 : 0.0);

  final dateFormatVal = settings['dateFormat'] as String?;
  if (dateFormatVal != null && dateFormatVal.isNotEmpty) {
    dateFormatNotifier.value = dateFormatVal;
  }

  final todoDefaultViewVal = settings['todoDefaultView'] as String?;
  const validTodoViews = {'all', 'upcoming', 'missed', 'delayed', 'completed'};
  if (todoDefaultViewVal != null &&
      validTodoViews.contains(todoDefaultViewVal)) {
    todoDefaultViewNotifier.value = todoDefaultViewVal;
  }

  const windowOptions = WindowOptions(
    size: Size(460, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    try {
      await windowManager.setIcon('lib/assets/imgs/App logo (dark).png');
    } catch (_) {}
    await windowManager.setPreventClose(true);
    if (_startInBackground) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  });

  runApp(const OmojiApp());
  unawaited(UpdateCheckService.checkIfDue());
}

class OmojiApp extends StatefulWidget {
  const OmojiApp({super.key});

  @override
  State<OmojiApp> createState() => _OmojiAppState();
}

class _OmojiAppState extends State<OmojiApp> {
  @override
  void initState() {
    super.initState();
    TrayService.initialize(
      onShow: showOmojiWindow,
      onPrivateMode: () => trayPrivateModeRequestNotifier.value++,
      onChat: () => trayChatRequestNotifier.value++,
      onExit: () async {
        await TrayService.dispose();
        exit(0);
      },
      privateModeEnabled: trayPrivateModeNotifier.value,
      superAgentsEnabled: traySuperAgentsNotifier.value,
    );
    trayPrivateModeNotifier.addListener(_updateTrayPrivateMode);
    traySuperAgentsNotifier.addListener(_updateTraySuperAgents);
  }

  void _updateTrayPrivateMode() =>
      TrayService.updatePrivateMode(trayPrivateModeNotifier.value);
  void _updateTraySuperAgents() =>
      TrayService.updateSuperAgents(traySuperAgentsNotifier.value);

  @override
  void dispose() {
    trayPrivateModeNotifier.removeListener(_updateTrayPrivateMode);
    traySuperAgentsNotifier.removeListener(_updateTraySuperAgents);
    TrayService.dispose();
    super.dispose();
  }

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

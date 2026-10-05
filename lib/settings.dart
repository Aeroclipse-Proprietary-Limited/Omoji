import 'dart:io';
import 'dart:ui'; // Required for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omoji/main.dart';
import 'package:omoji/services/alarm_service.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/services/hotkey_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showCardForm = false;
  bool _showCryptoAddress = false;
  String? _customAlarmSoundPath;
  bool _isPlayingTest = false;
  bool _autoPaste = true;
  bool _ignoreEmojisInClipboard = true;
  bool _enableEmojiPredictions = true;
  bool _useSystemDefaultSound = true;
  int _audioLoopIntervalSeconds = 10;

  late TextEditingController _primaryTriggerController;
  late TextEditingController _secondaryTriggerController;
  bool _isRegisteringHotkeys = false;

  @override
  void initState() {
    super.initState();
    _primaryTriggerController = TextEditingController(text: 'Super + .');
    _secondaryTriggerController = TextEditingController(text: 'Ctrl + Alt + O');
    _loadSettings();
  }

  @override
  void dispose() {
    _primaryTriggerController.dispose();
    _secondaryTriggerController.dispose();
    AlarmService.killAudioProcess();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await AppSettings.loadSettings();
    setState(() {
      _customAlarmSoundPath = settings['customAlarmSoundPath'] as String?;
      final savedUseSystemDefault = settings['useSystemDefaultSound'] as bool?;
      if (savedUseSystemDefault != null) {
        _useSystemDefaultSound = savedUseSystemDefault;
      } else {
        _useSystemDefaultSound = (_customAlarmSoundPath == null || _customAlarmSoundPath!.isEmpty);
      }
      _audioLoopIntervalSeconds = (settings['audioLoopIntervalSeconds'] as int?) ?? 10;
      _autoPaste = settings['autoPaste'] as bool? ?? true;
      _ignoreEmojisInClipboard = settings['ignoreEmojisInClipboard'] as bool? ?? true;
      _enableEmojiPredictions = settings['enableEmojiPredictions'] as bool? ?? true;
      _primaryTriggerController.text = Platform.isWindows ? 'Super + Z' : 'Super + X';
      _secondaryTriggerController.text = (settings['secondaryTrigger'] as String?) ?? 'Ctrl + Alt + O';
    });
  }

  String _formatIntervalLabel(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '${mins}m';
    return '${mins}m ${secs}s';
  }

  Future<void> _pickCustomSound() async {
    if (Platform.isLinux) {
      try {
        final result = await Process.run('zenity', [
          '--file-selection',
          '--title=Select Custom Alarm Sound MP3',
          '--file-filter=Audio files (*.mp3 *.wav *.ogg) | *.mp3 *.wav *.ogg *.MP3 *.WAV *.OGG',
        ]);
        // This is life!
        if (result.exitCode == 0) {
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty) {
            setState(() {
              _customAlarmSoundPath = path;
              _useSystemDefaultSound = false;
            });
            await AppSettings.saveSettings(
              customAlarmSoundPath: path,
              useSystemDefaultSound: false,
            );
            AlarmService.updateAudioConfig(
              useSystemDefault: false,
              customPath: path,
            );
          }
        }
      } catch (e) {
        debugPrint('Failed to run zenity file picker: $e');
      }
    }
  }

  Future<void> _openFeedbackEmail() async {
    const mailtoUrl = 'mailto:godlyttn@outlook.com?subject=Feedback%20on%20omoji';
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [mailtoUrl]);
      } catch (_) {
        try {
          await Process.run('xdg-email', ['mailto:godlyttn@outlook.com', '--subject', 'Feedback on omoji']);
        } catch (_) {}
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', [mailtoUrl]);
      } catch (_) {}
    } else if (Platform.isWindows) {
      try {
        await Process.run('cmd', ['/c', 'start', '', mailtoUrl]);
      } catch (_) {}
    }
  }

  Future<void> _saveAndGoBack(BuildContext context) async {
    if (_isRegisteringHotkeys) return;
    setState(() => _isRegisteringHotkeys = true);

    final primary = Platform.isWindows ? 'Super + Z' : 'Super + X';
    final secondary = _secondaryTriggerController.text.trim();

    await AppSettings.saveSettings(
      primaryTrigger: primary,
      secondaryTrigger: secondary,
    );

    await HotkeyService.registerTriggers(
      primaryTrigger: primary,
      secondaryTrigger: secondary,
    );

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.6);
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveAndGoBack(context);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF2E2E2E).withValues(alpha: 0.65),
                          const Color(0xFF1A1A1A).withValues(alpha: 0.45),
                          const Color(0xFF121212).withValues(alpha: 0.75),
                        ]
                      : [
                          const Color(0xFFFFFFFF).withValues(alpha: 0.65),
                          const Color(0xFFE0E0E0).withValues(alpha: 0.45),
                          const Color(0xFFF5F5F5).withValues(alpha: 0.75),
                        ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          IconButton(
                            icon: _isRegisteringHotkeys
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
                                  )
                                : const Icon(Icons.arrow_back_ios_new_rounded),
                            color: textColor,
                            splashRadius: 20,
                            onPressed: () => _saveAndGoBack(context),
                          ),
                          const SizedBox(width: 8),
                        Text(
                          'Settings',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'v1.2.3',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Section: Theme
                    Text(
                      'App Theme',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, currentTheme, _) {
                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorderColor),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildThemeOption(
                                  context: context,
                                  label: 'Dark',
                                  icon: Icons.dark_mode_rounded,
                                  isActive: currentTheme == ThemeMode.dark,
                                  onTap: () async {
                                    themeNotifier.value = ThemeMode.dark;
                                    await AppSettings.saveSettings(theme: ThemeMode.dark);
                                  },
                                ),
                              ),
                              Expanded(
                                child: _buildThemeOption(
                                  context: context,
                                  label: 'Light',
                                  icon: Icons.light_mode_rounded,
                                  isActive: currentTheme == ThemeMode.light,
                                  onTap: () async {
                                    themeNotifier.value = ThemeMode.light;
                                    await AppSettings.saveSettings(theme: ThemeMode.light);
                                  },
                                ),
                              ),
                              Expanded(
                                child: _buildThemeOption(
                                  context: context,
                                  label: 'System',
                                  icon: Icons.settings_brightness_rounded,
                                  isActive: currentTheme == ThemeMode.system,
                                  onTap: () async {
                                    themeNotifier.value = ThemeMode.system;
                                    await AppSettings.saveSettings(theme: ThemeMode.system);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),

                    // Section: Accent Color
                    Text(
                      'Accent Color',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<Color>(
                      valueListenable: accentColorNotifier,
                      builder: (context, currentAccent, _) {
                        const accentColors = [
                          Color(0xFFB91C1C), // Blood Red (Default)
                          Color(0xFF10B981), // Emerald Green
                          Color(0xFF8B5CF6), // Purple
                          Color(0xFF2563EB), // Sapphire
                          Color(0xFFD97706), // Gold
                        ];
                        const accentLabels = [
                          'Blood Red (Default)',
                          'Emerald Green',
                          'Purple',
                          'Sapphire',
                          'Gold',
                        ];

                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorderColor),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(accentColors.length, (idx) {
                              final color = accentColors[idx];
                              final isSelected = currentAccent == color;

                              return Tooltip(
                                message: accentLabels[idx],
                                child: GestureDetector(
                                  onTap: () async {
                                    accentColorNotifier.value = color;
                                    await AppSettings.saveSettings(accentColorValue: color.toARGB32());
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withValues(alpha: isSelected ? 0.6 : 0.25),
                                          blurRadius: isSelected ? 10 : 4,
                                          spreadRadius: isSelected ? 2 : 0,
                                        ),
                                      ],
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                                        : null,
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section: Date Display Format
                    Text(
                      'Date Display Format',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<String>(
                      valueListenable: dateFormatNotifier,
                      builder: (context, currentFormat, _) {
                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorderColor),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildThemeOption(
                                  context: context,
                                  label: 'dd/mm/yyyy',
                                  icon: Icons.calendar_today_rounded,
                                  isActive: currentFormat == 'dd/mm/yyyy',
                                  onTap: () async {
                                    dateFormatNotifier.value = 'dd/mm/yyyy';
                                    await AppSettings.saveSettings(dateFormat: 'dd/mm/yyyy');
                                  },
                                ),
                              ),
                              Expanded(
                                child: _buildThemeOption(
                                  context: context,
                                  label: 'yyyy/mm/dd',
                                  icon: Icons.event_rounded,
                                  isActive: currentFormat == 'yyyy/mm/dd',
                                  onTap: () async {
                                    dateFormatNotifier.value = 'yyyy/mm/dd';
                                    await AppSettings.saveSettings(dateFormat: 'yyyy/mm/dd');
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section: To-Do Default View
                    Text(
                      'To-Do Default View',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ValueListenableBuilder<String>(
                      valueListenable: todoDefaultViewNotifier,
                      builder: (context, currentView, _) {
                        final views = [
                          ('all',       'All',      Icons.list_rounded),
                          ('upcoming',  'Upcoming', Icons.upcoming_rounded),
                          ('missed',    'Missed',   Icons.alarm_off_rounded),
                          ('completed', 'Done',     Icons.check_circle_outline_rounded),
                        ];
                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorderColor),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Row(
                            children: views.map((v) {
                              final isActive = currentView == v.$1;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    todoDefaultViewNotifier.value = v.$1;
                                    await AppSettings.saveSettings(todoDefaultView: v.$1);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          v.$3,
                                          size: 16,
                                          color: isActive
                                              ? Colors.white
                                              : subtitleColor,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          v.$2,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isActive
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: isActive
                                                ? Colors.white
                                                : subtitleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Section: Launch Triggers (Primary & Secondary)
                    Text(
                      'App Launch Triggers (Primary & Secondary)',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.keyboard_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Configure primary and secondary system hotkeys to open Omoji from anywhere',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Primary Trigger (Fixed per Platform)
                          Text(
                            'Primary Trigger (Fixed System Default)',
                            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cardBorderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt_rounded, color: Theme.of(context).colorScheme.primary, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  Platform.isWindows ? 'Super + Z' : 'Super + X',
                                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Primary Default',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Secondary Trigger Input
                          Text(
                            'Secondary Trigger',
                            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _secondaryTriggerController,
                                  style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Ctrl + Alt + O',
                                    prefixIcon: Icon(Icons.bolt_outlined, color: Theme.of(context).colorScheme.primary, size: 18),
                                    isDense: true,
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.fiber_manual_record_rounded, size: 14, color: Colors.redAccent),
                                label: const Text('Record Key', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _showRecordKeyDialog(_secondaryTriggerController, 'Secondary Trigger'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section: Auto-Paste
                    Text(
                      'Pasting & Clipboard Behavior',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.paste_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auto-Paste on Click',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Automatically paste selected emoji or clipboard item into active app',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _autoPaste,
                                activeThumbColor: Theme.of(context).colorScheme.primary,
                                onChanged: (val) async {
                                  setState(() {
                                    _autoPaste = val;
                                  });
                                  await AppSettings.saveSettings(autoPaste: val);
                                },
                              ),
                            ],
                          ),
                          Divider(color: cardBorderColor, height: 16),
                          Row(
                            children: [
                              Icon(Icons.do_not_disturb_on_outlined, color: Theme.of(context).colorScheme.primary, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ignore Emojis in Clipboard',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Prevent single emojis from clogging up your clipboard history list',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _ignoreEmojisInClipboard,
                                activeThumbColor: Theme.of(context).colorScheme.primary,
                                onChanged: (val) async {
                                  setState(() {
                                    _ignoreEmojisInClipboard = val;
                                  });
                                  await AppSettings.saveSettings(ignoreEmojisInClipboard: val);
                                },
                              ),
                            ],
                          ),
                          Divider(color: cardBorderColor, height: 16),
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live Emoji Predictions',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Suggest matching emoji as you type (Enter to autofill, Esc to cancel)',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _enableEmojiPredictions,
                                activeThumbColor: Theme.of(context).colorScheme.primary,
                                onChanged: (val) async {
                                  setState(() {
                                    _enableEmojiPredictions = val;
                                  });
                                  await AppSettings.saveSettings(enableEmojiPredictions: val);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section: Alarm Sound & Loop Configuration
                    Text(
                      'Alarm Sound & Loop Interval',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sound Selection Options: System Default vs Custom File
                          Text(
                            'Sound Source',
                            style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          RadioListTile<bool>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Use System Default Sound', style: TextStyle(color: textColor, fontSize: 13)),
                            value: true,
                            groupValue: _useSystemDefaultSound,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (val) async {
                              if (val != null) {
                                setState(() {
                                  _useSystemDefaultSound = val;
                                });
                                await AppSettings.saveSettings(useSystemDefaultSound: val);
                                AlarmService.updateAudioConfig(useSystemDefault: val);
                              }
                            },
                          ),
                          RadioListTile<bool>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Custom Audio File (MP3 / WAV / OGG)', style: TextStyle(color: textColor, fontSize: 13)),
                            value: false,
                            groupValue: _useSystemDefaultSound,
                            activeColor: Theme.of(context).colorScheme.primary,
                            onChanged: (val) async {
                              if (val != null) {
                                setState(() {
                                  _useSystemDefaultSound = val;
                                });
                                await AppSettings.saveSettings(useSystemDefaultSound: val);
                                AlarmService.updateAudioConfig(useSystemDefault: val);
                              }
                            },
                          ),
                          if (!_useSystemDefaultSound) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.music_note_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _customAlarmSoundPath != null
                                        ? _customAlarmSoundPath!.split('/').last
                                        : 'No custom sound chosen',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (_customAlarmSoundPath != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _customAlarmSoundPath!,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () async {
                                    await _pickCustomSound();
                                    await AppSettings.saveSettings(useSystemDefaultSound: false);
                                    AlarmService.updateAudioConfig(useSystemDefault: false);
                                  },
                                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                                  label: const Text('Browse MP3', style: TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _isPlayingTest ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                                    side: BorderSide(
                                      color: _isPlayingTest ? Colors.redAccent : Theme.of(context).colorScheme.primary,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    if (_isPlayingTest) {
                                      AlarmService.killAudioProcess();
                                      setState(() {
                                        _isPlayingTest = false;
                                      });
                                    } else {
                                      setState(() {
                                        _isPlayingTest = true;
                                      });
                                      AlarmService.playAlertSound(customPath: _customAlarmSoundPath);
                                    }
                                  },
                                  icon: Icon(_isPlayingTest ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 16),
                                  label: Text(_isPlayingTest ? 'Stop Sound' : 'Test Sound', style: const TextStyle(fontSize: 12)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                                  color: _customAlarmSoundPath != null ? Colors.orangeAccent : textColor.withValues(alpha: 0.3),
                                  tooltip: 'Reset to Default System Sound',
                                  onPressed: _customAlarmSoundPath == null
                                      ? null
                                      : () async {
                                          setState(() {
                                            _customAlarmSoundPath = null;
                                            _useSystemDefaultSound = true;
                                          });
                                          await AppSettings.saveSettings(clearCustomAlarmSound: true, useSystemDefaultSound: true);
                                          AlarmService.updateAudioConfig(useSystemDefault: true, customPath: null);
                                        },
                                ),
                              ],
                            ),
                          ],
                          Divider(color: cardBorderColor, height: 24),
                          // Loop Interval Section (Range: 10s to 1m 33s / 93s)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Audio Repeat Loop Interval',
                                    style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'How frequently the sound repeats (10s – 1m 33s)',
                                    style: TextStyle(color: subtitleColor, fontSize: 11),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _formatIntervalLabel(_audioLoopIntervalSeconds),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Slider(
                            value: _audioLoopIntervalSeconds.toDouble().clamp(10.0, 93.0),
                            min: 10.0,
                            max: 93.0,
                            divisions: 83,
                            activeColor: Theme.of(context).colorScheme.primary,
                            label: _formatIntervalLabel(_audioLoopIntervalSeconds),
                            onChanged: (val) {
                              setState(() {
                                _audioLoopIntervalSeconds = val.round();
                              });
                            },
                            onChangeEnd: (val) async {
                              final interval = val.round();
                              await AppSettings.saveSettings(audioLoopIntervalSeconds: interval);
                              AlarmService.updateAudioConfig(loopIntervalSeconds: interval);
                            },
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildIntervalChip(10, '10s (Default)'),
                              _buildIntervalChip(15, '15s'),
                              _buildIntervalChip(30, '30s'),
                              _buildIntervalChip(60, '1m (60s)'),
                              _buildIntervalChip(93, '1m 33s (93s)'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section: Developer Information
                    Text(
                      'Developer',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _openFeedbackEmail,
                      borderRadius: BorderRadius.circular(12),
                      splashColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      highlightColor: Colors.transparent,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorderColor),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              backgroundImage: const AssetImage('lib/assets/imgs/acc pic.jpg'),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kevin Manda',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Creator of Omoji',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Aeroclipse Pty Ltd',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section: Donation / Support
                    Text(
                      'Support Development',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorderColor),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.coffee_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'buy me a coffee',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDonationButton(
                                  context: context,
                                  label: 'card',
                                  icon: Icons.credit_card_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  isActive: false,
                                  onTap: () {
                                    setState(() {
                                      _showCardForm = false;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Credit card payments are disabled for security reasons. Please use ETH instead!'),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDonationButton(
                                  context: context,
                                  label: 'eth',
                                  icon: Icons.currency_bitcoin_rounded,
                                  color: Colors.amber[700]!,
                                  isActive: _showCryptoAddress,
                                  onTap: () {
                                    setState(() {
                                      _showCryptoAddress = !_showCryptoAddress;
                                      _showCardForm = false;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_showCryptoAddress) ...[
                            const SizedBox(height: 16),
                            Divider(color: isDark ? Colors.white10 : Colors.black12),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: cardBorderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_rounded, color: Colors.amber[700], size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'ETH Wallet Address',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: textColor.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    '0xfe9dd55429fc5f35f9f363aeaeba256f955b807c',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () {
                                        Clipboard.setData(
                                          const ClipboardData(text: '0xfe9dd55429fc5f35f9f363aeaeba256f955b807c'),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Wallet address copied to clipboard!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.copy_rounded, size: 13, color: Theme.of(context).colorScheme.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Copy Address',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_showCardForm) ...[
                            const SizedBox(height: 20),
                            Divider(color: isDark ? Colors.white10 : Colors.black12),
                            const SizedBox(height: 12),
                            _buildCardForm(context, textColor, cardBg, cardBorderColor),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : textColor,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.15),
          border: Border.all(color: isActive ? color : color.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm(BuildContext context, Color textColor, Color cardBg, Color cardBorderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Card Information',
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Card Number
        _buildTextField(
          context: context,
          hintText: '1234 5678 1234 5678',
          labelText: 'Card Number',
          icon: Icons.credit_card,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        // Expiry & CVV Row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                context: context,
                hintText: 'MM/YY',
                labelText: 'Expiry Date',
                icon: Icons.calendar_month,
                keyboardType: TextInputType.datetime,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                context: context,
                hintText: '123',
                labelText: 'CVV',
                icon: Icons.lock_outline,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Name
        _buildTextField(
          context: context,
          hintText: 'John Doe',
          labelText: 'Cardholder Name',
          icon: Icons.person_outline,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 18),
        // Submit Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Colors.tealAccent),
                      SizedBox(width: 8),
                      Text('Thank you! Donation successful.'),
                    ],
                  ),
                  backgroundColor: Color(0xFF1E3A2F),
                  duration: Duration(seconds: 3),
                ),
              );
              setState(() {
                _showCardForm = false;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Donate \$5.00',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required String hintText,
    required String labelText,
    required IconData icon,
    required TextInputType keyboardType,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          keyboardType: keyboardType,
          style: TextStyle(color: textColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: textColor.withValues(alpha: 0.35), fontSize: 13),
            prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 16),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalChip(int seconds, String label) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSelected = _audioLoopIntervalSeconds == seconds;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : primaryColor,
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      backgroundColor: primaryColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      onSelected: (val) async {
        if (val) {
          setState(() {
            _audioLoopIntervalSeconds = seconds;
          });
          await AppSettings.saveSettings(audioLoopIntervalSeconds: seconds);
          AlarmService.updateAudioConfig(loopIntervalSeconds: seconds);
        }
      },
    );
  }

  void _showRecordKeyDialog(TextEditingController controller, String label) {
    String recorded = controller.text;
    FocusNode focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).colorScheme.primary;
            final textColor = isDark ? Colors.white : Colors.black87;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF2E2E2E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.keyboard_alt_rounded, color: primaryColor),
                  const SizedBox(width: 8),
                  Text('Press Keys for $label', style: TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.bold)),
                ],
              ),
              content: KeyboardListener(
                focusNode: focusNode..requestFocus(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent) {
                    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
                    final keys = <String>[];

                    final isSuper = pressedKeys.any((k) =>
                        k == LogicalKeyboardKey.meta ||
                        k == LogicalKeyboardKey.metaLeft ||
                        k == LogicalKeyboardKey.metaRight ||
                        k == LogicalKeyboardKey.superKey) ||
                        HardwareKeyboard.instance.isMetaPressed;

                    final isCtrl = pressedKeys.any((k) =>
                        k == LogicalKeyboardKey.control ||
                        k == LogicalKeyboardKey.controlLeft ||
                        k == LogicalKeyboardKey.controlRight) ||
                        HardwareKeyboard.instance.isControlPressed;

                    final isAlt = pressedKeys.any((k) =>
                        k == LogicalKeyboardKey.alt ||
                        k == LogicalKeyboardKey.altLeft ||
                        k == LogicalKeyboardKey.altRight) ||
                        HardwareKeyboard.instance.isAltPressed;

                    final isShift = pressedKeys.any((k) =>
                        k == LogicalKeyboardKey.shift ||
                        k == LogicalKeyboardKey.shiftLeft ||
                        k == LogicalKeyboardKey.shiftRight) ||
                        HardwareKeyboard.instance.isShiftPressed;

                    if (isSuper) keys.add('Super');
                    if (isCtrl) keys.add('Ctrl');
                    if (isAlt) keys.add('Alt');
                    if (isShift) keys.add('Shift');

                    final ignored = {
                      LogicalKeyboardKey.meta,
                      LogicalKeyboardKey.metaLeft,
                      LogicalKeyboardKey.metaRight,
                      LogicalKeyboardKey.superKey,
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.controlLeft,
                      LogicalKeyboardKey.controlRight,
                      LogicalKeyboardKey.alt,
                      LogicalKeyboardKey.altLeft,
                      LogicalKeyboardKey.altRight,
                      LogicalKeyboardKey.shift,
                      LogicalKeyboardKey.shiftLeft,
                      LogicalKeyboardKey.shiftRight,
                      LogicalKeyboardKey.numLock,
                      LogicalKeyboardKey.capsLock,
                      LogicalKeyboardKey.scrollLock,
                    };

                    LogicalKeyboardKey? mainKey;
                    for (final k in pressedKeys) {
                      if (!ignored.contains(k)) {
                        mainKey = k;
                        break;
                      }
                    }
                    if (mainKey == null && !ignored.contains(event.logicalKey)) {
                      mainKey = event.logicalKey;
                    }

                    if (mainKey != null) {
                      String labelStr = '';
                      if (mainKey == LogicalKeyboardKey.period) {
                        labelStr = '.';
                      } else if (mainKey == LogicalKeyboardKey.comma) {
                        labelStr = ',';
                      } else if (mainKey == LogicalKeyboardKey.slash) {
                        labelStr = '/';
                      } else if (mainKey == LogicalKeyboardKey.minus) {
                        labelStr = '-';
                      } else if (mainKey == LogicalKeyboardKey.space) {
                        labelStr = 'Space';
                      } else {
                        labelStr = mainKey.keyLabel.trim().toUpperCase();
                        labelStr = labelStr.replaceAll('KEY ', '').replaceAll('NUM ', '');
                      }

                      if (labelStr.isNotEmpty && !keys.contains(labelStr)) {
                        keys.add(labelStr);
                      }
                    }

                    if (keys.isNotEmpty) {
                      setDialogState(() {
                        recorded = keys.join(' + ');
                      });
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Press your desired key combination on your keyboard',
                        style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryColor),
                        ),
                        child: Text(
                          recorded.isEmpty ? 'Listening for keys...' : recorded,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    if (recorded.isNotEmpty) {
                      setState(() {
                        controller.text = recorded;
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Assign Key', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

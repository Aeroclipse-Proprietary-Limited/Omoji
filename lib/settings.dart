import 'dart:io';
import 'dart:ui'; // Required for ImageFilter.blur

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omoji/build_config.dart';
import 'package:omoji/main.dart';
import 'package:omoji/services/account_service.dart';
import 'package:omoji/services/alarm_service.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/services/startup_service.dart';
import 'package:omoji/models/todo_item.dart';
import 'package:omoji/services/calendar_import_service.dart';
import 'package:omoji/services/hotkey_service.dart';
import 'package:omoji/services/logger_service.dart';
import 'package:omoji/widgets/full_version_prompt.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _payPalPaymentUrl =
      'https://www.paypal.com/ncp/payment/ZUZA5SH4V35RE';
  static const String _ethWalletAddress =
      '0xfe9dd55429fc5f35f9f363aeaeba256f955b807c';

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

  bool _superAgentsEnabled = false;
  String _superAgentModelType = 'local';
  String _superAgentCloudProvider = 'OpenAI';
  late TextEditingController _superAgentApiKeyController;
  bool _animationsEnabled = true;
  bool _runAtLogin = true;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _primaryTriggerController = TextEditingController(text: 'Super + .');
    _secondaryTriggerController = TextEditingController(text: 'Ctrl + Alt + O');
    _superAgentApiKeyController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _primaryTriggerController.dispose();
    _secondaryTriggerController.dispose();
    _superAgentApiKeyController.dispose();
    AlarmService.killAudioProcess();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await AppSettings.loadSettings();
    if (!mounted) return;
    setState(() {
      _customAlarmSoundPath = isDeveloperBuild
          ? settings['customAlarmSoundPath'] as String?
          : null;
      final savedUseSystemDefault = settings['useSystemDefaultSound'] as bool?;
      if (savedUseSystemDefault != null) {
        _useSystemDefaultSound = !isDeveloperBuild || savedUseSystemDefault;
      } else {
        _useSystemDefaultSound =
            (_customAlarmSoundPath == null || _customAlarmSoundPath!.isEmpty);
      }
      _audioLoopIntervalSeconds =
          (settings['audioLoopIntervalSeconds'] as int?) ?? 10;
      _autoPaste = settings['autoPaste'] as bool? ?? true;
      _ignoreEmojisInClipboard =
          settings['ignoreEmojisInClipboard'] as bool? ?? true;
      _enableEmojiPredictions =
          settings['enableEmojiPredictions'] as bool? ?? false;
      _primaryTriggerController.text = Platform.isWindows
          ? 'Super + Z'
          : 'Super + X';
      _secondaryTriggerController.text =
          (settings['secondaryTrigger'] as String?) ?? 'Ctrl + Alt + O';
      _superAgentsEnabled = settings['superAgentsEnabled'] as bool? ?? false;
      _superAgentModelType =
          settings['superAgentModelType'] as String? ?? 'local';
      _superAgentCloudProvider =
          settings['superAgentCloudProvider'] as String? ?? 'OpenAI';
      _superAgentApiKeyController.text =
          settings['superAgentApiKey'] as String? ?? '';
      _animationsEnabled = settings['animationsEnabled'] as bool? ?? true;
      _runAtLogin = settings['runAtLogin'] as bool? ?? true;

      final themeName = settings['theme'] as String?;
      if (themeName == 'light') themeNotifier.value = ThemeMode.light;
      if (themeName == 'dark') themeNotifier.value = ThemeMode.dark;
      if (themeName == 'system') themeNotifier.value = ThemeMode.system;

      final accentVal = settings['accentColor'] as int?;
      if (accentVal != null) {
        accentColorNotifier.value = Color(accentVal);
      }
      accentBackgroundIntensityNotifier.value =
          (settings['accentBackgroundIntensity'] as num?)?.toDouble() ??
          ((settings['accentBackgroundEffects'] as bool? ?? false)
              ? 0.35
              : 0.0);

      _hasUnsavedChanges = false;
    });
  }

  Future<void> _toggleSuperAgents(bool val) async {
    if (val && !isEmojiSelectionUnlocked && !isDeveloperBuild) {
      final wantsFullVersion = await showFullVersionPrompt(
        context,
        feature: 'Super Agents (AI)',
      );
      if (wantsFullVersion && mounted) {
        await _openFullVersionPage();
      }
      return;
    }
    setState(() {
      _superAgentsEnabled = val;
      _hasUnsavedChanges = true;
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
    const mailtoUrl =
        'mailto:godlyttn@outlook.com?subject=Feedback%20on%20omoji';
    if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [mailtoUrl]);
      } catch (_) {
        try {
          await Process.run('xdg-email', [
            'mailto:godlyttn@outlook.com',
            '--subject',
            'Feedback on omoji',
          ]);
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

  Future<void> _openPayPalPayment() async {
    final command = Platform.isLinux
        ? ('xdg-open', [_payPalPaymentUrl])
        : Platform.isMacOS
        ? ('open', [_payPalPaymentUrl])
        : Platform.isWindows
        ? ('rundll32', ['url.dll,FileProtocolHandler', _payPalPaymentUrl])
        : throw UnsupportedError(
            'PayPal payments are not supported on this platform.',
          );

    try {
      final result = await Process.run(command.$1, command.$2);
      if (result.exitCode != 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PayPal: ${result.stderr}')),
        );
      }
    } on ProcessException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PayPal: $error')),
        );
      }
    }
  }

  Future<void> _showCustomAlarmSoundUpgradeDialog() async {
    final wantsFullVersion = await showFullVersionPrompt(
      context,
      feature: 'Custom alarm sounds',
    );
    if (wantsFullVersion && mounted) {
      await _openFullVersionPage();
    }
  }

  Future<void> _openFullVersionPage() async {
    final command = Platform.isLinux
        ? ('xdg-open', [fullVersionUrl])
        : Platform.isMacOS
        ? ('open', [fullVersionUrl])
        : Platform.isWindows
        ? ('rundll32', ['url.dll,FileProtocolHandler', fullVersionUrl])
        : throw UnsupportedError(
            'GitHub Releases are not supported on this platform.',
          );

    try {
      final result = await Process.run(command.$1, command.$2);
      if (result.exitCode != 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open GitHub Releases: ${result.stderr}'),
          ),
        );
      }
    } on ProcessException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open GitHub Releases: $error')),
        );
      }
    }
  }

  Future<void> _copyEthWalletAddress() async {
    try {
      await Clipboard.setData(const ClipboardData(text: _ethWalletAddress));
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not copy ETH wallet address: $error')),
        );
      }
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ETH wallet address copied'),
        content: const Text(
          'Paste the address into Binance or another wallet to send ETH. '
          'Select the Ethereum (ERC-20) network and verify the address before '
          'confirming; crypto transfers cannot be reversed.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndGoBack(BuildContext context) async {
    if (_isRegisteringHotkeys) return;
    if (_hasUnsavedChanges) {
      await _saveChanges();
    }
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _resetOmoji() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Omoji?'),
        content: const Text(
          'This will delete all configurations, settings, clipboard history, alarms, and to-dos, restoring Omoji to factory defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Omoji'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      final configDir = Directory('$home/.config/omoji');
      if (await configDir.exists()) {
        await configDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Failed to delete config directory: $e');
    }

    setState(() {
      _autoPaste = true;
      _ignoreEmojisInClipboard = true;
      _enableEmojiPredictions = false;
      _superAgentsEnabled = false;
      _superAgentModelType = 'local';
      _superAgentCloudProvider = 'OpenAI';
      _superAgentApiKeyController.clear();
      _animationsEnabled = true;
      _runAtLogin = true;
      themeNotifier.value = ThemeMode.system;
      accentColorNotifier.value = const Color(0xFFB91C1C);
      accentBackgroundIntensityNotifier.value = 0.0;
      _hasUnsavedChanges = false;
    });
    AppSettings.animationsEnabledNotifier.value = true;
    await StartupService.setEnabled(true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Omoji has been reset to factory defaults.'),
        ),
      );
    }
  }

  Future<void> _shutDownOmoji() async {
    if (!_animationsEnabled) {
      exit(0);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const durationMs = 3000;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131417) : const Color(0xFFF3F0EA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                isDark
                    ? 'lib/assets/gifs/shutdown dark v1.gif'
                    : 'lib/assets/gifs/shutdown v1.gif',
                width: 140,
                height: 140,
              ),
              const SizedBox(height: 16),
              Text(
                'Shutting down Omoji...',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(Duration(milliseconds: durationMs));
    exit(0);
  }

  Future<void> _saveChanges() async {
    if (_isRegisteringHotkeys) return;
    setState(() => _isRegisteringHotkeys = true);

    final primary = Platform.isWindows ? 'Super + Z' : 'Super + X';
    final secondary = _secondaryTriggerController.text.trim();

    await AppSettings.saveSettings(
      theme: themeNotifier.value,
      accentColorValue: accentColorNotifier.value.toARGB32(),
      accentBackgroundIntensity: accentBackgroundIntensityNotifier.value,
      autoPaste: _autoPaste,
      ignoreEmojisInClipboard: _ignoreEmojisInClipboard,
      enableEmojiPredictions: _enableEmojiPredictions,
      superAgentsEnabled: _superAgentsEnabled,
      superAgentModelType: _superAgentModelType,
      superAgentCloudProvider: _superAgentCloudProvider,
      superAgentApiKey: _superAgentApiKeyController.text.trim(),
      animationsEnabled: _animationsEnabled,
      runAtLogin: _runAtLogin,
      primaryTrigger: primary,
      secondaryTrigger: secondary,
      audioLoopIntervalSeconds: _audioLoopIntervalSeconds,
      customAlarmSoundPath: _customAlarmSoundPath,
      useSystemDefaultSound: _useSystemDefaultSound,
    );
    traySuperAgentsNotifier.value = _superAgentsEnabled;
    try {
      await StartupService.setEnabled(_runAtLogin);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update login startup: $error')),
        );
      }
    }

    await HotkeyService.registerTriggers(
      primaryTrigger: primary,
      secondaryTrigger: secondary,
    );

    setState(() {
      _isRegisteringHotkeys = false;
      _hasUnsavedChanges = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully.')),
      );
    }
  }

  Future<void> _showLogsDialog() async {
    final log = await LoggerService.readLog();
    String changelog;
    try {
      changelog = await rootBundle.loadString('CHANGELOG.md');
    } catch (_) {
      changelog = 'CHANGELOG.md could not be loaded.';
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final selectedLevels = <String>{'INFO', 'WARN', 'ERROR'};
    var showingChangelog = false;
    var visibleLog = log;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(showingChangelog ? 'Omoji changelog' : 'Omoji logs'),
          content: SizedBox(
            width: 600,
            height: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Logs'),
                      selected: !showingChangelog,
                      onSelected: (_) =>
                          setDialogState(() => showingChangelog = false),
                    ),
                    ChoiceChip(
                      label: const Text('CHANGELOG.md'),
                      selected: showingChangelog,
                      onSelected: (_) =>
                          setDialogState(() => showingChangelog = true),
                    ),
                  ],
                ),
                if (!showingChangelog) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: ['INFO', 'WARN', 'ERROR'].map((level) {
                      return FilterChip(
                        label: Text(level),
                        selected: selectedLevels.contains(level),
                        onSelected: (selected) async {
                          if (selected) {
                            selectedLevels.add(level);
                          } else {
                            selectedLevels.remove(level);
                          }
                          visibleLog = await LoggerService.readLog(
                            levels: selectedLevels,
                          );
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      showingChangelog ? changelog : visibleLog,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!showingChangelog)
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: visibleLog));
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Logs copied to clipboard.'),
                      ),
                    );
                  }
                },
                child: const Text('Copy filtered logs'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCalendarEventsFromSettings() async {
    if (!AccountService.isAccountAttached) return;
    final imported = await CalendarImportService.pickAndImport();
    if (imported == null || imported.isEmpty) return;
    final settings = await AppSettings.loadSettings();
    final storedTodos = settings['todos'] as List<dynamic>? ?? const [];
    final todos =
        storedTodos
            .whereType<Map>()
            .map((item) => TodoItem.fromJson(Map<String, dynamic>.from(item)))
            .toList()
          ..addAll(imported);
    await AppSettings.saveSettings(todos: todos);
    AlarmService.updateTodos(todos);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${imported.length} calendar events.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.black.withValues(alpha: 0.6);
    final cardBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

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
                          applyAccentBackgroundEffect(
                            const Color(0xFF2E2E2E).withValues(alpha: 0.65),
                          ),
                          applyAccentBackgroundEffect(
                            const Color(0xFF1A1A1A).withValues(alpha: 0.45),
                          ),
                          applyAccentBackgroundEffect(
                            const Color(0xFF121212).withValues(alpha: 0.75),
                          ),
                        ]
                      : [
                          applyAccentBackgroundEffect(
                            const Color(0xFFFFFFFF).withValues(alpha: 0.65),
                          ),
                          applyAccentBackgroundEffect(
                            const Color(0xFFE0E0E0).withValues(alpha: 0.45),
                          ),
                          applyAccentBackgroundEffect(
                            const Color(0xFFF5F5F5).withValues(alpha: 0.75),
                          ),
                        ],
                  stops: const [0.0, 0.4, 1.0],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.15),
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: _isRegisteringHotkeys
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: textColor,
                                  ),
                                )
                              : const Icon(Icons.arrow_back_ios_new_rounded),
                          color: textColor,
                          splashRadius: 20,
                          onPressed: () => _saveAndGoBack(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Settings',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_hasUnsavedChanges) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Unsaved changes',
                                      style: TextStyle(
                                        color: Colors.amber[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: Colors.redAccent,
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(60, 24),
                                      ),
                                      onPressed: _resetOmoji,
                                      child: const Text(
                                        'Reset Omoji',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 2,
                                        ),
                                        minimumSize: const Size(60, 24),
                                      ),
                                      onPressed: _saveChanges,
                                      child: const Text(
                                        'Save changes',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Open Omoji logs',
                          onPressed: _showLogsDialog,
                          icon: const Icon(Icons.article_outlined, size: 18),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                          isActive:
                                              currentTheme == ThemeMode.dark,
                                          onTap: () async {
                                            themeNotifier.value =
                                                ThemeMode.dark;
                                            await AppSettings.saveSettings(
                                              theme: ThemeMode.dark,
                                            );
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildThemeOption(
                                          context: context,
                                          label: 'Light',
                                          icon: Icons.light_mode_rounded,
                                          isActive:
                                              currentTheme == ThemeMode.light,
                                          onTap: () async {
                                            themeNotifier.value =
                                                ThemeMode.light;
                                            await AppSettings.saveSettings(
                                              theme: ThemeMode.light,
                                            );
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildThemeOption(
                                          context: context,
                                          label: 'System',
                                          icon:
                                              Icons.settings_brightness_rounded,
                                          isActive:
                                              currentTheme == ThemeMode.system,
                                          onTap: () async {
                                            themeNotifier.value =
                                                ThemeMode.system;
                                            await AppSettings.saveSettings(
                                              theme: ThemeMode.system,
                                            );
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: List.generate(
                                      accentColors.length,
                                      (idx) {
                                        final color = accentColors[idx];
                                        final isSelected =
                                            currentAccent == color;

                                        return Tooltip(
                                          message: accentLabels[idx],
                                          child: GestureDetector(
                                            onTap: () async {
                                              accentColorNotifier.value = color;
                                              setState(() {});
                                              await AppSettings.saveSettings(
                                                accentColorValue: color
                                                    .toARGB32(),
                                              );
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              width: 34,
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: color,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.transparent,
                                                  width: 2.5,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: color.withValues(
                                                      alpha: isSelected
                                                          ? 0.6
                                                          : 0.25,
                                                    ),
                                                    blurRadius: isSelected
                                                        ? 10
                                                        : 4,
                                                    spreadRadius: isSelected
                                                        ? 2
                                                        : 0,
                                                  ),
                                                ],
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                      size: 18,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 18),
                            Text(
                              'Accent Effects',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Choose how the selected accent colour is used.',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ValueListenableBuilder<double>(
                              valueListenable:
                                  accentBackgroundIntensityNotifier,
                              builder: (context, tintIntensity, _) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: cardBorderColor),
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.format_color_fill_rounded,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text('Tint background'),
                                          ),
                                          Text(
                                            '${(tintIntensity * 100).round()}%',
                                          ),
                                        ],
                                      ),
                                      Slider(
                                        value: tintIntensity.clamp(0.0, 1.0),
                                        min: 0,
                                        max: 1,
                                        divisions: 20,
                                        label:
                                            '${(tintIntensity * 100).round()}%',
                                        onChanged: (value) {
                                          accentBackgroundIntensityNotifier
                                                  .value =
                                              value;
                                          setState(() {});
                                        },
                                        onChangeEnd: (value) async {
                                          await AppSettings.saveSettings(
                                            accentBackgroundIntensity: value,
                                          );
                                        },
                                      ),
                                    ],
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
                                          isActive:
                                              currentFormat == 'dd/mm/yyyy',
                                          onTap: () async {
                                            dateFormatNotifier.value =
                                                'dd/mm/yyyy';
                                            await AppSettings.saveSettings(
                                              dateFormat: 'dd/mm/yyyy',
                                            );
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildThemeOption(
                                          context: context,
                                          label: 'yyyy/mm/dd',
                                          icon: Icons.event_rounded,
                                          isActive:
                                              currentFormat == 'yyyy/mm/dd',
                                          onTap: () async {
                                            dateFormatNotifier.value =
                                                'yyyy/mm/dd';
                                            await AppSettings.saveSettings(
                                              dateFormat: 'yyyy/mm/dd',
                                            );
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
                                  ('all', 'All', Icons.list_rounded),
                                  (
                                    'upcoming',
                                    'Upcoming',
                                    Icons.upcoming_rounded,
                                  ),
                                  ('missed', 'Missed', Icons.alarm_off_rounded),
                                  (
                                    'delayed',
                                    'Delayed',
                                    Icons.event_repeat_rounded,
                                  ),
                                  (
                                    'completed',
                                    'Done',
                                    Icons.check_circle_outline_rounded,
                                  ),
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
                                            todoDefaultViewNotifier.value =
                                                v.$1;
                                            await AppSettings.saveSettings(
                                              todoDefaultView: v.$1,
                                            );
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 3,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isActive
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                      Icon(
                                        Icons.keyboard_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 20,
                                      ),
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
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.04)
                                          : Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: cardBorderColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.bolt_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          Platform.isWindows
                                              ? 'Super + Z'
                                              : 'Super + X',
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Primary Default',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
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
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller:
                                              _secondaryTriggerController,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'e.g. Ctrl + Alt + O',
                                            prefixIcon: Icon(
                                              Icons.bolt_outlined,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              size: 18,
                                            ),
                                            isDense: true,
                                            filled: true,
                                            fillColor: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.04,
                                                  )
                                                : Colors.black.withValues(
                                                    alpha: 0.03,
                                                  ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.2),
                                          foregroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.fiber_manual_record_rounded,
                                          size: 14,
                                          color: Colors.redAccent,
                                        ),
                                        label: const Text(
                                          'Record Key',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: () => _showRecordKeyDialog(
                                          _secondaryTriggerController,
                                          'Secondary Trigger',
                                        ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.paste_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                        activeThumbColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        onChanged: (val) {
                                          setState(() {
                                            _autoPaste = val;
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  Divider(color: cardBorderColor, height: 16),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.do_not_disturb_on_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                        activeThumbColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        onChanged: (val) {
                                          setState(() {
                                            _ignoreEmojisInClipboard = val;
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  Divider(color: cardBorderColor, height: 16),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.speed_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Animations',
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Show Omoji startup and summoning animations',
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _animationsEnabled,
                                        activeThumbColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        onChanged: (val) {
                                          setState(() {
                                            _animationsEnabled = val;
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  Divider(color: cardBorderColor, height: 16),
                                  Row(
                                    children: [
                                      Image.asset(
                                        'lib/assets/gifs/SIMPLE INTELLIGENCE.gif',
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Super Agents (AI)',
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isEmojiSelectionUnlocked ||
                                                      isDeveloperBuild
                                                  ? 'Enable Omoji AI Chat & Super Agents'
                                                  : 'Paid feature (Requires full version license)',
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch(
                                        value: _superAgentsEnabled,
                                        activeThumbColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        onChanged: _toggleSuperAgents,
                                      ),
                                    ],
                                  ),
                                  if (_superAgentsEnabled) ...[
                                    const SizedBox(height: 12),
                                    Divider(color: cardBorderColor, height: 16),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.lightbulb_outline_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Live Emoji Predictions',
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Suggest matching emoji as you type',
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
                                          activeThumbColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          onChanged: (val) {
                                            setState(() {
                                              _enableEmojiPredictions = val;
                                              _hasUnsavedChanges = true;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Select AI Model Engine',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<String>(
                                            title: Text(
                                              'Local (Omoji)',
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 13,
                                              ),
                                            ),
                                            value: 'local',
                                            groupValue: _superAgentModelType,
                                            onChanged: (val) {
                                              if (val == null) return;
                                              setState(() {
                                                _superAgentModelType = val;
                                                _hasUnsavedChanges = true;
                                              });
                                            },
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<String>(
                                            title: Text(
                                              'Cloud AI',
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 13,
                                              ),
                                            ),
                                            value: 'cloud',
                                            groupValue: _superAgentModelType,
                                            onChanged: (val) {
                                              if (val == null) return;
                                              setState(() {
                                                _superAgentModelType = val;
                                                _hasUnsavedChanges = true;
                                              });
                                            },
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_superAgentModelType == 'cloud') ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        'Cloud AI Provider',
                                        style: TextStyle(
                                          color: subtitleColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        value: _superAgentCloudProvider,
                                        dropdownColor: cardBg,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'OpenAI',
                                            child: Text(
                                              'OpenAI (GPT-4o / GPT-4)',
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Gemini',
                                            child: Text(
                                              'Google Gemini (Gemini Pro)',
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Anthropic',
                                            child: Text('Anthropic Claude'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'DeepSeek',
                                            child: Text('DeepSeek R1 / V3'),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val == null) return;
                                          setState(() {
                                            _superAgentCloudProvider = val;
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'API Key',
                                        style: TextStyle(
                                          color: subtitleColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _superAgentApiKeyController,
                                        obscureText: true,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Enter your API key...',
                                          isDense: true,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                        ),
                                        onChanged: (val) {
                                          setState(() {
                                            _hasUnsavedChanges = true;
                                          });
                                        },
                                      ),
                                    ],
                                  ],
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
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  RadioListTile<bool>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      'Use System Default Sound',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                    value: true,
                                    groupValue: _useSystemDefaultSound,
                                    activeColor: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    onChanged: (val) async {
                                      if (val != null) {
                                        setState(() {
                                          _useSystemDefaultSound = val;
                                        });
                                        await AppSettings.saveSettings(
                                          useSystemDefaultSound: val,
                                        );
                                        AlarmService.updateAudioConfig(
                                          useSystemDefault: val,
                                        );
                                      }
                                    },
                                  ),
                                  RadioListTile<bool>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Custom Audio File (MP3 / WAV / OGG)',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (!isDeveloperBuild)
                                          Icon(
                                            Icons.lock_outline_rounded,
                                            size: 16,
                                            color: subtitleColor,
                                          ),
                                      ],
                                    ),
                                    value: false,
                                    groupValue: _useSystemDefaultSound,
                                    activeColor: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    onChanged: (val) async {
                                      if (val != null) {
                                        if (val == false && !isDeveloperBuild) {
                                          await _showCustomAlarmSoundUpgradeDialog();
                                          return;
                                        }
                                        setState(() {
                                          _useSystemDefaultSound = val;
                                        });
                                        await AppSettings.saveSettings(
                                          useSystemDefaultSound: val,
                                        );
                                        AlarmService.updateAudioConfig(
                                          useSystemDefault: val,
                                        );
                                      }
                                    },
                                  ),
                                  if (!_useSystemDefaultSound) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.music_note_rounded,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _customAlarmSoundPath != null
                                                ? _customAlarmSoundPath!
                                                      .split('/')
                                                      .last
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
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            foregroundColor: Colors.white,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: () async {
                                            await _pickCustomSound();
                                            await AppSettings.saveSettings(
                                              useSystemDefaultSound: false,
                                            );
                                            AlarmService.updateAudioConfig(
                                              useSystemDefault: false,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.folder_open_rounded,
                                            size: 16,
                                          ),
                                          label: const Text(
                                            'Browse MP3',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _isPlayingTest
                                                ? Colors.redAccent
                                                : Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                            side: BorderSide(
                                              color: _isPlayingTest
                                                  ? Colors.redAccent
                                                  : Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
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
                                              AlarmService.playAlertSound(
                                                customPath:
                                                    _customAlarmSoundPath,
                                              );
                                            }
                                          },
                                          icon: Icon(
                                            _isPlayingTest
                                                ? Icons.stop_rounded
                                                : Icons.play_arrow_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            _isPlayingTest
                                                ? 'Stop Sound'
                                                : 'Test Sound',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.restart_alt_rounded,
                                            size: 20,
                                          ),
                                          color: _customAlarmSoundPath != null
                                              ? Colors.orangeAccent
                                              : textColor.withValues(
                                                  alpha: 0.3,
                                                ),
                                          tooltip:
                                              'Reset to Default System Sound',
                                          onPressed:
                                              _customAlarmSoundPath == null
                                              ? null
                                              : () async {
                                                  setState(() {
                                                    _customAlarmSoundPath =
                                                        null;
                                                    _useSystemDefaultSound =
                                                        true;
                                                  });
                                                  await AppSettings.saveSettings(
                                                    clearCustomAlarmSound: true,
                                                    useSystemDefaultSound: true,
                                                  );
                                                  AlarmService.updateAudioConfig(
                                                    useSystemDefault: true,
                                                    customPath: null,
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  ],
                                  Divider(color: cardBorderColor, height: 24),
                                  // Loop Interval Section (Range: 10s to 1m 33s / 93s)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Audio Repeat Loop Interval',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'How frequently the sound repeats (10s – 1m 33s)',
                                            style: TextStyle(
                                              color: subtitleColor,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.15),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.4),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          _formatIntervalLabel(
                                            _audioLoopIntervalSeconds,
                                          ),
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Slider(
                                    value: _audioLoopIntervalSeconds
                                        .toDouble()
                                        .clamp(10.0, 93.0),
                                    min: 10.0,
                                    max: 93.0,
                                    divisions: 83,
                                    activeColor: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    label: _formatIntervalLabel(
                                      _audioLoopIntervalSeconds,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _audioLoopIntervalSeconds = val.round();
                                      });
                                    },
                                    onChangeEnd: (val) async {
                                      final interval = val.round();
                                      await AppSettings.saveSettings(
                                        audioLoopIntervalSeconds: interval,
                                      );
                                      AlarmService.updateAudioConfig(
                                        loopIntervalSeconds: interval,
                                      );
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

                            // Section: Startup
                            Text(
                              'Startup',
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
                              child: CheckboxListTile(
                                value: _runAtLogin,
                                activeColor: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                title: Text(
                                  'Run at login',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Start Omoji automatically when you sign in to your computer.',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 11,
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _runAtLogin = value;
                                    _hasUnsavedChanges = true;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Section: Account access
                            Text(
                              'Account & Calendar Import',
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
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.account_circle_outlined,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AccountService.isAccountAttached
                                                  ? 'Account attached'
                                                  : 'No account attached',
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Firebase sign-in will be added in a later update.',
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: null,
                                        icon: const Icon(
                                          Icons.login_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Login'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (AccountService.isAccountAttached)
                                    OutlinedButton.icon(
                                      onPressed:
                                          _importCalendarEventsFromSettings,
                                      icon: const Icon(
                                        Icons.event_available_rounded,
                                      ),
                                      label: const Text(
                                        'Import calendar events',
                                      ),
                                    )
                                  else
                                    Text(
                                      'Calendar and event import will appear here after an account is attached.',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 12,
                                      ),
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
                              splashColor: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.1),
                              highlightColor: Colors.transparent,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorderColor),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.2),
                                          backgroundImage: const AssetImage(
                                            'lib/assets/imgs/acc pic.jpg',
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Kevin Manda',
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: 'Shut Omoji down',
                                                  icon: const Icon(
                                                    Icons
                                                        .power_settings_new_rounded,
                                                    color: Colors.redAccent,
                                                    size: 20,
                                                  ),
                                                  onPressed: _shutDownOmoji,
                                                ),
                                              ],
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
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.coffee_rounded,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'buy me a coffee',
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildDonationButton(
                                            context: context,
                                            label: 'PayPal',
                                            icon: Icons.open_in_new_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            isActive: false,
                                            onTap: _openPayPalPayment,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildDonationButton(
                                            context: context,
                                            label: 'ETH',
                                            icon:
                                                Icons.currency_bitcoin_rounded,
                                            color: Colors.amber[700]!,
                                            isActive: false,
                                            onTap: _copyEthWalletAddress,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
              color: isActive
                  ? Colors.white
                  : (isDark ? Colors.white54 : Colors.black54),
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
          color: isActive
              ? color.withValues(alpha: 0.3)
              : color.withValues(alpha: 0.15),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.4),
            width: 1.5,
          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.keyboard_alt_rounded, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Press Keys for $label',
                    style: TextStyle(
                      fontSize: 15,
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: KeyboardListener(
                focusNode: focusNode..requestFocus(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent) {
                    final pressedKeys =
                        HardwareKeyboard.instance.logicalKeysPressed;
                    final keys = <String>[];

                    final isSuper =
                        pressedKeys.any(
                          (k) =>
                              k == LogicalKeyboardKey.meta ||
                              k == LogicalKeyboardKey.metaLeft ||
                              k == LogicalKeyboardKey.metaRight ||
                              k == LogicalKeyboardKey.superKey,
                        ) ||
                        HardwareKeyboard.instance.isMetaPressed;

                    final isCtrl =
                        pressedKeys.any(
                          (k) =>
                              k == LogicalKeyboardKey.control ||
                              k == LogicalKeyboardKey.controlLeft ||
                              k == LogicalKeyboardKey.controlRight,
                        ) ||
                        HardwareKeyboard.instance.isControlPressed;

                    final isAlt =
                        pressedKeys.any(
                          (k) =>
                              k == LogicalKeyboardKey.alt ||
                              k == LogicalKeyboardKey.altLeft ||
                              k == LogicalKeyboardKey.altRight,
                        ) ||
                        HardwareKeyboard.instance.isAltPressed;

                    final isShift =
                        pressedKeys.any(
                          (k) =>
                              k == LogicalKeyboardKey.shift ||
                              k == LogicalKeyboardKey.shiftLeft ||
                              k == LogicalKeyboardKey.shiftRight,
                        ) ||
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
                    if (mainKey == null &&
                        !ignored.contains(event.logicalKey)) {
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
                        labelStr = labelStr
                            .replaceAll('KEY ', '')
                            .replaceAll('NUM ', '');
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Press your desired key combination on your keyboard',
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryColor),
                        ),
                        child: Text(
                          recorded.isEmpty ? 'Listening for keys...' : recorded,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () {
                    if (recorded.isNotEmpty) {
                      setState(() {
                        controller.text = recorded;
                      });
                    }
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Assign Key',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

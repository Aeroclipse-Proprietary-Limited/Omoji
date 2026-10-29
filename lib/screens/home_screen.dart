// lib/screens/home_screen.dart

import 'dart:ui';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:omoji/build_config.dart';
import 'package:omoji/data/emoji_map.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/models/chat_message.dart';
import 'package:omoji/models/clipboard_item.dart';
import 'package:omoji/models/todo_item.dart';
import 'package:omoji/main.dart';
import 'package:omoji/services/alarm_service.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/services/emoji_prediction_service.dart';
import 'package:omoji/services/hotkey_service.dart';
import 'package:omoji/services/logger_service.dart';
import 'package:omoji/services/stopwatch_service.dart';
import 'package:omoji/services/timer_service.dart';
import 'package:omoji/widgets/clipboard_view.dart';
import 'package:omoji/widgets/clipboard_chat_view.dart';
import 'package:omoji/widgets/clock_view.dart';
import 'package:omoji/widgets/emoji_view.dart';
import 'package:omoji/widgets/full_version_prompt.dart';
import 'package:omoji/widgets/tab_switcher.dart';
import 'package:omoji/widgets/top_bar.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class OmojiHomeScreen extends StatefulWidget {
  const OmojiHomeScreen({super.key});

  @override
  State<OmojiHomeScreen> createState() => _OmojiHomeScreenState();
}

class _OmojiHomeScreenState extends State<OmojiHomeScreen> with WindowListener {
  static const MethodChannel _windowChannel = MethodChannel(
    'com.aeroclipse.omoji/window',
  );

  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _focusNode;
  final FocusNode _keyboardFocusNode = FocusNode();
  String _searchQuery = "";

  final List<String> _recentEmojis = [];
  bool _privateMode = false;
  bool _autoPaste = true;
  bool _ignoreEmojisInClipboard = true;

  bool _enableEmojiPredictions = true;
  List<Map<String, String>> _currentPredictions = [];
  String? _dismissedPredictionWord;
  bool _isFloatingOverlayMode = false;
  String _globalPredictionWord = "";

  bool _isEmojiOnly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final emojiRegExp = RegExp(
      r'^[\u{1F300}-\u{1F9FF}\u{1F600}-\u{1F64F}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}\u{200D}\u{FE0F}\s]+$',
      unicode: true,
    );
    return emojiRegExp.hasMatch(trimmed);
  }

  List<ClipboardItem> _clipboardHistory = [];
  List<AlarmItem> _alarms = [];
  List<TodoItem> _todos = [];
  String _selectedTab = 'clipboard';
  bool _isChatMode = false;
  String _chatInitialPrompt = '';
  final List<ChatMessage> _chatMessages = [];
  String? _lastClipboardText;
  Timer? _clipboardTimer;
  bool _isCheckingClipboard = false;
  bool _clipboardCheckPending = false;
  bool _isPastingSelection = false;
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _windowChannel.setMethodCallHandler(_handleNativeMethodCall);
    windowManager.addListener(this);
    AppSettings.dataImportRevision.addListener(_handleImportedData);

    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (_enableEmojiPredictions && _currentPredictions.isNotEmpty) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              final topEmoji = _currentPredictions.first['char']!;
              _handleEmojiSelection(topEmoji);
              setState(() {
                _dismissedPredictionWord = null;
                _currentPredictions = [];
              });
              return KeyEventResult.handled;
            }

            if (event.logicalKey == LogicalKeyboardKey.escape) {
              final trimmed = _searchController.text.trim();
              final words = trimmed
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .toList();
              if (words.isNotEmpty) {
                final cleanLast = words.last.toLowerCase().replaceAll(
                  RegExp(r'[^a-z0-9]'),
                  '',
                );
                setState(() {
                  _dismissedPredictionWord = cleanLast;
                  _currentPredictions = [];
                });
              }
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _searchController.addListener(() {
      final text = _searchController.text;
      setState(() {
        _searchQuery = text.toLowerCase().trim();
        if (_enableEmojiPredictions && !_isFloatingOverlayMode) {
          _currentPredictions = _getEmojiPredictions(text);
        } else if (!_isFloatingOverlayMode) {
          _currentPredictions = [];
        }
      });
    });

    _loadClipboardSettings();
    _startClipboardMonitoring();

    EmojiPredictionService.init();
    EmojiPredictionService.currentEvent.addListener(
      _handleGlobalPredictionEvent,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedTab != 'clock') {
        _focusNode.requestFocus();
      }
    });
  }

  void _handleGlobalPredictionEvent() async {
    if (!mounted || !_enableEmojiPredictions) return;

    final event = EmojiPredictionService.currentEvent.value;
    if (event == null) return;

    if (event.type == 'prediction') {
      if (event.predictions.isNotEmpty) {
        setState(() {
          _globalPredictionWord = event.word;
          _currentPredictions = event.predictions;
          _isFloatingOverlayMode = true;
        });

        try {
          final display = await screenRetriever.getPrimaryDisplay();
          final screenWidth = display.size.width;
          final screenHeight = display.size.height;

          // Target clean compact overlay size
          double targetX = (screenWidth - 440) / 2;
          double targetY = screenHeight - 190;

          if (event.x != null &&
              event.y != null &&
              event.x! > 0 &&
              event.y! > 0) {
            targetX = (event.x! - 220)
                .clamp(10.0, screenWidth - 450.0)
                .toDouble();
            targetY = (event.y! - 80)
                .clamp(10.0, screenHeight - 80.0)
                .toDouble();
          }

          try {
            await const MethodChannel(
              'com.aeroclipse.omoji/window',
            ).invokeMethod('showOverlay', {
              'x': targetX,
              'y': targetY,
              'width': 440.0,
              'height': 60.0,
            });
          } catch (e) {
            debugPrint('Error showing native GTK overlay: $e');
          }
        } catch (e) {
          debugPrint('Error calculating display offset: $e');
        }
      } else {
        await _clearOverlayMode();
      }
    } else if (event.type == 'autofill') {
      final emoji = event.emoji;
      if (emoji != null && emoji.isNotEmpty) {
        _handleEmojiSelection(emoji);
      }
      await _clearOverlayMode();
    } else if (event.type == 'clear') {
      await _clearOverlayMode();
    }
  }

  Future<void> _clearOverlayMode() async {
    if (_isFloatingOverlayMode) {
      setState(() {
        _isFloatingOverlayMode = false;
        _currentPredictions = [];
        _globalPredictionWord = "";
      });
      try {
        await const MethodChannel(
          'com.aeroclipse.omoji/window',
        ).invokeMethod('hideOverlay');
      } catch (_) {}
    }
  }

  List<Map<String, String>> _getEmojiPredictions(String query) {
    if (!_enableEmojiPredictions || _selectedTab == 'clock') return [];

    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final words = trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return [];

    final rawLast = words.last.toLowerCase();
    final cleanLast = rawLast.replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (cleanLast.length < 2) return [];

    if (_dismissedPredictionWord == cleanLast) return [];

    final List<Map<String, String>> exactMatches = [];
    final List<Map<String, String>> prefixMatches = [];
    final Set<String> addedChars = {};

    for (final category in fullEmojiData.values) {
      for (final emoji in category) {
        final char = emoji['char'];
        final name = emoji['name'];
        if (char == null || name == null) continue;
        if (addedChars.contains(char)) continue;

        final tokens = name.toLowerCase().split(RegExp(r'\s+'));

        if (tokens.contains(cleanLast)) {
          exactMatches.add(emoji);
          addedChars.add(char);
        } else if (cleanLast.length >= 3 &&
            tokens.any((t) => t.startsWith(cleanLast))) {
          prefixMatches.add(emoji);
          addedChars.add(char);
        }
      }
    }

    return [...exactMatches, ...prefixMatches].take(4).toList();
  }

  Widget _buildEmojiPredictionBar(bool isDark, Color textColor) {
    final accentColor = Theme.of(context).colorScheme.primary;
    final bg = isDark
        ? const Color(0xFF242424).withValues(alpha: 0.95)
        : const Color(0xFFFFFFFF).withValues(alpha: 0.95);
    final borderColor = accentColor.withValues(alpha: 0.5);

    final words = _searchController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final lastWord = _isFloatingOverlayMode
        ? _globalPredictionWord
        : (words.isNotEmpty ? words.last : '');

    return Container(
      margin: _isFloatingOverlayMode
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: accentColor, size: 18),
          const SizedBox(width: 8),
          Text(
            '"$lastWord"',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_rounded,
            color: textColor.withValues(alpha: 0.4),
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _currentPredictions.map((pred) {
                  final char = pred['char']!;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          _handleEmojiSelection(char);
                          setState(() {
                            _dismissedPredictionWord = null;
                            _currentPredictions = [];
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            char,
                            style: const TextStyle(
                              fontSize: 20,
                              fontFamily: 'NotoColorEmoji',
                              fontFamilyFallback: ['NotoColorEmoji'],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              if (_currentPredictions.isNotEmpty) {
                _handleEmojiSelection(_currentPredictions.first['char']!);
                setState(() {
                  _dismissedPredictionWord = null;
                  _currentPredictions = [];
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_tab_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Tab Autofill',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Dismiss suggestion (Esc)',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                final trimmed = _searchController.text.trim();
                final words = trimmed
                    .split(RegExp(r'\s+'))
                    .where((w) => w.isNotEmpty)
                    .toList();
                if (words.isNotEmpty) {
                  final cleanLast = words.last.toLowerCase().replaceAll(
                    RegExp(r'[^a-z0-9]'),
                    '',
                  );
                  setState(() {
                    _dismissedPredictionWord = cleanLast;
                    _currentPredictions = [];
                  });
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _windowChannel.setMethodCallHandler(null);
    windowManager.removeListener(this);
    AppSettings.dataImportRevision.removeListener(_handleImportedData);
    _searchController.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    _clipboardTimer?.cancel();
    _editController.dispose();
    AlarmService.dispose();
    super.dispose();
  }

  Future<void> _handleImportedData() async {
    await TimerService.init();
    await StopwatchService.init();

    final settings = await AppSettings.loadSettings();
    if (!mounted) return;
    final themeName = settings['theme'] as String?;
    themeNotifier.value = switch (themeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final accentValue = settings['accentColor'] as int?;
    accentColorNotifier.value = Color(accentValue ?? 0xFFB91C1C);
    final savedDateFormat = settings['dateFormat'] as String?;
    dateFormatNotifier.value = savedDateFormat == 'yyyy/mm/dd'
        ? 'yyyy/mm/dd'
        : 'dd/mm/yyyy';
    const validTodoViews = {'all', 'upcoming', 'missed', 'completed'};
    final todoView = settings['todoDefaultView'] as String?;
    todoDefaultViewNotifier.value =
        todoView != null && validTodoViews.contains(todoView)
        ? todoView
        : 'upcoming';
    await _loadClipboardSettings();
  }

  Future<void> _showClockUpgradeDialog() async {
    final wantsFullVersion = await showFullVersionPrompt(
      context,
      feature: 'Clock tools',
    );
    if (wantsFullVersion && mounted) {
      await _openFullVersionPage();
    }
  }

  Future<void> _startClipboardChat() async {
    if (!isDeveloperBuild) {
      final wantsFullVersion = await showFullVersionPrompt(
        context,
        feature: 'Omoji Chat',
      );
      if (wantsFullVersion && mounted) {
        await _openFullVersionPage();
      }
      return;
    }

    setState(() {
      _chatInitialPrompt = _chatMessages.isEmpty
          ? _searchController.text.trim()
          : '';
      _isChatMode = true;
    });
  }

  Future<void> _exportChat() async {
    if (_chatMessages.isEmpty) return;
    try {
      final location = await getSaveLocation(
        suggestedName: 'omoji-chat.txt',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Text file', extensions: ['txt']),
        ],
      );
      if (location == null) return;

      final contents = _chatMessages
          .map(
            (message) =>
                '${message.role == ChatRole.user ? 'You' : 'Omoji'}:\n'
                '${message.text}',
          )
          .join('\n\n');
      await File(location.path).writeAsString(contents, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat exported to ${location.path}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export chat: $error')),
        );
      }
    }
  }

  Future<void> _openFullVersionPage() async {
    final uri = Uri.parse(fullVersionUrl);
    final command = Platform.isMacOS
        ? ('open', [uri.toString()])
        : Platform.isWindows
        ? ('rundll32', ['url.dll,FileProtocolHandler', uri.toString()])
        : ('xdg-open', [uri.toString()]);
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

  @override
  void onWindowFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedTab != 'clock') {
        _focusNode.requestFocus();
      }
    });
    _checkClipboard();
    _loadClipboardSettings();
  }

  @override
  void onWindowBlur() async {
    if (_isPastingSelection) return;
    // Keep Omoji open & visible as long as an alarm/timer is ringing or music is playing!
    if (AlarmService.activeRingingAlarm.value != null ||
        AlarmService.activeRingingTimer.value != null) {
      return;
    }
    await windowManager.hide();
    _searchController.clear();
    setState(() {
      _editingIndex = null;
    });
  }

  Future<void> _injectTextOrPaste(String text) async {
    if (!_autoPaste) {
      await LoggerService.info('Auto-paste skipped because it is disabled.');
      return;
    }

    if (Platform.isLinux) {
      // Keep the Linux fallback order in omoji_paste.py aligned with commit
      // 261a3f8: uinput, xdotool, wtype, ydotool, then direct text fallbacks.
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final home = Platform.environment['HOME'] ?? '';
        final scriptLocations = <String>[
          '$exeDir/lib/scripts/omoji_paste.py',
          '$home/.local/lib/omoji/lib/scripts/omoji_paste.py',
          'scripts/omoji_paste.py',
        ];
        for (final loc in scriptLocations) {
          if (File(loc).existsSync()) {
            final res = await Process.run(
              'python3',
              [loc, text],
            ).timeout(const Duration(seconds: 2));
            if (res.exitCode == 0) {
              await LoggerService.info(
                'Auto-paste command succeeded: omoji_paste.py ($loc)',
              );
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('omoji_paste.py error: $e');
      }

      final isWayland =
          Platform.environment['WAYLAND_DISPLAY']?.isNotEmpty == true ||
          Platform.environment['XDG_SESSION_TYPE'] == 'wayland';

      Future<bool> runPasteTool(
        String label,
        String executable,
        List<String> arguments,
      ) async {
        try {
          final result = await Process.run(
            executable,
            arguments,
          ).timeout(const Duration(seconds: 2));
          if (result.exitCode == 0) {
            await LoggerService.info('Auto-paste command succeeded: $label');
            return true;
          }
          await LoggerService.warn(
            'Auto-paste command failed: $label exited ${result.exitCode}: '
            '${result.stderr}'
                .trim(),
          );
          debugPrint(
            '$label exited ${result.exitCode}: ${result.stderr}'.trim(),
          );
        } on ProcessException {
          await LoggerService.warn(
            'Auto-paste command unavailable: $label is not installed or could not be started.',
          );
          debugPrint('$label is not installed or could not be started.');
        } on TimeoutException {
          await LoggerService.warn('Auto-paste command timed out: $label');
          debugPrint('$label timed out.');
        } catch (error) {
          await LoggerService.error('Auto-paste command failed: $label', error);
          debugPrint('$label failed: $error');
        }
        return false;
      }

      // On Wayland, xdotool can report success without sending keys to the
      // native target. Only use it on X11; ydotool needs the active daemon.
      final pasteCommands = isWayland
          ? <(String, String, List<String>)>[
              ('ydotool', 'ydotool', ['key', '29:1', '47:1', '47:0', '29:0']),
              ('wtype', 'wtype', ['-M', 'ctrl', '-k', 'v', '-m', 'ctrl']),
            ]
          : <(String, String, List<String>)>[
              ('xdotool', 'xdotool', ['key', '--clearmodifiers', 'ctrl+v']),
              ('wtype', 'wtype', ['-M', 'ctrl', '-k', 'v', '-m', 'ctrl']),
              ('ydotool', 'ydotool', ['key', '29:1', '47:1', '47:0', '29:0']),
            ];

      for (final (label, executable, arguments) in pasteCommands) {
        if (await runPasteTool(label, executable, arguments)) return;
      }

      await runPasteTool('wtype text fallback', 'wtype', ['--', text]);
      if (!isWayland) {
        await runPasteTool(
          'xdotool text fallback',
          'xdotool',
          ['type', '--clearmodifiers', text],
        );
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('osascript', [
          '-e',
          'tell application "System Events" to keystroke "v" using command down',
        ]);
      } catch (e) {
        debugPrint("macOS AppleScript paste error: $e");
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('powershell', [
          '-c',
          "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('^v')",
        ]);
      } catch (e) {
        debugPrint("Windows PowerShell paste error: $e");
      }
    }
  }

  void _handleEmojiSelection(String emoji) async {
    await Clipboard.setData(ClipboardData(text: emoji));
    _lastClipboardText = emoji;

    if (Platform.isLinux) {
      try {
        await Process.run('wl-copy', ['--', emoji]);
      } catch (_) {}
    }

    setState(() {
      _recentEmojis.remove(emoji);
      _recentEmojis.insert(0, emoji);
      if (_recentEmojis.length > 14) {
        _recentEmojis.removeLast();
      }
    });

    final isFloating = _isFloatingOverlayMode;
    final wordToClear = _globalPredictionWord;

    await _clearOverlayMode();
    await _dismissWindowForPaste();

    if (isFloating && wordToClear.isNotEmpty) {
      EmojiPredictionService.requestAutofillBackspaces(wordToClear.length);
    }

    try {
      await _injectTextOrPaste(emoji);
    } finally {
      _isPastingSelection = false;
    }
  }

  Future<void> _loadClipboardSettings() async {
    final settings = await AppSettings.loadSettings();
    if (!mounted) return;
    setState(() {
      _privateMode = settings['privateMode'] as bool? ?? false;
      _autoPaste = settings['autoPaste'] as bool? ?? true;
      _ignoreEmojisInClipboard =
          settings['ignoreEmojisInClipboard'] as bool? ?? true;
      _enableEmojiPredictions =
          settings['enableEmojiPredictions'] as bool? ?? true;
      final historyRaw = settings['clipboardHistory'] as List<dynamic>?;
      _clipboardHistory = (historyRaw ?? [])
          .map((item) => ClipboardItem.fromJson(item as Map<String, dynamic>))
          .toList();
      final alarmsRaw = settings['alarms'] as List<dynamic>?;
      _alarms = (alarmsRaw ?? [])
          .map((item) => AlarmItem.fromJson(item as Map<String, dynamic>))
          .toList();
      final todosRaw = settings['todos'] as List<dynamic>?;
      _todos = (todosRaw ?? [])
          .map((item) => TodoItem.fromJson(item as Map<String, dynamic>))
          .toList();
    });
    final customSoundPath = isDeveloperBuild
        ? settings['customAlarmSoundPath'] as String?
        : null;
    final savedUseSystemDefault = settings['useSystemDefaultSound'] as bool?;
    final useSystemDefault =
        !isDeveloperBuild ||
        (savedUseSystemDefault ??
            (customSoundPath == null || customSoundPath.isEmpty));
    final loopInterval = settings['audioLoopIntervalSeconds'] as int?;
    await AlarmService.init(
      _alarms,
      todos: _todos,
      customSoundPath: customSoundPath,
      useSystemDefault: useSystemDefault,
      loopIntervalSeconds: loopInterval,
      enableDucking: settings['enableAudioDucking'] as bool?,
    );

    final primaryTrigger = Platform.isWindows ? 'Super + Z' : 'Super + X';
    final secondaryTrigger =
        (settings['secondaryTrigger'] as String?) ?? 'Ctrl + Alt + O';
    await HotkeyService.registerTriggers(
      primaryTrigger: primaryTrigger,
      secondaryTrigger: secondaryTrigger,
    );
  }

  void _startClipboardMonitoring() {
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkClipboard();
    });
  }

  Future<void> _handleNativeMethodCall(MethodCall call) async {
    if (call.method == 'clipboardChanged') {
      await _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    if (_privateMode) return;
    if (_isCheckingClipboard) {
      _clipboardCheckPending = true;
      return;
    }
    _isCheckingClipboard = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final text = data.text!;
        if (text != _lastClipboardText) {
          _lastClipboardText = text;

          if (_ignoreEmojisInClipboard && _isEmojiOnly(text)) {
            return;
          }

          final existingIndex = _clipboardHistory.indexWhere(
            (item) => item.text == text,
          );
          if (existingIndex != -1) {
            final item = _clipboardHistory.removeAt(existingIndex);
            item.timestamp = DateTime.now().millisecondsSinceEpoch;
            _clipboardHistory.insert(0, item);
          } else {
            _clipboardHistory.insert(0, ClipboardItem(text: text));
            if (_clipboardHistory.length > 50) {
              int lastUnpinned = _clipboardHistory.lastIndexWhere(
                (item) => !item.isPinned,
              );
              if (lastUnpinned != -1) {
                _clipboardHistory.removeAt(lastUnpinned);
              } else {
                _clipboardHistory.removeLast();
              }
            }
          }

          _sortHistory();
          AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error checking clipboard: $e');
    } finally {
      _isCheckingClipboard = false;
      if (_clipboardCheckPending) {
        _clipboardCheckPending = false;
        unawaited(_checkClipboard());
      }
    }
  }

  void _sortHistory() {
    _clipboardHistory.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.timestamp.compareTo(a.timestamp);
    });
  }

  void _handleClipboardSelection(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _lastClipboardText = text;

    if (Platform.isLinux) {
      try {
        await Process.run('wl-copy', ['--', text]);
      } catch (_) {}
    }

    await _dismissWindowForPaste();
    try {
      await _injectTextOrPaste(text);
    } finally {
      _isPastingSelection = false;
    }
  }

  Future<void> _dismissWindowForPaste() async {
    _isPastingSelection = true;
    try {
      await windowManager.hide();
      _searchController.clear();
      // Auto-paste depends on the previously focused app regaining focus before
      // Ctrl+V; keep this delay when changing the dismissal/focus handoff logic.
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (error) {
      await LoggerService.warn(
        'Could not hand focus back before paste: $error',
      );
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  List<ClipboardItem> _filteredClipboardHistory() {
    if (_searchQuery.isEmpty) return _clipboardHistory;
    return _clipboardHistory
        .where((item) => item.text.toLowerCase().contains(_searchQuery))
        .toList();
  }

  void _saveEdit(int index, String val) {
    if (val.trim().isNotEmpty) {
      final filtered = _filteredClipboardHistory();
      final originalItem = filtered[index];
      final originalIndex = _clipboardHistory.indexOf(originalItem);

      setState(() {
        _clipboardHistory[originalIndex].text = val.trim();
        _clipboardHistory[originalIndex].timestamp =
            DateTime.now().millisecondsSinceEpoch;
        _editingIndex = null;
        _sortHistory();
      });
      AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
      _focusNode.requestFocus();
    }
  }

  void _togglePin(ClipboardItem item) {
    setState(() {
      item.isPinned = !item.isPinned;
      item.timestamp = DateTime.now().millisecondsSinceEpoch;
      _sortHistory();
    });
    AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
  }

  void _deleteItem(ClipboardItem item) {
    setState(() {
      _clipboardHistory.remove(item);
    });
    AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Clear History',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to clear your clipboard history? Pinned items will be kept.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _clipboardHistory.removeWhere((item) => !item.isPinned);
                });
                AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final inputBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    if (_isFloatingOverlayMode && _currentPredictions.isNotEmpty) {
      return Material(
        color: Colors.transparent,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _buildEmojiPredictionBar(isDark, textColor),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          KeyboardListener(
            focusNode: _keyboardFocusNode,
            autofocus: true,
            onKeyEvent: (KeyEvent event) {
              if (event is KeyDownEvent) {
                if (_editingIndex != null) return;

                if (event.logicalKey == LogicalKeyboardKey.escape) {
                  if (AlarmService.activeRingingAlarm.value != null ||
                      AlarmService.activeRingingTimer.value != null) {
                    AlarmService.stopRinging();
                    setState(() {});
                    return;
                  }
                  if (_searchController.text.isNotEmpty) {
                    _searchController.clear();
                    if (_selectedTab != 'clock') _focusNode.requestFocus();
                  } else {
                    windowManager.hide();
                  }
                  return;
                }

                if (_selectedTab == 'clock') return;

                if (_focusNode.hasFocus) return;

                final char = event.character;
                if (char != null &&
                    char.isNotEmpty &&
                    event.logicalKey != LogicalKeyboardKey.tab &&
                    event.logicalKey != LogicalKeyboardKey.enter) {
                  _focusNode.requestFocus();
                  _searchController.text = _searchController.text + char;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _searchController.text.length),
                  );
                } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
                  _focusNode.requestFocus();
                  if (_searchController.text.isNotEmpty) {
                    _searchController.text = _searchController.text.substring(
                      0,
                      _searchController.text.length - 1,
                    );
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _searchController.text.length),
                    );
                  }
                }
              }
            },
            child: ClipRRect(
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
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.5 : 0.2,
                        ),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TopBar(searchFocusNode: _focusNode),
                        ValueListenableBuilder<AlarmItem?>(
                          valueListenable: AlarmService.activeRingingAlarm,
                          builder: (context, activeAlarm, _) {
                            if (activeAlarm == null) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: Colors.redAccent,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.alarm_on_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'RINGING: ${activeAlarm.time} - ${activeAlarm.label}',
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      AlarmService.stopRinging();
                                      setState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.alarm_off_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'STOP ALARM',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        ValueListenableBuilder<String?>(
                          valueListenable: AlarmService.silencedAlarmNotice,
                          builder: (context, noticeText, _) {
                            if (noticeText == null || noticeText.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              margin: const EdgeInsets.only(top: 8, bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.notifications_off_rounded,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      noticeText,
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber,
                                      foregroundColor: Colors.black87,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      AlarmService.silencedAlarmNotice.value =
                                          null;
                                      setState(() {});
                                    },
                                    icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      'DISMISS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (!_isChatMode) ...[
                          const SizedBox(height: 12),
                          TabSwitcher(
                            selectedTab: _selectedTab,
                            onTabChanged: (tab) {
                              if (tab == 'clock' && !isDeveloperBuild) {
                                _showClockUpgradeDialog();
                                return;
                              }
                              setState(() {
                                _selectedTab = tab;
                                _editingIndex = null;
                                if (tab == 'clock') {
                                  _searchController.clear();
                                }
                              });
                              if (tab != 'clock') {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  _focusNode.requestFocus();
                                });
                              }
                            },
                            searchFocusNode: _focusNode,
                          ),
                        ],
                        if (_selectedTab != 'clock' && !_isChatMode) ...[
                          if (_enableEmojiPredictions &&
                              _currentPredictions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildEmojiPredictionBar(isDark, textColor),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            focusNode: _focusNode,
                            autofocus: true,
                            style: TextStyle(color: textColor),
                            onSubmitted: (val) {
                              if (_enableEmojiPredictions &&
                                  _currentPredictions.isNotEmpty) {
                                final topEmoji =
                                    _currentPredictions.first['char']!;
                                _handleEmojiSelection(topEmoji);
                                setState(() {
                                  _dismissedPredictionWord = null;
                                  _currentPredictions = [];
                                });
                              }
                            },
                            decoration: InputDecoration(
                              hintText: _selectedTab == 'emojis'
                                  ? 'Search emojis...'
                                  : 'Type here to search...',
                              hintStyle: TextStyle(
                                color: textColor.withValues(alpha: 0.35),
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              suffixIcon: _selectedTab == 'clipboard'
                                  ? IconButton(
                                      tooltip: 'Switch to Omoji chat',
                                      onPressed: _startClipboardChat,
                                      icon: const Icon(
                                        Icons.auto_awesome_rounded,
                                      ),
                                    )
                                  : null,
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: inputBorderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Expanded(
                          child: _isChatMode
                              ? ClipboardChatView(
                                  initialPrompt: _chatInitialPrompt,
                                  messages: _chatMessages,
                                  onBack: () {
                                    setState(() {
                                      _isChatMode = false;
                                    });
                                    _focusNode.requestFocus();
                                  },
                                  onExport: _exportChat,
                                )
                              : _selectedTab == 'clock'
                              ? ClockView(
                                  alarms: _alarms,
                                  onAlarmsChanged: (updated) {
                                    setState(() {
                                      _alarms = updated;
                                    });
                                  },
                                  todos: _todos,
                                  onTodosChanged: (updated) {
                                    setState(() {
                                      _todos = updated;
                                    });
                                  },
                                )
                              : _selectedTab == 'emojis'
                              ? EmojiView(
                                  searchQuery: _searchQuery,
                                  recentEmojis: _recentEmojis,
                                  onSelectEmoji: _handleEmojiSelection,
                                )
                              : ClipboardView(
                                  items: _filteredClipboardHistory(),
                                  searchQuery: _searchQuery,
                                  privateMode: _privateMode,
                                  editingIndex: _editingIndex,
                                  editController: _editController,
                                  searchFocusNode: _focusNode,
                                  onSelectText: _handleClipboardSelection,
                                  onSaveEdit: _saveEdit,
                                  onStartEdit: (idx) {
                                    setState(() {
                                      _editingIndex = idx;
                                      _editController.text =
                                          _filteredClipboardHistory()[idx].text;
                                    });
                                  },
                                  onTogglePin: _togglePin,
                                  onDeleteItem: _deleteItem,
                                  onTogglePrivateMode: (val) {
                                    setState(() {
                                      _privateMode = val;
                                    });
                                    AppSettings.saveSettings(privateMode: val);
                                  },
                                  onClearHistory: _clearHistory,
                                  onStartChat: _startClipboardChat,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildRingingOverlay(isDark, textColor),
        ],
      ),
    );
  }

  String _formatOvertimeDisplay(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '+${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '+${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildRingingOverlay(bool isDark, Color textColor) {
    return Positioned.fill(
      child: Stack(
        children: [
          ValueListenableBuilder<AlarmItem?>(
            valueListenable: AlarmService.activeRingingAlarm,
            builder: (context, alarm, _) {
              return ValueListenableBuilder<String?>(
                valueListenable: AlarmService.activeRingingTimer,
                builder: (context, timerLabel, _) {
                  if (alarm == null && timerLabel == null) {
                    return const SizedBox.shrink();
                  }

                  final isAlarm = alarm != null;
                  final accentColor = Theme.of(context).colorScheme.primary;

                  return ValueListenableBuilder<int>(
                    valueListenable: TimerService.overtimeNotifier,
                    builder: (context, overtimeSecs, _) {
                      final overtimeStr = overtimeSecs > 0
                          ? _formatOvertimeDisplay(overtimeSecs)
                          : '00:00';
                      final titleText = isAlarm ? alarm.time : overtimeStr;
                      final labelText = isAlarm
                          ? alarm.label
                          : (timerLabel ?? 'Timer Finished!');
                      final subText = isAlarm
                          ? (overtimeSecs > 0
                                ? 'Ringing for $overtimeStr • ${alarm.repeatSummary}'
                                : (alarm.repeatDays.isEmpty
                                      ? 'One-time Alarm (auto-disables when stopped)'
                                      : 'Recurring Alarm (${alarm.repeatSummary})'))
                          : (overtimeSecs > 0
                                ? 'Ringing unattended for $overtimeStr'
                                : 'Timer Alert');

                      return Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2C2C2C)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: accentColor,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.4),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.alarm_on_rounded,
                                      size: 44,
                                      color: accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    titleText,
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      color: accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    labelText,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    subText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withValues(alpha: 0.65),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accentColor,
                                        foregroundColor: Colors.white,
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        AlarmService.stopRinging();
                                        setState(() {});
                                      },
                                      icon: const Icon(
                                        Icons.alarm_off_rounded,
                                        size: 22,
                                      ),
                                      label: Text(
                                        isAlarm ? 'STOP ALARM' : 'STOP TIMER',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omoji/models/alarm_item.dart';
import 'package:omoji/models/clipboard_item.dart';
import 'package:omoji/services/alarm_service.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/widgets/clipboard_view.dart';
import 'package:omoji/widgets/clock_view.dart';
import 'package:omoji/widgets/emoji_view.dart';
import 'package:omoji/widgets/tab_switcher.dart';
import 'package:omoji/widgets/top_bar.dart';
import 'package:window_manager/window_manager.dart';

class OmojiHomeScreen extends StatefulWidget {
  const OmojiHomeScreen({super.key});

  @override
  State<OmojiHomeScreen> createState() => _OmojiHomeScreenState();
}

class _OmojiHomeScreenState extends State<OmojiHomeScreen> with WindowListener {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  String _searchQuery = "";

  final List<String> _recentEmojis = [];
  bool _privateMode = false;
  bool _autoPaste = true;
  bool _ignoreEmojisInClipboard = true;

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
  String _selectedTab = 'clipboard';
  String? _lastClipboardText;
  Timer? _clipboardTimer;
  int? _editingIndex;
  final TextEditingController _editController = TextEditingController();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });

    _loadClipboardSettings();
    _startClipboardMonitoring();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedTab != 'clock') {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _searchController.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    _clipboardTimer?.cancel();
    _editController.dispose();
    AlarmService.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedTab != 'clock') {
        _focusNode.requestFocus();
      }
    });
    _checkClipboard();
  }

  @override
  void onWindowBlur() async {
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

  void _injectTextOrPaste(String text) async {
    if (!_autoPaste) return;

    if (Platform.isLinux) {
      // 1. Try kernel uinput via python3 evdev (Universal for native Wayland & X11)
      try {
        final res = await Process.run('python3', [
          '-c',
          '''import evdev, time
from evdev import UInput, ecodes as e
ui = UInput()
time.sleep(0.05)
for k in [e.KEY_LEFTMETA, e.KEY_RIGHTMETA, e.KEY_LEFTALT, e.KEY_RIGHTALT, e.KEY_LEFTSHIFT, e.KEY_RIGHTSHIFT, e.KEY_LEFTCTRL, e.KEY_RIGHTCTRL]:
    ui.write(e.EV_KEY, k, 0)
ui.syn()
time.sleep(0.02)
ui.write(e.EV_KEY, e.KEY_LEFTCTRL, 1)
ui.write(e.EV_KEY, e.KEY_V, 1)
ui.syn()
time.sleep(0.03)
ui.write(e.EV_KEY, e.KEY_V, 0)
ui.write(e.EV_KEY, e.KEY_LEFTCTRL, 0)
ui.syn()
ui.close()'''
        ]);
        if (res.exitCode == 0) return;
      } catch (e) {
        debugPrint("python3 evdev paste error: $e");
      }

      // 2. Try xdotool key --clearmodifiers ctrl+v
      try {
        final res = await Process.run('xdotool', ['key', '--clearmodifiers', 'ctrl+v']);
        if (res.exitCode == 0) return;
      } catch (e) {
        debugPrint("xdotool key paste error: $e");
      }

      // 3. Try wtype paste (Ctrl+V) or direct text injection
      try {
        final res = await Process.run('wtype', ['-M', 'ctrl', '-k', 'v', '-m', 'ctrl']);
        if (res.exitCode == 0) return;
      } catch (e) {
        debugPrint("wtype paste error: $e");
      }

      try {
        final res = await Process.run('wtype', ['--', text]);
        if (res.exitCode == 0) return;
      } catch (e) {
        debugPrint("wtype text error: $e");
      }

      // 4. Try ydotool key 29:1 47:1 47:0 29:0 (Ctrl+V)
      try {
        final res = await Process.run('ydotool', ['key', '29:1', '47:1', '47:0', '29:0']);
        if (res.exitCode == 0) return;
      } catch (e) {
        debugPrint("ydotool paste error: $e");
      }

      // 5. Try dotool key ctrl+v
      try {
        final process = await Process.start('dotool', []);
        process.stdin.writeln('key ctrl+v');
        await process.stdin.close();
        final exitCode = await process.exitCode;
        if (exitCode == 0) return;
      } catch (e) {
        debugPrint("dotool paste error: $e");
      }

      // 6. Fallback: xdotool type
      try {
        await Process.run('xdotool', ['type', '--clearmodifiers', text]);
      } catch (e) {
        debugPrint("xdotool type fallback error: $e");
      }
    } else if (Platform.isMacOS) {
      try {
        await Process.run('osascript', [
          '-e',
          'tell application "System Events" to keystroke "v" using command down'
        ]);
      } catch (e) {
        debugPrint("macOS AppleScript paste error: $e");
      }
    } else if (Platform.isWindows) {
      try {
        await Process.run('powershell', [
          '-c',
          "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('^v')"
        ]);
      } catch (e) {
        debugPrint("Windows PowerShell paste error: $e");
      }
    }
  }

  void _handleEmojiSelection(String emoji) async {
    await Clipboard.setData(ClipboardData(text: emoji));
    _lastClipboardText = emoji;

    setState(() {
      _recentEmojis.remove(emoji);
      _recentEmojis.insert(0, emoji);
      if (_recentEmojis.length > 14) {
        _recentEmojis.removeLast();
      }
    });

    await windowManager.hide();
    _searchController.clear();

    await Future.delayed(const Duration(milliseconds: 220));
    _injectTextOrPaste(emoji);
  }

  Future<void> _loadClipboardSettings() async {
    final settings = await AppSettings.loadSettings();
    setState(() {
      _privateMode = settings['privateMode'] as bool? ?? false;
      _autoPaste = settings['autoPaste'] as bool? ?? true;
      _ignoreEmojisInClipboard = settings['ignoreEmojisInClipboard'] as bool? ?? true;
      final historyRaw = settings['clipboardHistory'] as List<dynamic>?;
      if (historyRaw != null) {
        _clipboardHistory = historyRaw
            .map((item) => ClipboardItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      final alarmsRaw = settings['alarms'] as List<dynamic>?;
      if (alarmsRaw != null) {
        _alarms = alarmsRaw
            .map((item) => AlarmItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    });
    final customSoundPath = settings['customAlarmSoundPath'] as String?;
    AlarmService.init(_alarms, customSoundPath: customSoundPath);
  }

  void _startClipboardMonitoring() {
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkClipboard();
    });
  }

  Future<void> _checkClipboard() async {
    if (_privateMode) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final text = data.text!;
        if (text != _lastClipboardText) {
          _lastClipboardText = text;

          if (_ignoreEmojisInClipboard && _isEmojiOnly(text)) {
            return;
          }

          final existingIndex =
              _clipboardHistory.indexWhere((item) => item.text == text);
          if (existingIndex != -1) {
            final item = _clipboardHistory.removeAt(existingIndex);
            item.timestamp = DateTime.now().millisecondsSinceEpoch;
            _clipboardHistory.insert(0, item);
          } else {
            _clipboardHistory.insert(0, ClipboardItem(text: text));
            if (_clipboardHistory.length > 50) {
              int lastUnpinned =
                  _clipboardHistory.lastIndexWhere((item) => !item.isPinned);
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

    await windowManager.hide();
    _searchController.clear();

    await Future.delayed(const Duration(milliseconds: 220));
    _injectTextOrPaste(text);
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title:
              const Text('Clear History', style: TextStyle(color: Colors.white)),
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
              child:
                  const Text('Clear', style: TextStyle(color: Colors.redAccent)),
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
                _searchController.text = _searchController.text
                    .substring(0, _searchController.text.length - 1);
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
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
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
                        if (activeAlarm == null) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.redAccent, width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.alarm_on_rounded, color: Colors.redAccent, size: 20),
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
                                icon: const Icon(Icons.alarm_off_rounded, size: 16),
                                label: const Text(
                                  'STOP ALARM',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
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
                        if (noticeText == null || noticeText.isEmpty) return const SizedBox.shrink();
                        return Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            border: Border.all(color: Colors.amber, width: 1.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_off_rounded, color: Colors.amber, size: 20),
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
                                  AlarmService.silencedAlarmNotice.value = null;
                                  setState(() {});
                                },
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                                label: const Text(
                                  'DISMISS',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TabSwitcher(
                      selectedTab: _selectedTab,
                      onTabChanged: (tab) {
                        setState(() {
                          _selectedTab = tab;
                          _editingIndex = null;
                          if (tab == 'clock') {
                            _searchController.clear();
                          }
                        });
                        if (tab != 'clock') {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _focusNode.requestFocus();
                          });
                        }
                      },
                      searchFocusNode: _focusNode,
                    ),
                    if (_selectedTab != 'clock') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: _selectedTab == 'emojis'
                              ? 'Search emojis...'
                              : 'Type here to search...',
                          hintStyle: TextStyle(
                              color: textColor.withValues(alpha: 0.35)),
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: inputBorderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                                width: 1.5),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Expanded(
                      child: _selectedTab == 'clock'
                          ? ClockView(
                              alarms: _alarms,
                              onAlarmsChanged: (updated) {
                                setState(() {
                                  _alarms = updated;
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
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
                  final titleText = isAlarm ? alarm.time : '00:00';
                  final labelText = isAlarm ? alarm.label : timerLabel ?? 'Timer Finished!';
                  final subText = isAlarm
                      ? (alarm.repeatDays.isEmpty
                          ? 'One-time Alarm (auto-disables when stopped)'
                          : 'Recurring Alarm (${alarm.repeatSummary}) • Stays active for next time')
                      : 'Timer Alert';

                  return Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.teal, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.4),
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
                                  color: Colors.teal.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.alarm_on_rounded,
                                  size: 44,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                titleText,
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
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
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    AlarmService.stopRinging();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.alarm_off_rounded, size: 22),
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
          ),
        ],
      ),
    );
  }
}

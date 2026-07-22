// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omoji/models/clipboard_item.dart';
import 'package:omoji/services/app_settings.dart';
import 'package:omoji/widgets/clipboard_view.dart';
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
  List<ClipboardItem> _clipboardHistory = [];
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
      if (mounted) {
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
    super.dispose();
  }

  @override
  void onWindowFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
    _checkClipboard();
  }

  @override
  void onWindowBlur() async {
    await windowManager.hide();
    _searchController.clear();
    setState(() {
      _editingIndex = null;
    });
  }

  void _injectTextOrPaste(String text) async {
    if (Platform.isLinux) {
      try {
        await Process.run('wtype', [text]);
      } catch (e) {
        debugPrint("Wayland 'wtype' text injection tool error: $e");
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

    await Future.delayed(const Duration(milliseconds: 150));
    _injectTextOrPaste(emoji);
  }

  Future<void> _loadClipboardSettings() async {
    final settings = await AppSettings.loadSettings();
    setState(() {
      _privateMode = settings['privateMode'] as bool? ?? false;
      final historyRaw = settings['clipboardHistory'] as List<dynamic>?;
      if (historyRaw != null) {
        _clipboardHistory = historyRaw
            .map((item) => ClipboardItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    });
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

    await Future.delayed(const Duration(milliseconds: 150));
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
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (_editingIndex != null) return;

            if (event.logicalKey == LogicalKeyboardKey.escape) {
              if (_searchController.text.isNotEmpty) {
                _searchController.clear();
                _focusNode.requestFocus();
              } else {
                windowManager.hide();
              }
              return;
            }

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
                    const SizedBox(height: 12),
                    TabSwitcher(
                      selectedTab: _selectedTab,
                      onTabChanged: (tab) {
                        setState(() {
                          _selectedTab = tab;
                          _editingIndex = null;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _focusNode.requestFocus();
                        });
                      },
                      searchFocusNode: _focusNode,
                    ),
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
                        prefixIcon: const Icon(Icons.search, color: Colors.teal),
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
                              color: Colors.teal.withValues(alpha: 0.6),
                              width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _selectedTab == 'emojis'
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
    );
  }
}

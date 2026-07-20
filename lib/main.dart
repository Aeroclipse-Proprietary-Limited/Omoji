// lib/main.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui'; // Required for ImageFilter.blur
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omoji/emoji%20map.dart';
import 'package:omoji/settings.dart';
import 'package:window_manager/window_manager.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

class ClipboardItem {
  String text;
  String? imagePath;
  bool isPinned;
  int timestamp;

  ClipboardItem({
    required this.text,
    this.imagePath,
    this.isPinned = false,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {
    'text': text,
    'imagePath': imagePath,
    'isPinned': isPinned,
    'timestamp': timestamp,
  };

  factory ClipboardItem.fromJson(Map<String, dynamic> json) => ClipboardItem(
    text: json['text'] as String? ?? '',
    imagePath: json['imagePath'] as String?,
    isPinned: json['isPinned'] as bool? ?? false,
    timestamp: json['timestamp'] as int?,
  );
}

class AppSettings {
  static File get _configFile {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.config/omoji/settings.json');
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    try {
      final file = _configFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
    return {};
  }

  static Future<void> saveSettings({
    ThemeMode? theme,
    List<ClipboardItem>? clipboardHistory,
    bool? privateMode,
  }) async {
    try {
      final file = _configFile;
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      
      Map<String, dynamic> current = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          current = jsonDecode(content) as Map<String, dynamic>;
        } catch (_) {}
      }

      if (theme != null) {
        String themeName;
        switch (theme) {
          case ThemeMode.light: themeName = 'light'; break;
          case ThemeMode.dark: themeName = 'dark'; break;
          case ThemeMode.system: themeName = 'system'; break;
        }
        current['theme'] = themeName;
      }
      if (clipboardHistory != null) {
        current['clipboardHistory'] = clipboardHistory.map((item) => item.toJson()).toList();
      }
      if (privateMode != null) {
        current['privateMode'] = privateMode;
      }

      await file.writeAsString(jsonEncode(current));
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Load the persisted settings
  final settings = await AppSettings.loadSettings();
  
  ThemeMode initialTheme = ThemeMode.dark;
  final themeName = settings['theme'] as String?;
  if (themeName == 'light') initialTheme = ThemeMode.light;
  if (themeName == 'system') initialTheme = ThemeMode.system;
  themeNotifier.value = initialTheme;

  // Listen to changes to save the theme dynamically
  themeNotifier.addListener(() {
    AppSettings.saveSettings(theme: themeNotifier.value);
  });

  WindowOptions windowOptions = const WindowOptions(
    size: Size(450, 550),
    center: true,
    backgroundColor: Colors.transparent, // Crucial for letting desktop background show through blur
    skipTaskbar: true, 
    titleBarStyle: TitleBarStyle.hidden, 
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Set the Linux window icon here
    try {
      await windowManager.setIcon('lib/assets/imgs/app-logo.jpg');
    } catch (e) {
      debugPrint('Failed to set window icon: $e');
    }
    
    await windowManager.setAsFrameless();
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
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Omoji',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: Colors.transparent, // Let our glass canvas handle the background color
          ),
          darkTheme: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: Colors.transparent, // Let our glass canvas handle the background color
          ),
          home: const OmojiHomeScreen(),
        );
      },
    );
  }
}

class OmojiHomeScreen extends StatefulWidget {
  const OmojiHomeScreen({super.key});

  @override
  State<OmojiHomeScreen> createState() => _OmojiHomeScreenState();
}

class _OmojiHomeScreenState extends State<OmojiHomeScreen> with WindowListener {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = "";
  
  // Track recently clicked emojis purely in runtime memory
  final List<String> _recentEmojis = [];

  // Clipboard Manager State
  bool _privateMode = false;
  List<ClipboardItem> _clipboardHistory = [];
  String _selectedTab = 'clipboard'; // 'clipboard' or 'emojis'
  String? _lastClipboardText;
  List<int>? _lastClipboardImageBytes;
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

    _initCacheDirectory();
    _loadClipboardSettings();
    _startClipboardMonitoring();
  }

  @override
  void dispose() {
    windowManager.removeListener(this); 
    _searchController.dispose();
    _focusNode.dispose();
    _clipboardTimer?.cancel();
    _editController.dispose();
    super.dispose();
  }

  @override
  void onWindowFocus() {
    setState(() {
      _focusNode.requestFocus();
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

  void _handleEmojiSelection(String emoji) async {
    await Clipboard.setData(ClipboardData(text: emoji));
    _lastClipboardText = emoji; // Prevent immediately adding it to clipboard history
    _lastClipboardImageBytes = null;
    
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
    
    try {
      await Process.run('wtype', [emoji]);
    } catch (e) {
      debugPrint("Wayland 'wtype' text injection tool error: $e");
    }
  }

  Future<void> _initCacheDirectory() async {
    final home = Platform.environment['HOME'] ?? '';
    final cacheDir = Directory('$home/.cache/omoji');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
  }

  Future<void> _loadClipboardSettings() async {
    try {
      final settings = await AppSettings.loadSettings();
      setState(() {
        _privateMode = settings['privateMode'] as bool? ?? false;
        final historyRaw = settings['clipboardHistory'] as List<dynamic>?;
        if (historyRaw != null) {
          _clipboardHistory = historyRaw
              .map((item) => ClipboardItem.fromJson(Map<String, dynamic>.from(item as Map)))
              .toList();
        }
      });
    } catch (e) {
      debugPrint('Failed to load clipboard settings: $e');
    }
  }

  void _startClipboardMonitoring() {
    _clipboardTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      await _checkClipboard();
    });
  }

  bool _areBytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    if (a.length < 1000) {
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
    } else {
      for (int i = 0; i < 500; i++) {
        if (a[i] != b[i]) return false;
      }
      for (int i = a.length - 500; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
    }
    return true;
  }

  Future<void> _checkClipboard() async {
    if (_privateMode) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.isNotEmpty) {
        final text = data.text!;
        if (text != _lastClipboardText) {
          _lastClipboardText = text;
          _lastClipboardImageBytes = null;
          _addTextClipboardItem(text);
        }
      } else {
        // Text is empty/null, check for Wayland image/png clipboard data
        final imageResult = await Process.run('wl-paste', ['-t', 'image/png'], stdoutEncoding: null);
        if (imageResult.exitCode == 0) {
          final bytes = imageResult.stdout as List<int>;
          if (bytes.isNotEmpty) {
            if (_lastClipboardImageBytes == null || !_areBytesEqual(bytes, _lastClipboardImageBytes!)) {
              _lastClipboardImageBytes = bytes;
              _lastClipboardText = null;
              await _addImageClipboardItem(bytes);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking clipboard: $e');
    }
  }

  void _addTextClipboardItem(String text) {
    final existingIndex = _clipboardHistory.indexWhere((item) => item.text == text && item.imagePath == null);
    if (existingIndex != -1) {
      final item = _clipboardHistory.removeAt(existingIndex);
      item.timestamp = DateTime.now().millisecondsSinceEpoch;
      _clipboardHistory.insert(0, item);
    } else {
      _clipboardHistory.insert(0, ClipboardItem(text: text));
      _capHistorySize();
    }
    _sortHistory();
    AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
    if (mounted) setState(() {});
  }

  Future<void> _addImageClipboardItem(List<int> bytes) async {
    final home = Platform.environment['HOME'] ?? '';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final imagePath = '$home/.cache/omoji/image_$timestamp.png';

    try {
      await File(imagePath).writeAsBytes(bytes);
      _clipboardHistory.insert(0, ClipboardItem(text: '', imagePath: imagePath));
      _capHistorySize();
      _sortHistory();
      AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Failed to save screenshot cache: $e');
    }
  }

  void _capHistorySize() {
    if (_clipboardHistory.length > 50) {
      int lastUnpinned = _clipboardHistory.lastIndexWhere((item) => !item.isPinned);
      if (lastUnpinned != -1) {
        final removed = _clipboardHistory.removeAt(lastUnpinned);
        if (removed.imagePath != null) {
          _deleteCacheFile(removed.imagePath!);
        }
      } else {
        final removed = _clipboardHistory.removeLast();
        if (removed.imagePath != null) {
          _deleteCacheFile(removed.imagePath!);
        }
      }
    }
  }

  void _deleteCacheFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  void _sortHistory() {
    _clipboardHistory.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.timestamp.compareTo(a.timestamp);
    });
  }

  void _handleClipboardSelection(ClipboardItem item) async {
    if (item.imagePath != null) {
      final file = File(item.imagePath!);
      if (await file.exists()) {
        await Process.run('sh', ['-c', 'wl-copy -t image/png < "${item.imagePath}"']);
        try {
          _lastClipboardImageBytes = await file.readAsBytes();
          _lastClipboardText = null;
        } catch (_) {}
      }
      await windowManager.hide();
      _searchController.clear();

      await Future.delayed(const Duration(milliseconds: 150));
      try {
        await Process.run('wtype', ['-M', 'ctrl', 'v']);
      } catch (e) {
        debugPrint("wtype clipboard image paste error: $e");
      }
    } else {
      await Clipboard.setData(ClipboardData(text: item.text));
      _lastClipboardText = item.text;
      _lastClipboardImageBytes = null;
      
      await windowManager.hide();
      _searchController.clear();

      await Future.delayed(const Duration(milliseconds: 150));
      try {
        await Process.run('wtype', [item.text]);
      } catch (e) {
        debugPrint("Wayland 'wtype' text injection tool error: $e");
      }
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
        _clipboardHistory[originalIndex].timestamp = DateTime.now().millisecondsSinceEpoch;
        _editingIndex = null;
        _sortHistory();
      });
      AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
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
      if (item.imagePath != null) {
        _deleteCacheFile(item.imagePath!);
      }
    });
    AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2E2E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Clear History', style: TextStyle(color: Colors.white)),
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
                  final removedItems = _clipboardHistory.where((item) => !item.isPinned).toList();
                  for (final item in removedItems) {
                    if (item.imagePath != null) {
                      _deleteCacheFile(item.imagePath!);
                    }
                  }
                  _clipboardHistory.removeWhere((item) => !item.isPinned);
                });
                AppSettings.saveSettings(clipboardHistory: _clipboardHistory);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final activeBg = Colors.teal;
    final inactiveBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? activeBg : inactiveBg,
            border: Border.all(color: isActive ? Colors.teal : borderColor),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : textColor,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClipboardSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);
    final filtered = _filteredClipboardHistory();

    return Column(
      children: [
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty ? 'Clipboard history is empty' : 'No matching items found',
                    style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 13),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isEditing = _editingIndex == index;
                    final isImage = item.imagePath != null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        border: Border.all(color: cardBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              item.isPinned ? Icons.push_pin : Icons.circle,
                              size: item.isPinned ? 12 : 8,
                              color: item.isPinned ? Colors.teal : textColor.withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: isImage
                                  ? InkWell(
                                      onTap: () => _handleClipboardSelection(item),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(item.imagePath!),
                                          height: 100,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              height: 100,
                                              color: Colors.red.withValues(alpha: 0.1),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Image not found',
                                                style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  : (isEditing
                                      ? TextField(
                                          controller: _editController,
                                          autofocus: true,
                                          style: TextStyle(color: textColor, fontSize: 13),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onSubmitted: (val) => _saveEdit(index, val),
                                        )
                                      : InkWell(
                                          onTap: () => _handleClipboardSelection(item),
                                          child: Text(
                                            item.text.replaceAll('\n', ' '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: textColor, fontSize: 13),
                                          ),
                                        )),
                            ),
                            const SizedBox(width: 8),
                            if (isEditing)
                              IconButton(
                                icon: const Icon(Icons.check_rounded, size: 16),
                                color: Colors.teal,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _saveEdit(index, _editController.text),
                              )
                            else ...[
                              if (!isImage) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  color: textColor.withValues(alpha: 0.6),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () {
                                    setState(() {
                                      _editingIndex = index;
                                      _editController.text = item.text;
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                              ],
                              IconButton(
                                icon: Icon(
                                  item.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                  size: 16,
                                ),
                                color: item.isPinned ? Colors.teal : textColor.withValues(alpha: 0.6),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _togglePin(item),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                color: textColor.withValues(alpha: 0.6),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _handleClipboardSelection(item),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                color: Colors.redAccent.withValues(alpha: 0.7),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _deleteItem(item),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 12),
        Divider(color: isDark ? Colors.white10 : Colors.black12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _privateMode ? Icons.security : Icons.security_outlined,
            color: _privateMode ? Colors.teal : textColor.withValues(alpha: 0.7),
            size: 20,
          ),
          title: Text(
            'Private mode',
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          trailing: Switch(
            value: _privateMode,
            activeTrackColor: Colors.teal.withValues(alpha: 0.5),
            activeThumbColor: Colors.teal,
            onChanged: (val) {
              setState(() {
                _privateMode = val;
              });
              AppSettings.saveSettings(privateMode: val);
            },
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.delete_sweep_outlined,
            color: Colors.redAccent.withValues(alpha: 0.8),
            size: 20,
          ),
          title: Text(
            'Clear history',
            style: TextStyle(
              color: Colors.redAccent.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: _clearHistory,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final inputBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

    return Scaffold(
      body: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), // Deep underlying glossy blur
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              // Multi-stop glass gradient layout mimicking high-spec specular reflections
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- New Feature: Top Bar with Title, Settings, and Close ---
                  Row(
                    children: [
                      // App Title acts as an anchor for the top left
                      Expanded(
                        child: Text(
                          'Omoji',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        color: textColor.withValues(alpha: 0.7),
                        splashRadius: 20,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: textColor.withValues(alpha: 0.7),
                        splashRadius: 20,
                        onPressed: () async => await windowManager.minimize(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // --- Tab switcher ---
                  Row(
                    children: [
                      _buildTabButton(
                        label: 'Clipboard',
                        icon: Icons.assignment_outlined,
                        isActive: _selectedTab == 'clipboard',
                        onTap: () {
                          setState(() {
                            _selectedTab = 'clipboard';
                            _editingIndex = null;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildTabButton(
                        label: 'Emojis',
                        icon: Icons.emoji_emotions_outlined,
                        isActive: _selectedTab == 'emojis',
                        onTap: () {
                          setState(() {
                            _selectedTab = 'emojis';
                            _editingIndex = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // High contrast input surface matching the acrylic paneling look
                  TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: _selectedTab == 'emojis' ? 'Search emojis...' : 'Type here to search...',
                      hintStyle: TextStyle(color: textColor.withValues(alpha: 0.35)),
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
                        borderSide: BorderSide(color: Colors.teal.withValues(alpha: 0.6), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: _selectedTab == 'emojis'
                        ? ListView(
                            children: [
                              if (_searchQuery.isEmpty && _recentEmojis.isNotEmpty)
                                _buildRecentEmojisSection(),
                              ..._buildEmojiSections(),
                            ],
                          )
                        : _buildClipboardSection(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Dashboard grid containing frequently used symbols
  Widget _buildRecentEmojisSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Icon(Icons.history, size: 16, color: textColor.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                'Recently Used', 
                style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.4), fontWeight: FontWeight.bold)
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 55,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: _recentEmojis.length,
          itemBuilder: (context, index) {
            final emoji = _recentEmojis[index];
            return InkWell(
              onTap: () => _handleEmojiSelection(emoji),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 24, fontFamilyFallback: ['NotoColorEmoji'])),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ],
    );
  }

  List<Widget> _buildEmojiSections() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03);
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);

    List<Widget> sections = [];
    
    fullEmojiData.forEach((category, emojis) {
      final filteredEmojis = emojis.where((e) {
        return e['name']!.contains(_searchQuery) || e['char']!.contains(_searchQuery);
      }).toList();

      if (filteredEmojis.isNotEmpty) {
        sections.add(
          Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
            child: Text(
              category, 
              style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.4), fontWeight: FontWeight.bold)
            ),
          ),
        );

        sections.add(
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 55,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: filteredEmojis.length,
            itemBuilder: (context, index) {
              final emoji = filteredEmojis[index];
              return InkWell(
                onTap: () => _handleEmojiSelection(emoji['char']!),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    // Inner glossy card layer: transparent background tile
                    color: cardBg,
                    border: Border.all(color: cardBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji['char']!, style: const TextStyle(fontSize: 24, fontFamilyFallback: ['NotoColorEmoji'])),
                ),
              );
            },
          ),
        );
      }
    });
    return sections;
  }
}
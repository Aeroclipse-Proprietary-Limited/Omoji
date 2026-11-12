import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

/// Owns Omoji's persistent tray icon and its small set of global actions.
class TrayService {
  static TrayIcon? _trayIcon;
  static MenuItem? _privateModeItem;
  static MenuItem? _chatItem;
  static bool _privateModeEnabled = false;
  static bool _superAgentsEnabled = false;
  static Future<void> Function()? _onShow;
  static void Function()? _onPrivateMode;
  static void Function()? _onChat;
  static Future<void> Function()? _onExit;

  static void initialize({
    required Future<void> Function() onShow,
    required void Function() onPrivateMode,
    required void Function() onChat,
    required Future<void> Function() onExit,
    required bool privateModeEnabled,
    required bool superAgentsEnabled,
  }) {
    if (_trayIcon != null) return;
    _onShow = onShow;
    _onPrivateMode = onPrivateMode;
    _onChat = onChat;
    _onExit = onExit;
    _privateModeEnabled = privateModeEnabled;
    _superAgentsEnabled = superAgentsEnabled;

    final tray = TrayIcon.create();
    final menu = Menu.create();
    if (tray == null || menu == null) return;

    _trayIcon = tray;
    // Flutter URL-encodes spaces in bundled asset filenames on disk.
    tray.icon = ImageAsset.fromAsset('lib/assets/imgs/App%20logo%20(dark).png');
    tray.setTooltip('Omoji');
    // StatusNotifierItem panels expose a menu on ordinary clicks only when
    // the item advertises itself as a menu.
    tray.setContextMenuTrigger(ContextMenuTrigger.clicked);

    final exitItem = _item('Exit', MenuItemType.normal);
    exitItem.addListener((event) {
      if (event is MenuItemClickedEvent) _onExit?.call();
    });
    menu.addItem(exitItem);
    menu.addSeparator();

    final privateItem = _item('Enable Private Mode', MenuItemType.checkbox);
    _privateModeItem = privateItem;
    privateItem.state = _privateModeEnabled
        ? MenuItemState.checked
        : MenuItemState.unchecked;
    privateItem.addListener((event) {
      if (event is MenuItemClickedEvent) {
        _onPrivateMode?.call();
      }
    });
    menu.addItem(privateItem);

    final updateItem = _item('Check for updates', MenuItemType.normal);
    updateItem.addListener((event) {
      if (event is MenuItemClickedEvent) _openSnapStore();
    });
    menu.addItem(updateItem);

    final chatItem = _item('Chat', MenuItemType.normal);
    _chatItem = chatItem;
    chatItem.isEnabled = _superAgentsEnabled;
    chatItem.addListener((event) {
      if (event is MenuItemClickedEvent && _superAgentsEnabled) {
        _onChat?.call();
        _onShow?.call();
      }
    });
    menu.addItem(chatItem);

    tray.setContextMenu(menu);
    tray.setVisible(true);
  }

  static MenuItem _item(String label, MenuItemType type) =>
      MenuItem.createWithLabelAndType(label, type)!;

  static void updatePrivateMode(bool enabled) {
    _privateModeEnabled = enabled;
    final item = _privateModeItem;
    if (item != null) {
      item.state = enabled ? MenuItemState.checked : MenuItemState.unchecked;
    }
  }

  static void updateSuperAgents(bool enabled) {
    _superAgentsEnabled = enabled;
    _chatItem?.isEnabled = enabled;
  }

  static Future<void> _openSnapStore() async {
    final command = Platform.isMacOS
        ? ('open', ['https://snapcraft.io/omoji'])
        : Platform.isWindows
        ? (
            'rundll32',
            ['url.dll,FileProtocolHandler', 'https://snapcraft.io/omoji'],
          )
        : ('xdg-open', ['https://snapcraft.io/omoji']);
    try {
      await Process.run(command.$1, command.$2);
    } on ProcessException {
      // Keep the tray usable when a desktop browser opener is unavailable.
    }
  }

  static Future<void> dispose() async {
    _trayIcon?.dispose();
    _trayIcon = null;
    _privateModeItem = null;
    _chatItem = null;
  }
}

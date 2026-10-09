import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var windowObserver: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    windowObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didBecomeKeyNotification,
      object: nil,
      queue: .main
    ) { notification in
      (notification.object as? NSWindow)?
        .standardWindowButton(.closeButton)?
        .isHidden = true
    }
    NSApp.windows.forEach { window in
      window.standardWindowButton(.closeButton)?.isHidden = true
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

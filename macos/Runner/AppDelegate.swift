import Cocoa
import FlutterMacOS

class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    if let window = mainFlutterWindow {
        let
            frame =
                NSScreen.main!.frame
        window.setFrame(frame, display: true)
        window.minSize = NSSize(width: 400, height: 600)
    }
    super.applicationDidFinishLaunching(aNotification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}

@main
class Main: NSApplication {
    let
        strongDelegate
            = AppDelegate()

    override init() {
        super.init()
        self.delegate = strongDelegate
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

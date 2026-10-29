import Cocoa
import FlutterMacOS

private let minimumContentSize = NSSize(width: 900, height: 600)

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.contentMinSize = minimumContentSize

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

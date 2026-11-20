import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    private var pendingLinks: [String] = []
    private var linksTaken = false

    override func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
        super.applicationWillFinishLaunching(notification)
    }

    @objc private func handleGetURL(
        _ event: NSAppleEventDescriptor,
        withReplyEvent _: NSAppleEventDescriptor
    ) {
        guard let link = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else {
            return
        }
        if linksTaken {
            NotificationCenter.default.post(name: .uniPulseApplicationOpenLink, object: link)
        } else {
            pendingLinks.append(link)
        }
    }

    @objc func takePendingLinks() -> [String] {
        linksTaken = true
        defer { pendingLinks = [] }
        return pendingLinks
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        NotificationCenter.default.post(name: .uniPulseApplicationShouldTerminate, object: nil)
        return .terminateCancel
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
      return true
    }

    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .uniPulseApplicationReopen, object: nil)
        return false
    }
}

// rust_api's window module observes these; the names are fixed there.
extension Notification.Name {
    static let uniPulseApplicationShouldTerminate = Notification.Name("UniPulseApplicationShouldTerminate")
    static let uniPulseApplicationReopen = Notification.Name("UniPulseApplicationReopen")
    static let uniPulseApplicationOpenLink = Notification.Name("UniPulseApplicationOpenLink")
}

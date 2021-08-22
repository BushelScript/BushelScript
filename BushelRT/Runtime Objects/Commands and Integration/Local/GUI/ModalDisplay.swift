import Cocoa

func displayModally(window: NSWindow) {
//    NSApplication.shared.activate(ignoringOtherApps: true)
    let lastKeyWindow = NSApplication.shared.keyWindow
    defer {
//        appDeactivationObserver.lastActivatedApplication.activate()
        lastKeyWindow?.makeKey()
    }
    
    var closeObservation: Any?
    closeObservation = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { notification in
        NotificationCenter.default.removeObserver(closeObservation!)
        
        NSApplication.shared.stopModal()
    }
    
    NSApplication.shared.runModal(for: window)
}

private var appDeactivationObserver = AppDeactivationObserver()

// Adapted from https://stackoverflow.com/a/25212722/5390105
private class AppDeactivationObserver: NSObject {
    
    var lastActivatedApplication: NSRunningApplication = .current
    
    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationDidDeactivate(_:)), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
    }
    
    @objc func applicationDidDeactivate(_ notification: NSNotification!) {
        lastActivatedApplication = notification.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
    }
    
}

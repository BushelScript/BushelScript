import Cocoa

func displayWindowAndBlockUntilClosed<WC: NSWindowController>(makeWindowController: () -> WC) -> WC {
    let sema = DispatchSemaphore(value: 0)
    
    var lastKeyWindow: NSWindow?
    defer {
        //        appDeactivationObserver.lastActivatedApplication.activate()
        if let lastKeyWindow = lastKeyWindow {
            executeSyncOnMainThread {
                lastKeyWindow.makeKey()
            }
        }
    }
    
    var wc: WC!
    executeSyncOnMainThread {
        wc = makeWindowController()
        guard let window = wc.window else {
            return
        }
        
        //    NSApplication.shared.activate(ignoringOtherApps: true)
        lastKeyWindow = NSApplication.shared.keyWindow
        
        var closeObservation: Any?
        closeObservation = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { notification in
            NotificationCenter.default.removeObserver(closeObservation!)
            
            sema.signal()
        }
        
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    sema.wait()
    return wc
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

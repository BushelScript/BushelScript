import Cocoa

func display(window: NSWindow, then completion: @escaping () -> Void = {}) {
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
        NSApp.activate(ignoringOtherApps: true)
    }

    window.center()
    window.makeKeyAndOrderFront(nil)
    
    var observation: Any?
    observation = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil) { notification in
        NotificationCenter.default.removeObserver(observation!)
        
        completion()
        
        (NSApp.delegate as! AppDelegate).lastActivatedApplication.activate()
    }
}

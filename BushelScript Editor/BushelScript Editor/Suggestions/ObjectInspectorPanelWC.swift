// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import KVODelegate

class ObjectInspectorPanelWC: NSWindowController, NSWindowDelegate {
    
    @IBOutlet var containerView: NSView!
    
    private var parentWindow: NSWindow?
    
    static func instantiate(for object: ObjectInspectable, attachedTo parentWindow: NSWindow? = nil) -> ObjectInspectorPanelWC {
        _ = notificationDelegate
        let wc = ObjectInspectorPanelWC(windowNibName: "ObjectInspectorPanelWC")
        let vc = ObjectInspectorVC.instantiate(for: object)
        wc.contentViewController = vc
        wc.window?.contentView = vc.view
        
        if let parentWindow = parentWindow {
            wc.attach(to: parentWindow)
        } else {
            wc.detach()
        }
        
        return wc
    }
    
    func attach(to parentWindow: NSWindow) {
        self.parentWindow = parentWindow
        
        guard let window = self.window else {
            return
        }
        window.styleMask.remove(.closable)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    func detach() {
        parentWindow = nil
        
        guard let window = self.window else {
            return
        }
        window.styleMask.insert(.closable)
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }
    
    @objc dynamic var isWindowVisible: Bool {
        get {
            window?.isVisible ?? false
        }
        set {
            window?.setIsVisible(newValue)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        willChangeValue(for: \.isWindowVisible)
        DispatchQueue.main.async {
            self.didChangeValue(for: \.isWindowVisible)
        }
    }
    
}

extension ObjectInspectorPanelWC: KVONotificationDelegator {
    
    private static var notificationDelegate = KVONotificationDelegate(forClass: ObjectInspectorPanelWC.self)
    
    static func configKVONotificationDelegate(_ delegate: KVONotificationDelegate) {
        delegate.key(#keyPath(ObjectInspectorPanelWC.isWindowVisible), dependsUponKeyPaths: [
            #keyPath(ObjectInspectorPanelWC.window),
            #keyPath(ObjectInspectorPanelWC.window.isVisible)
        ])
    }
    
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        notificationDelegate.keyPathsForValuesAffectingValue(forKey: key)
    }
    
}

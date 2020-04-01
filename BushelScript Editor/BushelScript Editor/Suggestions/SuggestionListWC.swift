// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa

class SuggestionListWC: NSWindowController, NSWindowDelegate {
    
    public static func instantiate() -> SuggestionListWC {
        return NSStoryboard(name: "SuggestionList", bundle: nil).instantiateInitialController() as! SuggestionListWC
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.delegate = self
        (window as? NSPanel)?.isFloatingPanel = true
    }
    
    private var inactiveOpacity: Float?
    
    func windowDidBecomeKey(_ notification: Notification) {
        guard let layer = contentViewController?.view.layer else {
            return
        }
        inactiveOpacity = layer.opacity
        layer.opacity = 1.0
    }
    
    func windowDidResignKey(_ notification: Notification) {
        resetOpacity()
    }
    
    func windowWillClose(_ notification: Notification) {
        resetOpacity()
    }
    
    func resetOpacity() {
        guard let inactiveOpacity = inactiveOpacity else {
            return
        }
        contentViewController?.view.layer?.opacity = inactiveOpacity
    }
    
}

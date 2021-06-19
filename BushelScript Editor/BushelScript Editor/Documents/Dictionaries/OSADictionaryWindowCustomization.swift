// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa

extension NSWindowController {
    
    @objc dynamic func TJC_windowDidLoad() {
        TJC_windowDidLoad() // Swizzled in ObjC
        
        guard self is OSADictionaryWindowController else {
            return
        }
        
        // These don't seem to work on their own anyway,
        // so disabling them does less harm than good
        if let toolbar = window?.toolbar {
            for _ in 0..<toolbar.items.count {
                toolbar.removeItem(at: 0)
            }
            toolbar.isVisible = false
        }
    }
    
}

// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import os.log
import Carbon.HIToolbox.Events

private let log = OSLog(subsystem: logSubsystem, category: #file)

class EditorTextView: NSTextView {
    
    override func keyDown(with event: NSEvent) {
        if event.type == .keyDown, event.keyCode == kVK_Escape {
            complete(nil)
        } else {
            super.keyDown(with: event)
        }
    }
    
}

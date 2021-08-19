import AppKit
import os.log
import Carbon.HIToolbox.Events

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

class EditorTextView: NSTextView {
    
    override func keyDown(with event: NSEvent) {
        if event.type == .keyDown, event.keyCode == kVK_Escape {
            complete(nil)
        } else {
            super.keyDown(with: event)
        }
    }
    
}

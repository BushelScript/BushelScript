import AppKit
import os

private let log = OSLog(subsystem: logSubsystem, category: "InlineErrorView")

final class InlineErrorView: NSView {
    
    override func awakeFromNib() {
        guard let layer = layer else {
            return os_log("View layer is nil! The view will not look right.", log: log)
        }
        layer.backgroundColor = NSColor(named: "ErrorInlineViewColor")!.cgColor
        layer.cornerRadius = 6.0
    }
    
}

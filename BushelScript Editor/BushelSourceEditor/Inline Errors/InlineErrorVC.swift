import AppKit
import os

private let log = OSLog(subsystem: logSubsystem, category: "InlineErrorVC")

class InlineErrorVC: NSViewController {
    
    init() {
        super.init(nibName: nil, bundle: Bundle(for: Self.self))
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
}

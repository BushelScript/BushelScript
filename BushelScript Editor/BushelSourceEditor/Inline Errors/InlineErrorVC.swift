import AppKit
import os

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

class InlineErrorVC: NSViewController {
    
    @IBOutlet weak var toggleExpandedButton: NSButton!
    @IBOutlet weak var textField: NSTextField!
    
    init() {
        super.init(nibName: nil, bundle: Bundle(for: Self.self))
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    var isExpanded = true {
        didSet {
            textField.isHidden = !isExpanded
        }
    }
    
    @IBAction
    func takeIsExpandedValue(from sender: NSButton!) {
        isExpanded = (sender.state == .on)
    }
    
}

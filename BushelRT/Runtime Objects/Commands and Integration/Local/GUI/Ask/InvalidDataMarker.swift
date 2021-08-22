// Originally from defaults-edit

import Cocoa

// Enable to auto-hide the marker when its control's text changes,
// regardless of its validity.
private let autoHideWhenTextChanges: Bool = false

extension NSControl {
    
    private static var invalidDataMarkerAssociationKey: Int = 0
    @IBOutlet var invalidDataMarker: InvalidDataMarker? {
        get {
            return objc_getAssociatedObject(self, &NSControl.invalidDataMarkerAssociationKey) as? InvalidDataMarker
        }
        set {
            objc_setAssociatedObject(self, &NSControl.invalidDataMarkerAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
}

class InvalidDataMarker: NSObject, NSPopoverDelegate {
    
    // InvalidDataMarker.xib
    @IBOutlet var messageView: NSView!
    @IBOutlet var imageView: NSImageView!
    
    // Client nibs
    @IBOutlet weak var control: NSControl!
    
    @objc dynamic var errorString: String = ""
    
    private lazy var messageVC: NSViewController = {
        let vc = NSViewController()
        vc.view = messageView
        return vc
    }()
    
    override init() {
        super.init()
        loadNib()
    }
    
    override func awakeFromNib() {
        if control == nil {
            // Awoken from InvalidDataMarker.nib
        } else {
            // Awoken from client nib
            addImageView()
            registerForControlNotifications()
        }
    }
    
    deinit {
        hide()
        removeImageView()
    }
    
    private func loadNib() {
        Bundle(for: InvalidDataMarker.self).loadNibNamed("InvalidDataMarker", owner: self, topLevelObjects: nil)
    }
    
    private lazy var popover: NSPopover = {
        let popover = NSPopover()
        popover.delegate = self
        popover.contentViewController = messageVC
        popover.behavior = .semitransient
        return popover
    }()
    
    private var justShown: Bool = false
    
    func show() {
        justShown = true
        popover.show(relativeTo: .zero, of: control, preferredEdge: .maxX)
        imageView.isHidden = false
    }
    
    func hide() {
        popover.close()
        imageView.isHidden = true
    }
    
    private func addImageView() {
        guard control != nil else { return }
        control.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        control.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4).isActive = true
        control.centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
    }
    
    private func removeImageView() {
        imageView.removeFromSuperview()
    }
    
    private func registerForControlNotifications() {
        if autoHideWhenTextChanges {
            NotificationCenter.default.addObserver(self, selector: #selector(controlTextDidChange(_:)), name: NSControl.textDidChangeNotification, object: control)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(controlTextDidEndEditing(_:)), name: NSControl.textDidEndEditingNotification, object: control)
        
    }
    
    @objc func controlTextDidChange(_ notification: Notification) {
        if autoHideWhenTextChanges {
            if !justShown.tryReset() {
                hide()
            }
        }
    }
    
    @objc func controlTextDidEndEditing(_ notification: Notification) {
        popover.close()
    }
    
}

func exchange<T>(_ location: inout T, with newValue: T) -> T {
    let oldValue = location
    location = newValue
    return oldValue
}

extension Bool {
    
    mutating func trySet() -> Bool {
        return !exchange(&self, with: true)
    }
    
    mutating func tryReset() -> Bool {
        return exchange(&self, with: false)
    }
    
}

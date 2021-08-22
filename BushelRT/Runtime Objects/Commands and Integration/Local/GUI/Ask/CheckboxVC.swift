import Cocoa

final class CheckboxVC: NSViewController {
    
    init() {
        super.init(nibName: nil, bundle: Bundle(for: Self.self))
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBOutlet var checkbox: NSButton!
    
    override var title: String? {
        didSet {
            checkbox.title = self.title ?? ""
        }
    }
    
    @objc dynamic var value: Bool = false
    
}

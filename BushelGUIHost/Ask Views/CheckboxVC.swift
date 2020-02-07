import Cocoa

class CheckboxVC: NSViewController {
    
    @IBOutlet var checkbox: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    override var title: String? {
        didSet {
            checkbox.title = self.title ?? ""
        }
    }
    
    @objc dynamic var value: Bool = false
    
}

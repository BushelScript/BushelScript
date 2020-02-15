import Cocoa

final class CheckboxVC: NSViewController {
    
    @IBOutlet var checkbox: NSButton!
    
    override var title: String? {
        didSet {
            checkbox.title = self.title ?? ""
        }
    }
    
    @objc dynamic var value: Bool = false
    
}

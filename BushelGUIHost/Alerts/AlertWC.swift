import Cocoa

final class AlertWC: NSWindowController {
    
    @objc dynamic var heading: String?
    @objc dynamic var message: String?
    
    var response: String?
    
    @IBAction func buttonClicked(_ sender: NSButton) {
        response = sender.title
        close()
    }
    
}

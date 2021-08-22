import Cocoa

final class AlertWC: NSWindowController {
    
    @IBOutlet weak var messageTextView: NSTextView!
    
    var standardHeight: CGFloat = 300
    override func awakeFromNib() {
        guard let window = window else {
            return
        }
        standardHeight = window.frame.height
    }
    
    @objc dynamic var heading: String?
    @objc dynamic var message: String? {
        didSet {
            // Adjust window height to accomodate message text,
            // up to the screen's safe height limit.
            // (Any further text will be scrollable.)
            if let message = message, let window = window {
                let messageTextHeight = (message as NSString).size(withAttributes: messageTextView.typingAttributes).height
                let screenHeight = window.screen?.visibleFrame.height ?? standardHeight
                let newWindowHeight = min(standardHeight + messageTextHeight, screenHeight)
                let newWindowFrame = CGRect(
                    origin: window.frame.origin,
                    size: CGSize(
                        width: window.frame.width,
                        height: newWindowHeight
                    )
                )
                window.setFrame(newWindowFrame, display: true)
            }
        }
    }
    
    var response: String?
    
    @IBAction func buttonClicked(_ sender: NSButton) {
        response = sender.title
        close()
    }
    
}

import Cocoa

final class AskWC: NSWindowController {
    
    @IBOutlet weak var embedView: NSView!
    
    func embed(viewController vc: NSViewController) {
        contentViewController?.addChild(vc)
        embedView.addSubview(vc.view)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        vc.view.leadingAnchor.constraint(equalTo: embedView.leadingAnchor).isActive = true
        vc.view.trailingAnchor.constraint(equalTo: embedView.trailingAnchor).isActive = true
        vc.view.topAnchor.constraint(equalTo: embedView.topAnchor).isActive = true
        vc.view.bottomAnchor.constraint(equalTo: embedView.bottomAnchor).isActive = true
        vc.view.setContentHuggingPriority(.required, for: .vertical)
        vc.view.setContentHuggingPriority(.required, for: .horizontal)
    }
    
    @objc dynamic var prompt: String = ""
    
}

extension NSWindow {
    
    @IBAction func close(_ sender: Any?) {
        if let wc = windowController {
            wc.close()
        } else {
            close()
        }
    }
    
}

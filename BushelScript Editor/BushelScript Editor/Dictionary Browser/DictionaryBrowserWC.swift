// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Bushel

class DictionaryBrowserWC: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        setTitle(for: nil)
        tie(to: self, [
            KeyValueObservation(NSApplication.shared, \.keyWindow, handler: { [weak self] app, change in
                guard let self = self else {
                    return
                }
                if
                    let document = NSApplication.shared.keyWindow?.windowController?.document as? Document,
                    let rootTerm = document.program?.rootTerm
                {
                    (self.contentViewController as? DictionaryBrowserVC)?.rootTerm = rootTerm
                    self.setTitle(for: document)
                }
            })
        ])
    }
    
    func setTitle(for document: Document?) {
        guard let window = window else {
            return
        }
        var title = "Dictionary Browser"
        if let document = document {
            title += " – " + document.displayName
        }
        window.title = title
    }
    
}

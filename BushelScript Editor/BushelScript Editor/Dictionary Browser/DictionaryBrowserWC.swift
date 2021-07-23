// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Bushel

class DictionaryBrowserWC: NSWindowController {
    
    @IBOutlet var documentMenuDelegate: DictionaryBrowserDocumentMenuDelegate!
    
    @IBOutlet weak var documentPUB: NSPopUpButton!
    
    @IBOutlet var documentPUBMenu: NSMenu!
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // For some reason, when a menu is embedded in a popup button
        // in a toolbar item, the delegate connection doesn't seem to
        // make it through nib decoding
        documentPUBMenu.delegate = documentMenuDelegate
        
        selectFrontDocument()
        tie(to: self, [
            KeyValueObservation(NSDocumentController.shared, \.documents, options: [.initial], handler: { [weak self] _, _ in
                self?.updateDocumentMenu()
            })
        ])
    }
    
    func selectFrontDocument() {
        scriptDocument = NSApplication.shared.orderedDocuments.first as? Document
    }
    
    func updateDocumentMenu() {
        documentMenuDelegate.menuNeedsUpdate(documentPUBMenu)
    }
    
    var scriptDocument: Document? {
        didSet {
            if let rootTerm = scriptDocument?.program?.rootTerm {
                (self.contentViewController as? DictionaryBrowserVC)?.rootTerm = rootTerm
            }
            
            if let window = window {
                var title = "Dictionary Browser"
                if let document = scriptDocument {
                    title += " – " + document.displayName
                }
                window.title = title
            }
        }
    }
    
    @objc func setScriptDocument(_ sender: NSMenuItem?) {
        self.scriptDocument = sender?.representedObject as? Document
    }
    
}

class DictionaryBrowserDocumentMenuDelegate: NSObject, NSMenuDelegate {
    
    @IBOutlet var windowController: DictionaryBrowserWC!
    
    @IBOutlet var documentPUB: NSPopUpButton?
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        var itemTitleToSelect: String?
        
        for document in NSDocumentController.shared.documents {
            let item = menu.addItem(title: document.displayName, action: #selector(DictionaryBrowserWC.setScriptDocument(_:)))
            item.representedObject = document
            if document === windowController?.scriptDocument {
                item.state = .on
                itemTitleToSelect = document.displayName
            }
        }
        
        if let itemTitleToSelect = itemTitleToSelect {
            documentPUB?.selectItem(withTitle: itemTitleToSelect)
        }
    }
    
}

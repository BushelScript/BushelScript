// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Bushel

class DocumentWC: NSWindowController {
    
    @IBOutlet var languageMenuDelegate: CurrentDocumentLanguageMenuDelegate!
    @IBOutlet var indentationMenuDelegate: IndentationMenuDelegate!
    
    @IBOutlet weak var languagePUB: NSPopUpButton!
    
    @IBOutlet var languagePUBMenu: NSMenu!
    
    override func windowDidLoad() {
        // For some reason, when a menu is embedded in a popup button
        // in a toolbar item, the delegate connection doesn't seem to
        // make it through nib decoding
        languagePUBMenu.delegate = languageMenuDelegate
    }
    
    func updateLanguageMenu() {
        languageMenuDelegate.menuNeedsUpdate(languagePUBMenu)
    }
    
}

class CurrentDocumentLanguageMenuDelegate: NSObject, NSMenuDelegate {
    
    @IBOutlet var windowController: NSWindowController!
    
    @IBOutlet var languagePUB: NSPopUpButton?
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        var itemTitleToSelect: String?
        
        for module in LanguageModule.allModuleDescriptors() {
            let item = menu.addItem(title: module.localizedName, action: #selector(DocumentVC.setLanguage(_:)))
            item.representedObject = module
            if module.identifier == currentDocument?.languageID {
                item.state = .on
                itemTitleToSelect = module.localizedName
            }
        }
        
        if let itemTitleToSelect = itemTitleToSelect {
            languagePUB?.selectItem(withTitle: itemTitleToSelect)
        }
    }
    
    private var currentDocument: Document? {
        windowController.document as? Document
    }
    
}

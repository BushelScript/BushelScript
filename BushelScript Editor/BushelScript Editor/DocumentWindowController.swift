//
//  DocumentWindowController.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 30-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa
import BushelLanguage

class DocumentWindowController: NSWindowController {
    
    @IBOutlet var languageMenuDelegate: CurrentDocumentLanguageMenuDelegate!
    
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
        
        for module in LanguageModule.validModules() {
            let item = menu.addItem(withTitle: module.localizedName, action: #selector(DocumentViewController.setLanguage(_:)), keyEquivalent: "")
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

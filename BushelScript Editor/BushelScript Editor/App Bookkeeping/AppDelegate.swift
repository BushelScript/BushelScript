//
//  AppDelegate.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 25-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa
import Defaults
import BushelLanguage

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var defaultsObservations: [DefaultsObservation] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        defaultsObservations += [
            Defaults.observe(.liveParsingEnabled) { change in
                if !change.newValue {
                    Defaults[.smartSuggestionsEnabled] = false
                    Defaults[.liveErrorsEnabled] = false
                }
            },
            Defaults.observe(.privacyFetchAppDataForSmartSuggestions) { change in
                Defaults[.smartSuggestionKinds]["ScriptingObjects"] = false
            }
        ]
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        
        for observation in defaultsObservations {
            observation.invalidate()
        }
        UserDefaults.standard.synchronize()
    }
    
    @IBOutlet var runItem: NSMenuItem! {
        didSet {
            // I have tried repeatedly over the course of many months to try
            // and get menu items with key equiv ⌘R to work
            // If someone can help me with this, PLEASE let me know!
//            runItem.keyEquivalent = "r"
//            runItem.keyEquivalentModifierMask = [.command]
        }
    }
    
}

class ScriptLanguageMenuDelegate: NSObject, NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        for module in LanguageModule.validModules() {
            let item = menu.addItem(withTitle: module.localizedName, action: #selector(DocumentViewController.setLanguage(_:)), keyEquivalent: "")
            item.representedObject = module
            if module.identifier == currentDocument?.languageID {
                item.state = .on
            }
        }
    }
    
    private var currentDocument: Document? {
        return NSApplication.shared.orderedDocuments.first as? Document
    }
    
}

// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Defaults
import Bushel
import os

private let log = OSLog(subsystem: logSubsystem, category: "App delegate")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var defaultsObservations: [DefaultsObservation] = []
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        LanguageModule.appBundle = Bundle.main
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let runningCount = NSDocumentController.shared.documents.filter({ ($0 as? Document)?.isRunning ?? false }).count
        if runningCount == 0 {
            return .terminateNow
        } else {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "Are you sure you want to quit BushelScript Editor?"
            alert.informativeText = "Quitting will terminate \(runningCount) running script\(runningCount == 1 ? "" : "s")."
            alert.addButton(withTitle: "Quit and Terminate \(runningCount) Script\(runningCount == 1 ? "" : "s")")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                return .terminateNow
            case .alertSecondButtonReturn:
                return .terminateCancel
            default:
                os_log("Unknown termination modal response %d", log: log, response.rawValue)
                return .terminateNow
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        for observation in defaultsObservations {
            observation.invalidate()
        }
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
    
    @IBAction func chooseAndOpenDictionaries(_ sender: Any?) {
        OSADictionary.choose()
    }
    
}

class ScriptLanguageMenuDelegate: NSObject, NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        for module in LanguageModule.allModuleDescriptors() {
            let item = menu.addItem(withTitle: module.localizedName, action: #selector(DocumentVC.setLanguage(_:)), keyEquivalent: "")
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

// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Defaults
import Bushel
import BushelSourceEditor
import os

private let log = OSLog(subsystem: logSubsystem, category: "App delegate")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserInterfaceValidations {
    
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
            Defaults.observe(.privacyFetchAppForSmartSuggestions) { change in
                Defaults[.smartSuggestionKinds]["ScriptingObjects"] = false
            }
        ]
        tie(to: self, [
            NotificationObservation(.documentSelectedExpressions) { [weak self] (_: Document?, _) in
                self?.calculateCanRevealSelectionInDictionaryBrowser()
            },
            NotificationObservation(NSWindow.didBecomeKeyNotification) { [weak self] (_: NSWindow?, _) in
                self?.calculateCanRevealSelectionInDictionaryBrowser()
            }
        ])
        calculateCanRevealSelectionInDictionaryBrowser()
    }
    
    var runningDocuments: Set<Document> = []
    
    func applicationShouldTerminate(_ app: NSApplication) -> NSApplication.TerminateReply {
        if runningDocuments.isEmpty {
            return .terminateNow
        } else {
            let runningCount = runningDocuments.count
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.alertStyle = .informational
                alert.messageText = "Quit and terminate scripts?"
                alert.informativeText = "This will terminate \(runningCount) running script\(runningCount == 1 ? "" : "s")."
                alert.addButton(withTitle: "Quit and Terminate \(runningCount) Script\(runningCount == 1 ? "" : "s")")
                alert.addButton(withTitle: "Cancel")
                let response = alert.runModal()
                switch response {
                case .alertFirstButtonReturn:
                    app.reply(toApplicationShouldTerminate: true)
                case .alertSecondButtonReturn:
                    app.reply(toApplicationShouldTerminate: false)
                default:
                    os_log("Unknown termination modal response %d", log: log, response.rawValue)
                    app.reply(toApplicationShouldTerminate: true)
                }
            }
            return .terminateLater
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
    
    lazy var dictionaryBrowserWC: DictionaryBrowserWC = NSStoryboard(name: "DictionaryBrowser", bundle: nil).instantiateInitialController() as! DictionaryBrowserWC
    
    @IBAction func showDictionaryBrowserForCurrentDocument(_ sender: Any?) {
        dictionaryBrowserWC.selectFrontDocument()
        dictionaryBrowserWC.showWindow(nil)
    }
    
    func revealInDictionaryBrowser(_ term: Term) {
        showDictionaryBrowserForCurrentDocument(nil)
        dictionaryBrowserWC.reveal(term)
    }
    
    @IBAction func revealSelectionInDictionaryBrowser(_ sender: Any?) {
        guard let document = NSApplication.shared.orderedDocuments.first as? Document else {
            return
        }
        for expression in document.selectedExpressions {
            if let termForDocs = expression.termForDocs() {
                revealInDictionaryBrowser(termForDocs)
                break
            }
        }
    }
    
    private func calculateCanRevealSelectionInDictionaryBrowser() {
        canRevealSelectionInDictionaryBrowser = {
            if let document = NSApplication.shared.orderedDocuments.first as? Document {
                for expression in document.selectedExpressions {
                    if expression.termForDocs() != nil {
                        return true
                    }
                }
            }
            return false
        }()
    }
    
    @objc dynamic var canRevealSelectionInDictionaryBrowser: Bool = false
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        switch item.action {
        case #selector(revealSelectionInDictionaryBrowser(_:)):
            return canRevealSelectionInDictionaryBrowser
        default:
            return true
        }
    }
    
}

class ScriptLanguageMenuDelegate: NSObject, NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        for module in LanguageModule.allModuleDescriptors() {
            menu.addItem(
                title: module.localizedName,
                action: #selector(DocumentVC.setLanguage(_:)),
                representedObject: module,
                isOn: module.identifier == currentDocument()?.languageID
            )
        }
    }
    
}

class IndentationMenuDelegate: NSObject, NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        menu.addItem(title: "Spaces", action: #selector(DocumentVC.setIndentType(_:)), tag: IndentMode.Character.space.rawValue, isOn: currentDocument()?.indentMode.character == .space)
        menu.addItem(title: "Tabs", action: #selector(DocumentVC.setIndentType(_:)), tag: IndentMode.Character.tab.rawValue, isOn: currentDocument()?.indentMode.character == .tab)
        
        menu.addItem(NSMenuItem.separator())
        
        for width in 1...8 {
            menu.addItem(title: String(width), action: #selector(DocumentVC.setIndentWidth(_:)), tag: width, isOn: currentDocument()?.indentMode.width == width)
        }
    }
    
}

private func currentDocument() -> Document? {
    NSApplication.shared.orderedDocuments.first as? Document
}

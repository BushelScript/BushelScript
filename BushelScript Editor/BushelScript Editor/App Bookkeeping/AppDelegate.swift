// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import Defaults
import Bushel
import os

private let log = OSLog(subsystem: logSubsystem, category: "App delegate")

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var defaultsObservations: [DefaultsObservation] = []
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        DispatchQueue.main.async {
            self.verifyAEPermission()
        }
        
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
    
    private func verifyAEPermission() {
        guard !((ProcessInfo.processInfo.environment["BUSHEL_AUTOMATED_TESTING_MODE"] as NSString?)?.boolValue ?? false) else {
            // Don't ruin automated tests
            return
        }
        if Defaults[.hasBushelGUIHostEventPermission] == .current {
            // Should already have permission
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "BushelScript Editor needs to be able to communicate with BushelGUIHost."
        alert.informativeText = "In the forthcoming dialog, please select “OK”. If no dialog appears, go to System Preferences → Security & Privacy → Privacy → Automation and check the “BushelGUIHost” box under “BushelScript Editor”."
        alert.runModal()
        
        if !determineGUIHostEventPermission() {
            let alert = NSAlert()
            alert.messageText = "BushelScript Editor needs to be able to communicate with BushelGUIHost."
            alert.informativeText = "Please go to System Preferences → Security & Privacy → Privacy → Automation and check the “BushelGUIHost” box under “BushelScript Editor,” then click OK."
            alert.runModal()
            
            if !determineGUIHostEventPermission() {
                let alert = NSAlert()
                alert.messageText = "BushelScript Editor needs to be able to communicate with BushelGUIHost."
                alert.informativeText = "BushelScript Editor still doesn’t seem to have permission. Try reinstalling if this persists."
                alert.runModal()
                return
            }
        }
        
        // Permission was granted
        Defaults[.hasBushelGUIHostEventPermission] = .current
    }
    
    private func determineGUIHostEventPermission() -> Bool {
        let guiHostBundleID = "com.justcheesy.BushelGUIHost"
        
        NSWorkspace.shared.launchApplication(withBundleIdentifier: guiHostBundleID, options: [.withoutActivation], additionalEventParamDescriptor: nil, launchIdentifier: nil)
        
        // AEDeterminePermissionToAutomateTarget just hangs for me; don't ask why.
        // UGHHHH fine Apple, you've left me no choice but to do it the dumb way:
        var errorInfo: NSDictionary?
        NSAppleScript(source: "missing value 1 of app id \"\(guiHostBundleID)\"")!.executeAndReturnError(&errorInfo)
        
        if let errorInfo = errorInfo {
            guard let errorNumber = errorInfo[NSAppleScript.errorNumber] as? Int else {
                return false
            }
            return !(
                errorNumber == errAETargetAddressNotPermitted ||
                errorNumber == errAEEventNotPermitted ||
                errorNumber == errAEEventWouldRequireUserConsent ||
                errorNumber == procNotFound
            )
        } else {
            return true
        }
    }
    
}

class ScriptLanguageMenuDelegate: NSObject, NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        for module in LanguageModule.validModules() {
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

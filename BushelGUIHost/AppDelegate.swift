import Cocoa
import SwiftAutomation
import Bushel
import BushelRT
import os

private let log = OSLog(subsystem: logSubsystem, category: "AppleEvents")

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!).count > 1 {
            (notification.object as! NSApplication).terminate(self)
        }
    }
    
    private var appDeactivationObserver: AppDeactivationObserver!
    
    var lastActivatedApplication: NSRunningApplication {
        appDeactivationObserver.lastActivatedApplication
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        for eventID in GUIEventID.allCases {
            let handler: Selector = {
                switch eventID {
                case .ask:
                    return #selector(handleAsk)
                }
            }()
            
            NSAppleEventManager.shared().setEventHandler(self, andSelector: handler, forEventClass: guiEventClass, andEventID: eventID.rawValue)
        }
        
        appDeactivationObserver = AppDeactivationObserver()
    }
    
}

// Adapted from https://stackoverflow.com/a/25212722/5390105
private class AppDeactivationObserver: NSObject {
    
    var lastActivatedApplication: NSRunningApplication = .current
    
    override init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationDidDeactivate(_:)), name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
    }

    @objc func applicationDidDeactivate(_ notification: NSNotification!) {
        lastActivatedApplication = notification.userInfo![NSWorkspace.applicationUserInfoKey] as! NSRunningApplication
    }
    
}

// MARK: AppleEvent handlers
extension AppDelegate {
    
    @objc func handleAsk(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        let rt = RTInfo()
        let arguments = getArguments(from: event)
        
        let typeArg = arguments[ParameterInfo(.GUI_ask_dataType)]
        let type = (typeArg?.coerce() as? RT_Class)?.value ??
            rt.type(forUID: TypedTermUID(TypeUID.string))
        
        let promptArg = arguments[ParameterInfo(.direct)]
        let prompt = (promptArg?.coerce() as? RT_String)?.value ??
            promptArg.map { String(describing: $0) } ??
            "Please enter a value:"
        
        let titleArg = arguments[ParameterInfo(.GUI_ask_title)]
        let title = (titleArg?.coerce() as? RT_String)?.value ??
            titleArg.map { String(describing: $0) } ??
            ""
        
        ask(rt, for: type, prompt: prompt, title: title, suspension: suspendAppleEvent())
    }
}

func getArguments(from event: NSAppleEventDescriptor) -> [ParameterInfo : RT_Object] {
    var result: [ParameterInfo : RT_Object] = [:]
    
    let count = event.numberOfItems
    guard count > 0 else {
        return [:]
    }
    
    let eventClass = event.eventClass
    let eventID = event.eventID
    
    for i in 1...count {
        let code = event.keywordForDescriptor(at: i)
        guard let descriptor = event.paramDescriptor(forKeyword: code) else {
            continue
        }
        
        if let value = try? RT_Object.fromAEDescriptor(RTInfo(), AppData(), descriptor) {
            result[ParameterInfo(.ae12(class: eventClass, id: eventID, code: code))] = value
        }
    }
    
    return result
}

func returnResultToSender(_ result: RT_Object, for suspensionID: NSAppleEventManager.SuspensionID) {
    setResult(result, for: suspensionID)
    returnToSender(for: suspensionID)
}

private func setResult(_ object: RT_Object, for suspensionID: NSAppleEventManager.SuspensionID) {
    setResult(object, in: NSAppleEventManager.shared().replyAppleEvent(forSuspensionID: suspensionID))
}

private func setResult(_ object: RT_Object, in replyEvent: NSAppleEventDescriptor) {
    guard let encodable = object as? AEEncodable else {
        os_log("Could not send object %@ in a reply descriptor because it is not encodable", log: log, type: .error, object)
        return
    }
    do {
        let encoded = try encodable.encodeAEDescriptor(AppData())
        replyEvent.setDescriptor(encoded, forKeyword: keyDirectObject)
    } catch {
        os_log("Failed to encode reply descriptor for %@: %@", log: log, type: .error, object, String(describing: error))
    }
}

func suspendAppleEvent() -> NSAppleEventManager.SuspensionID {
    precondition(NSAppleEventManager.shared().currentAppleEvent != nil)
    ProcessInfo.processInfo.disableAutomaticTermination("Processing AppleEvents")
    return NSAppleEventManager.shared().suspendCurrentAppleEvent()!
}

private func returnToSender(for suspensionID: NSAppleEventManager.SuspensionID) {
    ProcessInfo.processInfo.enableAutomaticTermination("Processing AppleEvents")
    NSAppleEventManager.shared().resume(withSuspensionID: suspensionID)
}

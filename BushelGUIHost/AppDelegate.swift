import Cocoa
import SwiftAutomation
import Bushel
import BushelRT
import os
import UserNotifications

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
                case .alert:
                    return #selector(handleAlert)
                case .ask:
                    return #selector(handleAsk)
                case .chooseFrom:
                    return #selector(handleChooseFrom)
                case .notification:
                    return #selector(handleNotification)
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
    
    @objc func handleAlert(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        let arguments = getArguments(from: event)
        
        let heading = string(from: arguments[ParameterInfo(.direct)]) ?? ""
        let message = string(from: arguments[ParameterInfo(.GUI_alert_message)]) ?? ""
        let title = string(from: arguments[ParameterInfo(.GUI_alert_title)]) ?? ""
        
        runAlert(heading: heading, message: message, title: title, suspension: suspendAppleEvent())
    }
    
    @objc func handleChooseFrom(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        let arguments = getArguments(from: event)
        
        let itemsArg = arguments[ParameterInfo(.direct)]
        let items: [RT_Object] =
            (itemsArg?.coerce() as? RT_List)?.contents ??
            itemsArg.map { [$0] } ??
            []
        let stringItems = items.compactMap { string(from: $0) }
        
        let prompt = string(from: arguments[ParameterInfo(.GUI_chooseFrom_prompt)]) ?? ""
        let okButtonName = string(from: arguments[ParameterInfo(.GUI_chooseFrom_confirm)]) ?? "OK"
        let cancelButtonName = string(from: arguments[ParameterInfo(.GUI_chooseFrom_cancel)]) ?? "Cancel"
        let title = string(from: arguments[ParameterInfo(.GUI_chooseFrom_title)]) ?? ""
        
        chooseFrom(list: stringItems, prompt: prompt, okButtonName: okButtonName, cancelButtonName: cancelButtonName, title: title, suspension: suspendAppleEvent())
    }
    
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
    
    @objc func handleNotification(event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        let arguments = getArguments(from: event)
        
        let message = string(from: arguments[ParameterInfo(.direct)]) ?? ""
        let title = string(from: arguments[ParameterInfo(.GUI_notification_title)])
        let subtitle = string(from: arguments[ParameterInfo(.GUI_notification_subtitle)]) ?? ""
        let soundName = string(from: arguments[ParameterInfo(.GUI_notification_sound)])
        
        let content = UNMutableNotificationContent()
        if let title = title {
            content.title = title
            content.body = message
        } else {
            content.title = message
        }
        content.subtitle = subtitle
        if let soundName = soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        } else {
            content.sound = nil
        }
        
        let suspension = suspendAppleEvent()
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.requestAuthorization(options: [.sound, .alert]) { (isAuthorized, error) in
            if let error = error {
                DispatchQueue.main.async {
                    NSApp.presentError(error)
                }
            }
            guard isAuthorized else {
                return returnErrorStatusToSender(OSStatus(errAEPrivilegeError), for: suspension)
            }
            
            notificationCenter.add(request, withCompletionHandler: { error in
                if let error = error {
                    DispatchQueue.main.async {
                        NSApp.presentError(error)
                    }
                }
            })
            returnToSender(for: suspension)
        }
        
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

private func string(from argument: RT_Object?) -> String? {
    guard let argument = argument else {
        return nil
    }
    return (argument.coerce() as? RT_String)?.value ?? String(describing: argument)
}

func returnResultToSender(_ result: RT_Object, for suspensionID: NSAppleEventManager.SuspensionID) {
    setResult(result, for: suspensionID)
    returnToSender(for: suspensionID)
}

func returnErrorStatusToSender(_ status: OSStatus, for suspensionID: NSAppleEventManager.SuspensionID) {
    setErrorStatus(status, for: suspensionID)
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
        setResult(encoded, in: replyEvent)
    } catch {
        os_log("Failed to encode reply descriptor for %@: %@", log: log, type: .error, object, String(describing: error))
    }
}

private func setResult(_ descriptor: NSAppleEventDescriptor, in replyEvent: NSAppleEventDescriptor) {
    replyEvent.setDescriptor(descriptor, forKeyword: keyDirectObject)
}

private func setErrorStatus(_ status: OSStatus, for suspensionID: NSAppleEventManager.SuspensionID) {
    setErrorStatus(status, in: NSAppleEventManager.shared().replyAppleEvent(forSuspensionID: suspensionID))
}

private func setErrorStatus(_ status: OSStatus, in replyEvent: NSAppleEventDescriptor) {
    let statusDescriptor = NSAppleEventDescriptor(int32: status)
    replyEvent.setDescriptor(statusDescriptor, forKeyword: keyErrorNumber)
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

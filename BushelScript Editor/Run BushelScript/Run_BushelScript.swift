import Foundation
import Automator
import Bushel
import BushelRT
import AEthereal
import os.log

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

class Run_BushelScript: AMBundleAction {
    
    // MARK: Configuration
    
    @IBOutlet weak var parametersController: NSObjectController!
    
    @IBOutlet weak var inlineRadioButton: NSButton!
    @IBOutlet weak var fileRadioButton: NSButton!
    
    @IBOutlet weak var inlineConfigView: NSView!
    @IBOutlet weak var fileConfigView: NSStackView!
    
    override func parametersUpdated() {
        super.parametersUpdated()
        
        inlineRadioButton.state = (sourceType == "inline" ? .on : .off)
        fileRadioButton.state = (sourceType == "file" ? .on : .off)
        
        inlineConfigView.isHidden = (sourceType != "inline")
        fileConfigView.isHidden = (sourceType != "file")
    }
    
    @IBAction
    func setSourceType(_ sender: Any?) {
        guard let identifier: NSUserInterfaceItemIdentifier = (sender as AnyObject).identifier else {
            return
        }
        sourceType = identifier.rawValue
    }
    private var sourceType: String {
        get {
            parameters?["source"] as? String ?? "inline"
        }
        set {
            parameters!["source"] = newValue as NSString
            parametersUpdated()
        }
    }
    
    @IBAction
    func chooseFile(_ sender: Any?) {
        let openSheet = NSOpenPanel()
        openSheet.allowedFileTypes = ["bushel"]
        openSheet.allowsMultipleSelection = false
        switch openSheet.runModal() {
        case .OK:
            parameters?["path"] = openSheet.url?.path
        default:
            break
        }
    }
    
    // MARK: Runtime
    
    override func run(withInput input: Any?) throws -> Any {
        locateAppBundle()
        
        let program: Bushel.Program
        switch sourceType {
        case "inline":
            guard let code = parameters?["code"] as? String else {
                return input ?? ([] as NSArray)
            }
            program = try Bushel.parse(source: code)
        case "file":
            guard let path = parameters?["path"] as? String else {
                return input ?? ([] as NSArray)
            }
            program = try Bushel.parse(source: try String(contentsOfFile: path))
        default:
            struct UnknownSourceType: LocalizedError {
                var errorDescription: String? {
                    "Invalid source type (should be 'inline' or 'file')"
                }
            }
            throw UnknownSourceType()
        }
        
        let rt = BushelRT.Runtime()
        if let input = input as? NSAppleEventDescriptor {
            rt.lastResult = try RT_Object.decode(rt, app: App.generic, aeDescriptor: AEDescriptor(input))
        }
        
        let result = try rt.run(program)
        if
            let encodable = result as? Encodable,
            let encoded = try? AEEncoder.encode(encodable)
        {
            var copy = AEDesc()
            let err = AEDuplicateDesc(encoded.aeDesc, &copy)
            assert(err == noErr)
            return NSAppleEventDescriptor(aeDescNoCopy: &copy)
        } else {
            return "\(result)"
        }
    }
    
    private func locateAppBundle() {
        let us = Bundle(for: Run_BushelScript.self).bundleURL
        #if DEVENVIRONMENT
        LanguageModule.appBundle = Bundle(url:
            us
            .deletingLastPathComponent() // <action bundle>
            .appendingPathComponent("BushelScript Editor.app")
        )
        #else
        LanguageModule.appBundle = Bundle(url:
            us
            .deletingLastPathComponent() // <action bundle>
            .deletingLastPathComponent() // Automator
            .deletingLastPathComponent() // Library
            .deletingLastPathComponent() // Contents
        )
        #endif
        if LanguageModule.appBundle == nil {
            os_log("Failed to find app bundle from path to own bundle. Language modules installed in the app bundle will not be available.", log: log)
        }
    }

}

@objc(PathToFileURLVT)
class PathToFileURLVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        (value as? String).map { URL(fileURLWithPath: $0) }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        (value as? URL).map { $0.path }
    }
    
}

// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Defaults

class InterpreterPrefsVC: NSViewController {
    
    override func viewDidLoad() {
        Defaults.observe(.cltInstallPath) { [weak self] _ in
            self?.updateInstalledStatus()
        }.tieToLifetime(of: self)
    }
    
    override func viewWillAppear() {
        updateInstalledStatus()
    }
    
    @objc enum CLTInstalledStatus: Int {
        case `false`, `true`, obstructed, invalid
        
        static func fromObjC(_ value: Any?) -> Self? {
            ((value as? NSNumber)?.intValue).flatMap { Self(rawValue: $0) }
        }
    }
    
    @objc dynamic var cltInstalledStatus: CLTInstalledStatus = .false
    
    private func updateInstalledStatus() {
        do {
            if fileExistsAtCLTInstallPath() {
                let values = try URL(fileURLWithPath: Defaults[.cltInstallPath]).resourceValues(forKeys: [.isSymbolicLinkKey, .isWritableKey])
                if values.isSymbolicLink!, values.isWritable! {
                    if FileManager.default.isExecutableFile(atPath: Defaults[.cltInstallPath]) {
                        cltInstalledStatus = .true
                    } else {
                        cltInstalledStatus = .invalid
                    }
                } else {
                    cltInstalledStatus = .obstructed
                }
            } else {
                cltInstalledStatus = .false
            }
        } catch {
            presentError(error)
        }
    }
    
    @IBOutlet weak var locationTF: NSTextField!
    
    @IBAction
    func toggleInstalled(_ sender: Any?) {
        view.window?.makeFirstResponder(self)
        updateInstalledStatus()
        do {
            switch cltInstalledStatus {
            case .false, .invalid:
                // Remove old version if applicable.
                if fileExistsAtCLTInstallPath() {
                    try FileManager.default.removeItem(atPath: Defaults[.cltInstallPath])
                }
                
                let cltPath = Bundle.main.path(forResource: "bushelscript", ofType: nil)!
                try FileManager.default.createSymbolicLink(atPath: Defaults[.cltInstallPath], withDestinationPath: cltPath)
            case .true:
                try FileManager.default.removeItem(atPath: Defaults[.cltInstallPath])
            case .obstructed:
                return
            @unknown default:
                return
            }
        } catch {
            presentError(error)
        }
        updateInstalledStatus()
    }
    
    private func fileExistsAtCLTInstallPath() -> Bool {
        (try? URL(fileURLWithPath: Defaults[.cltInstallPath]).resourceValues(forKeys: [.fileResourceTypeKey])) != nil
    }
    
}

@objc(InterpreterPrefsInstallStatusAvailabilityImageVT)
class InterpreterPrefsInstallStatusAvailabilityImageVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        NSImage(named: {
            switch InterpreterPrefsVC.CLTInstalledStatus.fromObjC(value) {
            case .false:
                return NSImage.statusPartiallyAvailableName
            case .true:
                return NSImage.statusAvailableName
            case .obstructed, .invalid:
                return NSImage.statusUnavailableName
            case nil:
                fallthrough
            @unknown default:
                return NSImage.statusNoneName
            }
        }())
    }
    
}

@objc(InterpreterPrefsInstallStatusHeadingVT)
class InterpreterPrefsInstallStatusHeadingVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        switch InterpreterPrefsVC.CLTInstalledStatus.fromObjC(value) {
        case .false:
            return "Command line tool not installed"
        case .true:
            return "Command line tool installed"
        case .obstructed:
            return "Install location is obstructed, please change the location or remove the obstruction"
        case .invalid:
            return "Installation is invalid (BushelScript Editor may have been relocated), please reinstall"
        case nil:
            fallthrough
        @unknown default:
            return nil
        }
    }
    
}

@objc(InterpreterPrefsInstallButtonTitleVT)
class InterpreterPrefsInstallButtonTitleVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        switch InterpreterPrefsVC.CLTInstalledStatus.fromObjC(value) {
        case .false:
            return "Install"
        case .true:
            return "Uninstall"
        case .obstructed:
            return "Obstructed"
        case .invalid:
            return "Reinstall"
        case nil:
            fallthrough
        @unknown default:
            return nil
        }
    }
    
}

@objc(InterpreterPrefsToggleInstallButtonEnabledVT)
class InterpreterPrefsToggleInstallButtonEnabledVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        switch InterpreterPrefsVC.CLTInstalledStatus.fromObjC(value) {
        case .false, .true, .invalid:
            return true
        case .obstructed:
            return false
        case nil:
            fallthrough
        @unknown default:
            return false
        }
    }
    
}

@objc(InterpreterPrefsLocationFieldEnabledVT)
class InterpreterPrefsLocationFieldEnabledVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        switch InterpreterPrefsVC.CLTInstalledStatus.fromObjC(value) {
        case .false, .obstructed, .invalid:
            return true
        case .true:
            return false
        case nil:
            fallthrough
        @unknown default:
            return true
        }
    }
    
}

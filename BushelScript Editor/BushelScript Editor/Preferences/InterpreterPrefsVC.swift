// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
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
        case `false`, `true`, obstructed
        
        static func fromObjC(_ value: Any?) -> Self? {
            ((value as? NSNumber)?.intValue).flatMap { Self(rawValue: $0) }
        }
    }
    
    @objc dynamic var cltInstalledStatus: CLTInstalledStatus = .false
    
    private func updateInstalledStatus() {
        do {
            if FileManager.default.fileExists(atPath: Defaults[.cltInstallPath]) {
                let resources = try URL(fileURLWithPath: Defaults[.cltInstallPath]).resourceValues(forKeys: [.isRegularFileKey, .isExecutableKey])
                if resources.isRegularFile!, resources.isExecutable! {
                    cltInstalledStatus = .true
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
            case .false:
                let cltPath = Bundle.main.path(forResource: "bushelscript", ofType: nil)!
                try FileManager.default.linkItem(atPath: cltPath, toPath: Defaults[.cltInstallPath])
            case .true:
                try FileManager.default.removeItem(atPath: Defaults[.cltInstallPath])
            case .obstructed:
                return
            default:
                return
            }
        } catch {
            presentError(error)
        }
        updateInstalledStatus()
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
            case .obstructed:
                return NSImage.statusUnavailableName
            default:
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
        default:
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
        default:
            return nil
        }
    }
    
}

@objc(InterpreterPrefsToggleInstallButtonEnabledVT)
class InterpreterPrefsToggleInstallButtonEnabledVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        switch InterpreterPrefsVC.CLTInstalledStatus.fromObjC(value) {
        case .false:
            return true
        case .true:
            return true
        case .obstructed:
            return false
        default:
            return false
        }
    }
    
}

@objc(InterpreterPrefsLocationFieldEnabledVT)
class InterpreterPrefsLocationFieldEnabledVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        switch InterpreterPrefsVC.CLTInstalledStatus.fromObjC(value) {
        case .false:
            return true
        case .true:
            return false
        case .obstructed:
            return true
        default:
            return true
        }
    }
    
}

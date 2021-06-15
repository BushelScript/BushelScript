// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Defaults

class InterpreterPrefsVC: NSViewController {
    
    override func viewWillAppear() {
        updateInstalledStatus()
    }
    
    @objc dynamic var isCLTInstalled: Bool = false
    
    private func updateInstalledStatus() {
        isCLTInstalled = FileManager.default.isExecutableFile(atPath: Defaults[.cltInstallPath])
    }
    
    @IBOutlet weak var locationTF: NSTextField!
    
    @IBAction
    func toggleInstalled(_ sender: Any?) {
        view.window?.makeFirstResponder(self)
        do {
            if isCLTInstalled {
                try FileManager.default.removeItem(atPath: Defaults[.cltInstallPath])
            } else {
                let cltPath = Bundle.main.path(forResource: "bushelscript", ofType: nil)!
                try FileManager.default.linkItem(atPath: cltPath, toPath: Defaults[.cltInstallPath])
            }
        } catch {
            presentError(error)
        }
        updateInstalledStatus()
    }
    
}

@objc(InterpreterPrefsInstallStatusHeadingVT)
class InterpreterPrefsInstallStatusHeadingVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        (value as? Bool).map { $0 ? "Command line tool installed" : "Command line tool not installed" }
    }
    
}

@objc(InterpreterPrefsInstallButtonTitleVT)
class InterpreterPrefsInstallButtonTitleVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        (value as? Bool).map { $0 ? "Uninstall" : "Install" }
    }
    
}

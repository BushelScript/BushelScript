//
//  CommandLineToolVC.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 1 Feb '20.
//  Copyright © 2020 Ian Gregory. All rights reserved.
//

import Cocoa
import BushelLanguageServiceConnectionCreation

class CommandLineToolVC: NSViewController {

    @IBOutlet weak var installCommandsTF: NSTextField!
    @IBOutlet weak var runInstallCommandsButton: NSButton!
    @IBOutlet weak var uninstallCommandsTF: NSTextField!
    @IBOutlet weak var runUninstallCommandsButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        installCommandsTF.stringValue = installCommands
        uninstallCommandsTF.stringValue = uninstallCommands
    }
    
    private var installCommands: String {
        "ln -s '\(Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("bin", isDirectory: true).appendingPathComponent("bushelscript").path)' '/usr/local/bin/bushelscript'"
    }
    private var uninstallCommands: String {
        "rm '/usr/local/bin/bushelscript'"
    }
    
    @IBAction func runInstallCommands(_ sender: Any) {
        runTerminalCommands(installCommands)
    }
    
    @IBAction func runUninstallCommands(_ sender: Any) {
        runTerminalCommands(uninstallCommands)
    }
    
    private func runTerminalCommands(_ commands: String) {
        let programSource = """
use app Terminal
#!/bin/cat
\(commands)
exit
#!bushelscript
tell Terminal to do script that
"""
        
        func failed() {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Failed to run the commands automatically."
                alert.informativeText = "You can always run them youself in Terminal."
                if let window = self.view.window {
                    alert.beginSheetModal(for: window, completionHandler: nil)
                } else {
                    alert.runModal()
                }
            }
        }
        let connection = NSXPCConnection.bushelLanguageServiceConnection(interruptionHandler: failed, invalidationHandler: failed)
        guard let service = connection.remoteObjectProxyWithErrorHandler({ _ in failed() }) as? BushelLanguageServiceProtocol else {
            return failed()
        }
        service.loadLanguageModule(withIdentifier: "bushelscript_en") { languageModule in
            guard let languageModule = languageModule else {
                return failed()
            }
            service.parseSource(programSource, usingLanguageModule: languageModule) { (program, error) in
                guard let program = program else {
                    return failed()
                }
                service.runProgram(program, scriptName: "Install bushelscript Command-Line Tool", currentApplicationID: Bundle.main.bundleIdentifier!, reply: { result in
                    guard result != nil else {
                        return failed()
                    }
                })
            }
        }
    }
    
}

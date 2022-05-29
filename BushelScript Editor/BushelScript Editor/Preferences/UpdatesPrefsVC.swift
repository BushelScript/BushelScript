// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Defaults
import Sparkle

class UpdatesPrefsVC: NSViewController {
    
    @objc let updater = SUUpdater.shared()!
    
    @IBAction func checkForUpdates(_ sender: Any?) {
        updater.checkForUpdates(nil)
    }
    
}

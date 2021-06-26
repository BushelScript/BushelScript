// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import os.log

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

class MainSplitVC: NSSplitViewController {
    
    override func viewWillAppear() {
        for item in splitViewItems {
            (item.viewController as? DocumentVC)?.bind(NSBindingName(rawValue: #keyPath(NSViewController.representedObject)), to: self, withKeyPath: #keyPath(NSViewController.representedObject), options: nil)
        }
        super.viewWillAppear()
    }
    
}

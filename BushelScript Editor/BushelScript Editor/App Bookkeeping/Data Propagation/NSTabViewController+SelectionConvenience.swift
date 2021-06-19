// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import os

private let log = OSLog(subsystem: logSubsystem, category: "NSTabViewController selection convenience")

extension NSTabViewController {
    
    func selectTabViewItem(withIdentifier identifier: Any) {
        guard
            let itemIndex = tabViewItems
                .map({ $0.identifier as AnyObject })
                .firstIndex(where: { $0.isEqual(identifier as AnyObject) })
        else {
            os_log("Tab view item with identifier %@ not found!", log: log, type: .default, String(describing: identifier))
            return
        }
        
        selectedTabViewItemIndex = itemIndex
    }
    
}

//
//  NSTabViewController+SelectionConvenience.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 05-10-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

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

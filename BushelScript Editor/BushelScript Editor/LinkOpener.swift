//
//  LinkOpener.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 31-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa
import os

private let log = OSLog(subsystem: logSubsystem, category: "LinkOpener")

class LinkOpener: NSObject {
    
    @IBInspectable var link: String = ""
    
    @IBAction func openLink(_ sender: Any?) {
        guard let url = URL(string: link) else {
            return os_log("Could not initialize a URL object with string: %@", log: log, type: .info, link)
        }
        NSWorkspace.shared.open(url)
    }
    
}

// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

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

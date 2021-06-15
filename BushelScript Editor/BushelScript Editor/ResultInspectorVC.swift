// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import os.log

private let log = OSLog(subsystem: logSubsystem, category: #file)

class ResultInspectorVC: ObjectInspector2VC {
    
    var document: Document?
    
    override func viewWillAppear() {
        super.viewWillAppear()
        guard let document = view.window?.windowController?.document as? Document else {
            return os_log("No document available", log: log, type: .debug)
        }
        self.document = document
        tying(to: self) {
            NotificationObservation(.result, document) { [weak self] (document, userInfo) in
                self?.representedObject = userInfo[.payload]
            }
        }
    }
    
}

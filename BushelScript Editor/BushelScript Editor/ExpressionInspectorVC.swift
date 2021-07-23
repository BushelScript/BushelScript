// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import os.log
import Bushel

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

class ExpressionInspectorVC: ObjectInspector2VC {
    
    var document: Document?
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        guard self.document == nil else {
            return
        }
        
        guard let document = view.window?.windowController?.document as? Document else {
            return os_log("No document available", log: log, type: .debug)
        }
        self.document = document
        
        tie(to: self, [
            NotificationObservation(.selectedExpression, document) { [weak self] (document, userInfo) in
                guard let self = self else {
                    return
                }
                guard let expression = userInfo[.payload] as? Expression else {
                    self.representedObject = nil
                    return
                }
                var termDocString = ""
                if let termForDocs = expression.termForDocs() {
                    let doc = document?.program?.termDocs.value[termForDocs.id]
                    termDocString = "\(termForDocs)\(doc.map { ": \($0)" } ?? "")\n\n"
                }
                let expressionDocString = "\(expression.kindName): \(expression.kindDescription)"
                self.representedObject = termDocString + expressionDocString
            }
        ])
    }
    
}

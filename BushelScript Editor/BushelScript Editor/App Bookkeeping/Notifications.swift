// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import os.log

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

extension Notification.Name {
    
    static let documentSelectedExpressions = Notification.Name("documentSelectedExpressions")
    static let documentResult = Notification.Name("documentResult")
    
}

enum UserInfo: String, Hashable {
    
    case payload
    
}

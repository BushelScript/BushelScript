// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import os.log

private let log = OSLog(subsystem: logSubsystem, category: #file)

extension Notification.Name {
    
    static let selection = Notification.Name("selection")
    static let selectedExpression = Notification.Name("selectedExpression")
    static let result = Notification.Name("result")
    
}

enum UserInfo: String, Hashable {
    
    case payload
    
}

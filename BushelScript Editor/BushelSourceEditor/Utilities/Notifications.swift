import Foundation
import os.log

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

extension Notification.Name {
    
    public static let documentSelectedExpressions = Notification.Name("documentSelectedExpressions")
    public static let documentResult = Notification.Name("documentResult")
    
}

public enum UserInfo: String, Hashable {
    
    case payload
    
}

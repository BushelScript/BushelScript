import Foundation

/// A `LocalizedError` that marshals properly through `NSCoding` and
/// `NSSecureCoding`.
public protocol CodableLocalizedError: LocalizedError, CustomNSError {
}

public extension CustomNSError where Self: CodableLocalizedError {
    
    var errorCode: Int {
        return 1
    }
    
    var errorUserInfo: [String : Any] {
        var userInfo: [String : Any] = [:]
        if let errorDescription = errorDescription {
            userInfo[NSLocalizedDescriptionKey] = errorDescription
        }
        if let failureReason = failureReason {
            userInfo[NSLocalizedFailureReasonErrorKey] = failureReason
        }
        if let recoverySuggestion = recoverySuggestion {
            userInfo[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion
        }
        if let helpAnchor = helpAnchor {
            userInfo[NSHelpAnchorErrorKey] = helpAnchor
        }
        return userInfo
    }
    
}

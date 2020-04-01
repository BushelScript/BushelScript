// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Foundation

enum ReadError: LocalizedError {
    
    case corruptData(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .corruptData:
            return "The data is corrupted."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .corruptData(reason: let reason):
            return reason
        }
    }
    
}

enum RunError: LocalizedError {
    
    case syntaxErrorsExist
    
    var errorDescription: String? {
        switch self {
        case .syntaxErrorsExist:
            return "The script has syntax errors that must be resolved before running."
        }
    }
    
}

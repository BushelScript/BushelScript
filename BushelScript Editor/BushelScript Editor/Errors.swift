//
//  Errors.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 25-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

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

// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Foundation

extension UndoManager {
    
    func withoutRegistration<Result>(do action: () throws -> Result) rethrows -> Result {
        disableUndoRegistration()
        defer {
            enableUndoRegistration()
        }
        return try action()
    }
    
    func group<Result>(do action: () throws -> Result) rethrows -> Result {
        beginUndoGrouping()
        defer {
            endUndoGrouping()
        }
        return try action()
    }
    
}

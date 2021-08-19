import Foundation

extension UndoManager {
    
    public func withoutRegistration<Result>(do action: () throws -> Result) rethrows -> Result {
        disableUndoRegistration()
        defer {
            enableUndoRegistration()
        }
        return try action()
    }
    
    public func group<Result>(do action: () throws -> Result) rethrows -> Result {
        beginUndoGrouping()
        defer {
            endUndoGrouping()
        }
        return try action()
    }
    
}

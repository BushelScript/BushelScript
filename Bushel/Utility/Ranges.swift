import Foundation

extension Range {
    
    public func contains(_ other: Self) -> Bool {
        other.clamped(to: self) == other
    }
    
}

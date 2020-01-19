// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import Foundation

public extension Substring {
    
    mutating func removeFirst(while predicate: (Character) throws -> Bool) rethrows {
        self = try drop(while: predicate)
    }
    
    mutating func removeLast(while predicate: (Character) throws -> Bool) rethrows {
        while
            let last = self.last,
            try predicate(last)
        {
            removeLast()
        }
    }
    
    func dropLast(while predicate: (Character) throws -> Bool) rethrows -> Substring {
        var copy = self
        try copy.removeLast(while: predicate)
        return copy
    }
    
    mutating func removeLeadingWhitespace(removingNewlines: Bool = false) {
        removeFirst(while: { $0.isWhitespace && (removingNewlines || !$0.isNewline) })
    }
    
    mutating func removeTrailingWhitespace(removingNewlines: Bool = false) {
        removeLast(while: { $0.isWhitespace && (removingNewlines || !$0.isNewline) })
    }
    
    func removingPrefix(_ prefix: String) -> Substring? {
        var copy = Substring(self)
        return copy.removePrefix(prefix) ? copy : nil
    }
    
    mutating func removePrefix(_ prefix: String) -> Bool {
        removeLeadingWhitespace()
        if hasPrefix(prefix) {
            removeFirst(prefix.count)
            return true
        } else {
            return false
        }
    }
    
    func removingSuffix(_ suffix: String) -> Substring? {
        var copy = self
        return copy.removeSuffix(suffix) ? copy : nil
    }
    
    mutating func removeSuffix(_ suffix: String) -> Bool {
        removeTrailingWhitespace()
        if hasSuffix(suffix) {
            removeLast(suffix.count)
            return true
        } else {
            return false
        }
    }
    
}

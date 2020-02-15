import Foundation

// Implements this algorithm:
// https://en.cppreference.com/w/cpp/algorithm/lexicographical_compare
// Only difference here being that we distinguish between equal-to and greater-than
private func lexicographicalCompare<Seq: Swift.Sequence>(_ lhs: Seq, to rhs: Seq) -> ComparisonResult
    where Seq.Element: Comparable
{
    var lhsIt = lhs.makeIterator(), rhsIt = rhs.makeIterator()
    var lhsCount = 0, rhsCount = 0
    while
        let lhsValue = lhsIt.next(),
        let rhsValue = rhsIt.next()
    {
        if lhsValue < rhsValue { return .orderedAscending }
        if rhsValue < lhsValue { return .orderedDescending }
        lhsCount += 1
        rhsCount += 1
    }
    if lhsCount < rhsCount { return .orderedAscending }
    if rhsCount < lhsCount { return .orderedDescending }
    return .orderedSame
}

infix operator <=> : ComparisonPrecedence

extension Comparable {
    
    public static func <=> (lhs: Self, rhs: Self) -> ComparisonResult {
        return lhs == rhs ? .orderedSame : (lhs < rhs ? .orderedAscending : .orderedDescending)
    }
    
}

public func <=> (lhs: Bool, rhs: Bool) -> ComparisonResult {
    return lhs == rhs ? .orderedSame : (!lhs && rhs ? .orderedAscending : .orderedDescending)
}

extension Comparable where Self: Swift.Sequence, Self.Element: Comparable {
    
    public static func <=> (lhs: Self, rhs: Self) -> ComparisonResult {
        return lexicographicalCompare(lhs, to: rhs)
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lexicographicalCompare(lhs, to: rhs) == .orderedAscending
    }
    
}

extension Equatable where Self: Swift.Sequence, Self.Element: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.elementsEqual(rhs)
    }
    
}

// Some common cases
extension Array: Comparable where Element: Comparable {}
extension Set: Comparable where Element: Comparable {}
extension Dictionary.Keys: Comparable where Element: Comparable {}
extension Dictionary.Values: Equatable where Element: Equatable {}
extension Dictionary.Values: Comparable where Element: Comparable {}

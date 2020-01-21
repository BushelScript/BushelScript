import Foundation

public struct SourceLocation {
    
    public var range: Range<String.Index>
    
    #if DEBUG
    public var source: String
    #else
    public var source: String {
        return ""
    }
    #endif
    
    public init(_ range: Range<String.Index>, source: String) {
        self.range = range
        #if DEBUG
        self.source = source
        #endif
    }
    
    public init(at index: String.Index, source: String) {
        self.range = index..<index
        #if DEBUG
        self.source = source
        #endif
    }
    
}

#if DEBUG
extension SourceLocation: CustomReflectable {
    
    public var customMirror: Mirror {
        let children: [Mirror.Child] = [
            (label: "lowerBound", value: source.distance(from: source.startIndex, to: range.lowerBound)),
            (label: "upperBound", value: source.distance(from: source.startIndex, to: range.upperBound)),
        ]
        return Mirror(self, children: children)
    }
    
}
#endif

extension SourceLocation {
    
    public func lines<S: StringProtocol>(in source: S) -> Range<Int> {
        let lowerBound = source[...range.lowerBound].filter { $0.isNewline }.count + 1
        return lowerBound..<(lowerBound + source[range].filter { $0.isNewline }.count + 1)
    }
    
    public func columns<S: StringProtocol>(in source: S) -> Range<Int> {
        let lineRange = source.lineRange(for: range)
        let startCol = source.distance(from: lineRange.lowerBound, to: range.lowerBound) + 1
        if lines(in: source).count != 1 {
            // Spans multiple lines, so just mark the start
            return startCol..<(startCol + 1)
        }
        let endCol = source.distance(from: lineRange.lowerBound, to: range.upperBound) + 1
        return startCol..<endCol
    }
    
}

extension SourceLocation: Equatable, Hashable {
}

extension SourceLocation {
    
    public enum BetweenCharacterLeanPreference {
        case unspecified, backward, forward
    }
    
    public func snippet<S: StringProtocol>(in source: S, leaning: BetweenCharacterLeanPreference = .unspecified) -> S.SubSequence {
        let leaning = leaning == .unspecified ? .backward : leaning
        if source.distance(from: range.lowerBound, to: range.upperBound) >= 1 {
            return source[range]
        } else {
            let before = source.index(before: range.lowerBound)
            if leaning == .backward && before >= source.startIndex {
                return source[before...before]
            } else {
                return source[range.lowerBound...range.lowerBound]
            }
        }
    }
    
    public func words<S: StringProtocol>(in source: S) -> String where S.SubSequence == Substring {
        var words: [String] = []
        var remainingSource = source[range]
        remainingSource.removeLeadingWhitespace()
        while let word = TermName.nextWord(in: remainingSource) {
            words.append(word)
            remainingSource.removeLeadingWhitespace(removingNewlines: true)
            remainingSource.removeFirst(word.count)
        }
        return words.joined(separator: " ")
    }
    
    public init(between first: SourceLocation, and second: SourceLocation) {
        self.init(first.range.upperBound..<second.range.lowerBound, source: first.source)
    }
    
    public init(at other: SourceLocation) {
        self.init(at: other.range.lowerBound, source: other.source)
    }
    
    public init(after other: SourceLocation) {
        self.init(at: other.range.upperBound, source: other.source)
    }
    
}

infix operator >|< : AdditionPrecedence
prefix operator >|
postfix operator |<

public func >|< (lhs: SourceLocation, rhs: SourceLocation) -> SourceLocation {
    return SourceLocation(between: lhs, and: rhs)
}
public prefix func >| (operand: SourceLocation) -> SourceLocation {
    return SourceLocation(at: operand)
}
public postfix func |< (operand: SourceLocation) -> SourceLocation {
    return SourceLocation(after: operand)
}

public extension String {
    
    mutating func trimLineEndings() {
        self = String(
            (split { $0.isNewline } as [Substring])
            .map { (line: Substring) -> Substring in
                var line = line
                line.removeTrailingWhitespace()
                return line
            }
            .joined()
        )
    }
    
}

public extension String {
    
    mutating func removeFirst(while predicate: (Character) throws -> Bool) rethrows {
        while
            let first = self.first,
            try predicate(first)
        {
            removeFirst()
        }
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
        var substring = Substring(self)
        try substring.removeLast(while: predicate)
        return substring
    }
    
    func trimmingWhitespace(removingNewlines: Bool = false) -> String {
        var copy = self
        copy.removeLeadingWhitespace(removingNewlines: removingNewlines)
        copy.removeTrailingWhitespace(removingNewlines: removingNewlines)
        return copy
    }
    
    func removingLeadingWhitespace(removingNewlines: Bool = false) -> String {
        var copy = self
        copy.removeLeadingWhitespace(removingNewlines: removingNewlines)
        return copy
    }
    
    func removingTrailingWhitespace(removingNewlines: Bool = false) -> String {
        var copy = self
        copy.removeTrailingWhitespace(removingNewlines: removingNewlines)
        return copy
    }
    
    mutating func removeLeadingWhitespace(removingNewlines: Bool = false) {
        removeFirst(while: { $0.isWhitespace && (removingNewlines || !$0.isNewline) })
    }
    
    mutating func removeTrailingWhitespace(removingNewlines: Bool = false) {
        removeLast(while: { $0.isWhitespace && (removingNewlines || !$0.isNewline) })
    }
    
    func removingPrefix(_ prefix: String) -> Substring? {
        var substring = Substring(self)
        return substring.removePrefix(prefix) ? substring : nil
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
        var substring = Substring(self)
        return substring.removeSuffix(suffix) ? substring : nil
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
    
    func trimmingWhitespace(removingNewlines: Bool = false) -> Substring {
        var copy = self
        copy.removeLeadingWhitespace(removingNewlines: removingNewlines)
        copy.removeTrailingWhitespace(removingNewlines: removingNewlines)
        return copy
    }
    
    func removingLeadingWhitespace(removingNewlines: Bool = false) -> Substring {
        var copy = self
        copy.removeLeadingWhitespace(removingNewlines: removingNewlines)
        return copy
    }
    
    func removingTrailingWhitespace(removingNewlines: Bool = false) -> Substring {
        var copy = self
        copy.removeTrailingWhitespace(removingNewlines: removingNewlines)
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

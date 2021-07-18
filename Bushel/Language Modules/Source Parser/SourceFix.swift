
private extension Range where Bound == Int {
    
    func applying(to string: String) -> Range<String.Index> {
        func index(at offset: Int) -> String.Index {
            return string.index(string.startIndex, offsetBy: offset)
        }
        return index(at: lowerBound)..<index(at: upperBound)
    }
    
}

private extension Array where Element == FixImpact {
    
    func adjustedRelativeRange(for relativeRange: Range<Int>) throws -> Range<Int> {
        return try reduce(relativeRange) { try $1.adjust($0) }
    }
    
}

private extension SourceLocation {
    
    func relativeRange(in source: String) -> Range<Int> {
        func distance(to index: Substring.Index) -> Int {
            return source.distance(from: source.startIndex, to: index)
        }
        return distance(to: range.lowerBound)..<distance(to: range.upperBound)
    }
    
}

public struct FixImpact {
    
    public enum Delta {
        case adding
        case deleting
    }
    
    public let impactedRange: Range<Int>
    public let delta: Delta
    
    public init(in range: Range<Int>, by delta: Delta) {
        self.impactedRange = range
        self.delta = delta
    }
    
    public func adjust(_ otherRange: Range<Int>) throws -> Range<Int> {
        let lower = otherRange.lowerBound, upper = otherRange.upperBound
        let newLower: Int, newUpper: Int
        if impactedRange.overlaps(otherRange) {
            throw FixError.overlapping
        }
        switch delta {
        case .adding:
            newLower = lower + (lower >= impactedRange.upperBound ? otherRange.count : 0)
            newUpper = upper + (upper >= impactedRange.upperBound ? otherRange.count : 0)
        case .deleting:
            newLower = lower - (lower >= impactedRange.upperBound ? otherRange.count : 0)
            newUpper = upper - (upper >= impactedRange.upperBound ? otherRange.count : 0)
        }
        return newLower..<newUpper
    }
    
}

public protocol SourceFix {
    
    var locations: [SourceLocation] { get }
    
    func apply(to source: inout String, initialSource: String, impacts: inout [FixImpact]) throws
    
    func then(apply nextFix: SourceFix) -> SequencingFix
    
    func contextualDescription(in source: Substring) -> String
    func simpleDescription(in source: Substring) -> String
    
}

extension SourceFix {
    
    public static func | (lhs: SourceFix, rhs: SourceFix) -> SequencingFix {
        return lhs.then(apply: rhs)
    }
    
    public func then(apply nextFix: SourceFix) -> SequencingFix {
        return SequencingFix(fixes: [self, nextFix])
    }
    
}

extension SourceFix {
    
    public func apply(to source: String) throws -> String {
        var fixedSource = source
        var impacts: [FixImpact] = []
        try apply(to: &fixedSource, initialSource: source, impacts: &impacts)
        return fixedSource
    }
    
}

extension SourceFix {
    
    public func contextualDescription(in source: Substring) -> String {
        return simpleDescription(in: source)
    }
    
}

public class SequencingFix: SourceFix {
    
    private(set) public var fixes: [SourceFix]
    
    public var locations: [SourceLocation] {
        return fixes.flatMap { $0.locations }
    }
    
    public init(fixes: [SourceFix]) {
        self.fixes = fixes
    }
    
    public func apply(to source: inout String, initialSource: String, impacts: inout [FixImpact]) throws {
        for fix in fixes {
            try fix.apply(to: &source, initialSource: initialSource, impacts: &impacts)
        }
    }
    
    public func then(apply nextFix: SourceFix) -> SequencingFix {
        fixes.append(nextFix)
        return self
    }
    
    public func simpleDescription(in source: Substring) -> String {
        return fixes.map { $0.simpleDescription(in: source) }.joined(separator: ", ")
    }
    
}

public class NoOpFix: SourceFix {
    
    public var locations: [SourceLocation]
    
    public init(at locations: [SourceLocation]) {
        self.locations = locations
    }
    
    public func apply(to source: inout String, initialSource: String, impacts: inout [FixImpact]) throws {
        return
    }
    
    public func simpleDescription(in source: Substring) -> String {
        return "(no description provided)"
    }
    
}

public class DeletingFix: SourceFix {
    
    public let location: SourceLocation
    
    public var locations: [SourceLocation] {
        return [location]
    }
    
    public init(at location: SourceLocation) {
        self.location = location
    }
    
    public func apply(to source: inout String, initialSource: String, impacts: inout [FixImpact]) throws {
        let relativeRange = location.relativeRange(in: initialSource)
        
        source.removeSubrange(try impacts.adjustedRelativeRange(for: relativeRange).applying(to: source))
        
        impacts.append(FixImpact(in: relativeRange, by: .deleting))
    }
    
    public func simpleDescription(in source: Substring) -> String {
        return "delete ‘\(location.snippet(in: source))’"
    }
    
}

public class PrependingFix: SourceFix {
    
    public let stringToPrepend: String
    public let location: SourceLocation
    
    public var locations: [SourceLocation] {
        return [location]
    }
    
    public init(prepending string: String, at location: SourceLocation) {
        self.stringToPrepend = string
        self.location = location
    }
    
    public func apply(to source: inout String, initialSource: String, impacts: inout [FixImpact]) throws {
        let relativeRange = location.relativeRange(in: initialSource)
        
        source.insert(contentsOf: stringToPrepend, at: try impacts.adjustedRelativeRange(for: relativeRange).applying(to: source).lowerBound)
        
        let newStringRange = (relativeRange.lowerBound - stringToPrepend.count)..<relativeRange.lowerBound
        impacts.append(FixImpact(in: newStringRange, by: .adding))
    }
    
    public func contextualDescription(in source: Substring) -> String {
        return "\(simpleDescription(in: source)) before ‘\(Term.Name.nextWord(in: source[location.range.lowerBound...]) ?? String(location.snippet(in: source, leaning: .forward)))’"
    }
    public func simpleDescription(in source: Substring) -> String {
        return "add ‘\(stringToPrepend)’"
    }
    
}

public class AppendingFix: SourceFix {
    
    public let stringToAppend: String
    public let location: SourceLocation
    
    public var locations: [SourceLocation] {
        return [location]
    }
    
    public init(appending string: String, at location: SourceLocation) {
        self.stringToAppend = string
        self.location = location
    }
    
    public func apply(to source: inout String, initialSource: String, impacts: inout [FixImpact]) throws {
        let relativeRange = location.relativeRange(in: initialSource)
        
        source.insert(contentsOf: stringToAppend, at: try impacts.adjustedRelativeRange(for: relativeRange).applying(to: source).upperBound)
        
        let newStringRange = relativeRange.upperBound..<(relativeRange.upperBound + stringToAppend.count)
        impacts.append(FixImpact(in: newStringRange, by: .adding))
    }
    
    public func contextualDescription(in source: Substring) -> String {
        return "\(simpleDescription(in: source)) after ‘\(Term.Name.nextWord(in: source[location.range.lowerBound...]) ?? String(location.snippet(in: source, leaning: .backward)))’"
    }
    public func simpleDescription(in source: Substring) -> String {
        return "add ‘\(stringToAppend)’"
    }
    
}

public class TransposingFix: SourceFix {
    
    public let location: (SourceLocation, SourceLocation)
    
    public var locations: [SourceLocation] {
        return [location.0, location.1]
    }
    
    public init(at location1: SourceLocation, and location2: SourceLocation) {
        self.location = (location1, location2)
    }
    
    public func apply(to source: inout String, initialSource: String, impacts: inout [FixImpact]) throws {
        let relativeRanges = (
            location.0.relativeRange(in: initialSource),
            location.1.relativeRange(in: initialSource)
        )
        let strings = (
            String(initialSource[relativeRanges.0.applying(to: initialSource)]),
            String(initialSource[relativeRanges.1.applying(to: initialSource)])
        )
        let adjustedRelativeRanges = (
            try impacts.adjustedRelativeRange(for: relativeRanges.0),
            try impacts.adjustedRelativeRange(for: relativeRanges.1)
        )
        
        source.replaceSubrange(adjustedRelativeRanges.0.applying(to: source), with: strings.1)
        source.replaceSubrange(adjustedRelativeRanges.1.applying(to: source), with: strings.0)
        
        let newRanges = (
            relativeRanges.0.lowerBound..<(relativeRanges.0.lowerBound + strings.1.count),
            relativeRanges.1.lowerBound..<(relativeRanges.1.lowerBound + strings.0.count)
        )
        impacts.append(contentsOf: [
            FixImpact(in: relativeRanges.0, by: .deleting),
            FixImpact(in: relativeRanges.1, by: .deleting),
            FixImpact(in: newRanges.0, by: .adding),
            FixImpact(in: newRanges.1, by: .adding)
        ])
    }
    
    public func simpleDescription(in source: Substring) -> String {
        return "transpose ‘\(location.0.snippet(in: source))’ and ‘\(location.1.snippet(in: source))’"
    }
    
}

public class SuggestingFix: SourceFix {
    
    public let suggestion: String
    public let fix: SourceFix
    
    public init(suggesting suggestion: String, by fix: SourceFix) {
        self.suggestion = suggestion
        self.fix = fix
    }
    
    public convenience init(suggesting suggestion: String, at locations: [SourceLocation]) {
        self.init(suggesting: suggestion, by: NoOpFix(at: locations))
    }
    
    public var locations: [SourceLocation] {
        return fix.locations
    }
    
    public func apply(to source: inout String, initialSource: String, impacts: inout [FixImpact]) throws {
        try fix.apply(to: &source, initialSource: initialSource, impacts: &impacts)
    }
    
    public func contextualDescription(in source: Substring) -> String {
        return description(fixDescription: fix.contextualDescription(in: source))
    }
    public func simpleDescription(in source: Substring) -> String {
        return description(fixDescription: fix.simpleDescription(in: source))
    }
    
    private func description(fixDescription: String) -> String {
        return suggestion.replacingOccurrences(of: "{FIX}", with: fixDescription)
    }
    
}

public enum FixError: Error {
    
    case overlapping
    
    public var localizedDescription: String {
        switch self {
        case .overlapping:
            return "a fix attempted to modify a range modified by a previous fix"
        }
    }
    
}

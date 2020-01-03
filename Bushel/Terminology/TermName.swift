import Foundation

/// The user-facing name of a term, stored in a normalized representation.
public struct TermName: Hashable, Codable, CustomStringConvertible {
    
    public var words: [String] = []
    
    public var normalized: String {
        get {
            words.joined(separator: " ")
        }
        set {
            self = TermName(newValue)
        }
    }
    
    public var description: String {
        normalized
    }
    
    public init<S: StringProtocol>(_ string: S) where S.SubSequence == Substring {
        self.init(TermName.words(in: string))
    }
    
    public init(_ words: [String]) {
        self.words = words
    }
    
    public static func words<S: StringProtocol>(in string: S) -> [String] where S.SubSequence == Substring {
        string.split { $0.isWhitespace }.flatMap { brokenByPunctuation($0) }
    }
    
    public static func nextWord<S: StringProtocol>(in string: S) -> String? where S.SubSequence == Substring {
        words(in: string).first
    }
    
}

private func brokenByPunctuation(_ word: Substring) -> [String] {
    return word.reduce(into: []) { (result: inout [String], c: Character) in
        if c.isWordBreaking {
            result.append(String(c))
        } else {
            if result.isEmpty {
                result.append("")
            }
            if
                let lastLetter = result.last!.last,
                lastLetter.isWordBreaking
            {
                result.append("")
            }
            result[result.index(before: result.endIndex)].append(c)
        }
    }
}

extension Character {
    
    public var isWordBreaking: Bool {
        return unicodeScalars.allSatisfy(wordBreakingCharacters.contains(_:))
    }
    
}

private let wordBreakingCharacters: CharacterSet =
    CharacterSet.whitespacesAndNewlines
    .union(.punctuationCharacters)
    .union(.symbols)
    .subtracting(CharacterSet(charactersIn: "_.-'’"))

extension TermName: Comparable {
    
    public static func < (lhs: TermName, rhs: TermName) -> Bool {
        lhs.words < rhs.words
    }
    
}

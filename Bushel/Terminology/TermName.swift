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
        var words = string.reduce(into: []) { (result: inout [String], c: Character) in
            if c.isWhitespace {
                if result.last != "" {
                    result.append("")
                }
            } else {
                let breaking = c.isWordBreakingPunctuation
                if breaking && result.last != "" || result.isEmpty {
                    result.append("")
                }
                result[result.index(before: result.endIndex)].append(c)
                if breaking {
                    result.append("")
                }
            }
        }
        if words.last == "" {
            words.removeLast()
        }
        return words
    }
    
    public static func nextWord<S: StringProtocol>(in string: S) -> String? where S.SubSequence == Substring {
        words(in: string).first
    }
    
}

extension Character {
    
    public var isWordBreaking: Bool {
        unicodeScalars.allSatisfy(wordBreakingCharacters.contains(_:))
    }
    
    public var isWordBreakingPunctuation: Bool {
        unicodeScalars.allSatisfy(wordBreakingPunctuationCharacters.contains(_:))
    }
    
}

private let wordBreakingPunctuationCharacters: CharacterSet =
    CharacterSet.punctuationCharacters
    .union(.symbols)
    .subtracting(CharacterSet(charactersIn: "_.-/'’"))
private let wordBreakingCharacters: CharacterSet =
    CharacterSet.whitespacesAndNewlines
    .union(wordBreakingPunctuationCharacters)

extension TermName: Comparable {
    
    public static func < (lhs: TermName, rhs: TermName) -> Bool {
        lhs.words < rhs.words
    }
    
}

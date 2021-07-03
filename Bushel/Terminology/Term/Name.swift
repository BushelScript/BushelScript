import Foundation

extension Term {
    
    /// The user-facing name of a term, stored in a normalized representation.
    public struct Name: Hashable, Codable {
        
        public init(_ words: [String]) {
            self.words = words
        }
        
        public var words: [String] = []
        
    }
    
}

// MARK: String → term name
extension Term.Name {
    
    public init<S: StringProtocol>(_ string: S) where S.SubSequence == Substring {
        self.init(Term.Name.words(in: string))
    }
    
    public static func words<S: StringProtocol>(in string: S) -> [String] where S.SubSequence == Substring {
        var words: [String] = []
        var word = ""
        for c in string {
            let isWhitespace = c.isWhitespace
            let isWordBreaking = isWhitespace || c.isWordBreakingPunctuation
            if isWordBreaking, !word.isEmpty {
                words.append(word)
                word = ""
            }
            if !isWhitespace {
                if isWordBreaking {
                    words.append(String(c))
                } else {
                    word.append(c)
                }
            }
        }
        if !word.isEmpty {
            words.append(word)
        }
        return words
    }
    
    public static func nextWord<S: StringProtocol>(in string: S) -> String? where S.SubSequence == Substring {
        words(in: string).first
    }
    
}

// MARK: Term name → normalized string
extension Term.Name: CustomStringConvertible {
    
    public static let wordSeparator = " "
    
    public var description: String {
        normalized
    }
    
    public var normalized: String {
        get {
            words.joined(separator: Term.Name.wordSeparator)
        }
        set {
            self = Term.Name(newValue)
        }
    }
    
}

// MARK: Comparable
extension Term.Name: Comparable {
    
    public static func < (lhs: Term.Name, rhs: Term.Name) -> Bool {
        lhs.words < rhs.words
    }
    
}

extension Character {
    
    @inlinable public var isWordBreaking: Bool {
        unicodeScalars.allSatisfy(wordBreakingCharacters.contains(_:))
    }
    
    @inlinable public var isWordBreakingPunctuation: Bool {
        unicodeScalars.allSatisfy(wordBreakingPunctuationCharacters.contains(_:))
    }
    
}

public let wordBreakingPunctuationCharacters: CharacterSet =
    CharacterSet.punctuationCharacters
    .union(.symbols)
    .subtracting(CharacterSet(charactersIn: "_.-?"))
public let wordBreakingCharacters: CharacterSet =
    CharacterSet.whitespacesAndNewlines
    .union(wordBreakingPunctuationCharacters)

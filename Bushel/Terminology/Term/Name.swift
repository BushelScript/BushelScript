import Foundation

// MARK: Definition
extension Term {
    
    /// The user-facing name of a term, stored in a normalized representation.
    public struct Name: Hashable, Codable, CustomStringConvertible {
        
        public static let separator = " "
        
        public var words: [String] = []
        
        public var normalized: String {
            get {
                words.joined(separator: Term.Name.separator)
            }
            set {
                self = Term.Name(newValue)
            }
        }
        
        public var description: String {
            normalized
        }
        
        public init<S: StringProtocol>(_ string: S) where S.SubSequence == Substring {
            self.init(Term.Name.words(in: string))
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

extension Term.Name: Comparable {
    
    public static func < (lhs: Term.Name, rhs: Term.Name) -> Bool {
        lhs.words < rhs.words
    }
    
}

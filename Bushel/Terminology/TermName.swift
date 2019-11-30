import Foundation

/// The user-facing name of a term, stored in a normalized representation.
public struct TermName: Hashable, Codable, CustomStringConvertible {
    
    public var words: [String] = []
    public var scopes: [TermName] = []
    
    public var normalizedWords: String {
        words.joined(separator: " ")
    }
    public var normalizedScopes: String {
        scopes.isEmpty ? "" : scopes.map { $0.normalized }.joined(separator: " : ")
    }
    
    public var normalized: String {
        get {
            (scopes.isEmpty ? "" : normalizedScopes + " : ") + normalizedWords
        }
        set {
            self = TermName(newValue)
        }
    }
    
    public var description: String {
        return normalized
    }
    
    public init<S: StringProtocol>(_ string: S) where S.SubSequence == Substring {
        var scopeNames = string.split(separator: ":")
        guard !scopeNames.isEmpty else {
            return
        }
        let mainName = scopeNames.removeLast()
        
        for scopeName in scopeNames {
            scopes.append(TermName(scopeName))
        }
        
        words = TermName.words(in: mainName)
    }
    
    public init(_ words: [String]) {
        self.words = words
    }
    
    public static func words<S: StringProtocol>(in string: S) -> [String] where S.SubSequence == Substring {
        return string.split { $0.isWhitespace }.flatMap { brokenByPunctuation($0) }
    }
    
    public static func nextWord<S: StringProtocol>(in string: S) -> String? where S.SubSequence == Substring {
        return words(in: string).first
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
        if lhs.scopes != rhs.scopes {
            return lhs.scopes < rhs.scopes
        } else {
            return lhs.words < rhs.words
        }
    }
    
}

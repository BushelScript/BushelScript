import Foundation

public struct TermDoc: Hashable, CustomStringConvertible {
    
    public init(term: Term, summary: String, discussion: String) {
        self.term = term
        self.summary = summary
        self.discussion = discussion
    }
    
    public var term: Term
    public var summary: String
    public var discussion: String
    
    public init(term: Term, doc: String = "") {
        let firstSentence = NLP.firstSentence(in: doc)
        let afterFirstSentence = doc[firstSentence.endIndex...]
        
        let summary = String(firstSentence)
        let discussion = String(afterFirstSentence)
        self.init(term: term, summary: summary, discussion: discussion)
    }
    
    public static func == (_ lhs: TermDoc, _ rhs: TermDoc) -> Bool {
        lhs.term == rhs.term
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(term)
    }
    
    public var description: String {
        summary + (discussion.isEmpty ? "" : "\n\n\(discussion)")
    }
    
}

// MARK: Comparison
extension TermDoc: Comparable {
    
    public static func < (lhs: TermDoc, rhs: TermDoc) -> Bool {
        lhs.term < rhs.term
    }
    
}

// MARK: NLP
private enum NLP {
    
    private static let sentenceTagger = NSLinguisticTagger(tagSchemes: [], options: 0)
    
    static func firstSentence(in string: String) -> Substring {
        guard !string.isEmpty else {
            return string[...]
        }
        sentenceTagger.string = string
        let sentenceNSRange = sentenceTagger.tokenRange(at: 0, unit: .sentence)
        return string[Range(sentenceNSRange, in: string)!]
    }
    
}

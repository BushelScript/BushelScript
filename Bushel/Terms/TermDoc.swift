import Foundation

public struct TermDoc: Hashable {
    
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
    
}

// MARK: Comparison
extension TermDoc: Comparable {
    
    public static func < (lhs: TermDoc, rhs: TermDoc) -> Bool {
        lhs.term < rhs.term
    }
    
}

// MARK: NLP
private enum NLP {
    
    static func firstSentence(in string: String) -> Substring {
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
        tagger.string = string
        let sentenceNSRange = tagger.tokenRange(at: 0, unit: .sentence)
        return string[Range(sentenceNSRange, in: string)!]
    }
    
}

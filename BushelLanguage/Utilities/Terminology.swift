import Bushel

public extension Collection where Element == TermName {
    
    func findTermName(in source: Substring) -> (termString: Substring, termName: TermName?) {
        let line = source.prefix(while: { !$0.isNewline })
        guard let lastNonWhitespace = line.lastIndex(where: { !$0.isWhitespace }) else {
            // Only whitespace
            return (source[source.startIndex..<source.startIndex], nil)
        }
        
        let initialWords = TermName(String(source[...lastNonWhitespace])).words
        
        var candidates = self.filter { $0.words.first == initialWords.first }
        guard !candidates.isEmpty else {
            // No match
            return (source[source.startIndex..<source.startIndex], nil)
        }
        
        // We now know that we have *some* kind of match.
        // It could be near or it could be far.
        // i.e., for the set of terms {'bacon', 'bacon and eggs'},
        // A string starting with `bacon` could match either but is guaranteed
        // to match one.
        
        for wordsKept in initialWords.indices {
            guard candidates.count > 1 else {
                // Already have a single match
                break
            }
            
            let newCandidates = candidates.filter { $0.words[...wordsKept] == initialWords[...wordsKept] }
            guard !newCandidates.isEmpty else {
                // There is no more-specific term name to eat.
                break
            }
            
            candidates = newCandidates
        }
        
        let termName = candidates.first!
        var termString = line
        
        let wordsRemovedCount = initialWords.count - termName.words.count
        let wordsRemoved = initialWords.suffix(wordsRemovedCount)
        
        for word in wordsRemoved.reversed() {
            // Word
            termString.removeLast(word.count)
            // Whitespace after last word
            guard let lastNonWhitespace = termString.lastIndex(where: { !$0.isWhitespace }) else {
                break
            }
            termString = termString[...lastNonWhitespace]
        }
        
        return (termString, termName)
    }
    
}

public extension Lexicon {
    
    mutating func add(_ term: LocatedTerm) {
        add(term.wrappedTerm)
    }
    
}

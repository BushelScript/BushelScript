import Bushel

public extension Array where Element == TermName {
    
    func findTermName(in source: Substring) -> (termString: Substring, termName: TermName?) {
        let line = source.prefix(while: { !$0.isNewline })
        guard let lastNonWhitespace = line.lastIndex(where: { !$0.isWhitespace }) else {
            // Only whitespace
            return (source[source.startIndex..<source.startIndex], nil)
        }
        
        var termName = TermName(String(source[...lastNonWhitespace]))
        let initialWords = termName.words
        
        repeat {
            if self.contains(termName) {
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
            
            termName.words.removeLast()
        } while !termName.words.isEmpty
        
        // No match
        return (source[source.startIndex..<source.startIndex], nil)
    }
    
}

public extension Lexicon {
    
    mutating func add(_ term: LocatedTerm) {
        add(term.wrappedTerm)
    }
    
}

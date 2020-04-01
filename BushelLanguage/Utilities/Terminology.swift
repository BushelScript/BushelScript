import Bushel

public extension Collection where Element == TermName {
    
    func findTermName(in source: Substring) -> (termString: Substring, termName: TermName?) {
        let line = source.prefix(while: { !$0.isNewline })
        guard let lastNonWhitespace = line.lastIndex(where: { !$0.isWhitespace }) else {
            // Only whitespace
            return (source[source.startIndex..<source.startIndex], nil)
        }
        
        let initialTermName = TermName(String(source[...lastNonWhitespace]))
        let initialWords = initialTermName.words
        
        var words: [String] = []
        var matches: [TermName?] = []
        var candidates = [TermName](self) // Just an optimization
        
        for word in initialWords {
            words.append(word)
            let termName = TermName(words)
            
            matches.append(self.contains(termName) ? termName : nil)
            
            candidates.removeAll { (candidate: TermName) -> Bool in
                candidate.words.count < words.count || candidate.words[..<words.count] != ArraySlice(words)
            }
            if candidates.isEmpty {
                // No more-specific term name can be matched
                break
            }
        }
        
        guard let termName = matches.last(where: { $0 != nil }) as? TermName else {
            // No match
            return (source[source.startIndex..<source.startIndex], nil)
        }
        
        var termString = line
        
        let wordsRemovedCount = initialWords.count - termName.words.count
        let wordsRemoved = initialWords.suffix(wordsRemovedCount)
        
        for word in wordsRemoved.reversed() {
            termString.removeTrailingWhitespace()
            termString.removeLast(word.count)
        }
        termString.removeTrailingWhitespace()
        
        return (termString, termName)
    }
    
}

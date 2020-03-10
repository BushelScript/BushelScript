import Bushel

public extension Array where Element == TermName {
    
    func findTermName(in source: Substring) -> (termString: Substring, termName: TermName?) {
        var line = source.prefix(while: { !$0.isNewline })
        guard let lastNonWhitespace = line.lastIndex(where: { !$0.isWhitespace }) else {
            // Only whitespace
            return (source[source.startIndex..<source.startIndex], nil)
        }
        
        var termName = TermName(String(source[...lastNonWhitespace]))
        
        repeat {
            if self.contains(termName) {
                return (line, termName)
            }
            
            // Word
            line.removeLast(termName.words.last!.count)
            // Whitespace after word
            guard let lastNonWhitespace = line.lastIndex(where: { !$0.isWhitespace }) else {
                break
            }
            line = line[...lastNonWhitespace]
            
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

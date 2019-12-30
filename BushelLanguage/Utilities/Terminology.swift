import Bushel

public extension Array where Element == TermName {
    
    func findTermName(in source: Substring) -> (termString: Substring, termName: TermName?) {
        var termString = source
        while let lastNonWhitespace = termString.lastIndex(where: { !$0.isWhitespace }) {
            termString = termString[...lastNonWhitespace]
            
            let termName = TermName(String(termString))
            if self.contains(termName) {
                return (termString, termName)
            } else if let lastWord = termName.words.last {
                termString.removeLast(lastWord.count)
            } else if !termString.isEmpty {
                termString.removeLast()
            }
        }
        return (termString, nil)
    }
    
}

public extension Lexicon {
    
    mutating func add(_ term: LocatedTerm) {
        add(term.wrappedTerm)
    }
    
}

import Bushel

public extension Collection where Element == TermName {
    
    func findSimpleTermName(in source: Substring) -> (termString: Substring, termName: TermName?) {
        func noMatch() -> (termString: Substring, termName: TermName?) {
            (source[..<source.startIndex], nil)
        }
        if source.isEmpty {
            return noMatch()
        }
        var word = source.removingLeadingWhitespace().prefix(while: { !$0.isWordBreaking })
        if word.isEmpty {
            word = source[...source.startIndex]
        }
        let termName = TermName(word)
        if self.contains(termName) {
            return (word, termName)
        } else {
            return noMatch()
        }
    }
    
}

public typealias TermNameTraversalTable = [TermName : [TermName]]

public func findComplexTermName(from dictionary: TermNameTraversalTable, in source: Substring) -> (termString: Substring, termName: TermName?) {
    let line = source
        .removingLeadingWhitespace()
        .prefix(while: { !$0.isNewline })
        .removingTrailingWhitespace()
    
    // Advance endIndex to 1 past the end of each word in the line until
    // a term name matches those words, or we reach the end of the line.
    var endIndex = line.startIndex
    var largestMatchEndIndex = endIndex
    while true {
        func largestMatch() -> (termString: Substring, termName: TermName?) {
            let matchedSource = line[..<largestMatchEndIndex]
            return (matchedSource, matchedSource.isEmpty ? nil : TermName(matchedSource))
        }
        
        endIndex =
            line[endIndex...]
            .drop(while: { $0.isWhitespace })
            .drop(while: { !$0.isWhitespace })
            .startIndex
        
        guard let subsequentWords = dictionary[TermName(line[..<endIndex])] else {
            // There are no possible larger matches than whatever we've already matched.
            return largestMatch()
        }
        
        if subsequentWords.contains(TermName([])) {
            // Can match this iteration.
            largestMatchEndIndex = endIndex
            
            if subsequentWords.count == 1 {
                // No possible larger matches.
                return largestMatch()
            }
            
            // If we get here, a larger match in a future iteration is possible.
            // (If we find that there are no larger matches, however,
            // this match will be used.)
        }
        
        if endIndex == line.endIndex {
            // No future iterations possible.
            return largestMatch()
        }
        
        // If we get here, there is a possible match in a future iteration.
    }
}
    
public func buildTraversalTable<TermNames: Collection>(
    for termNames: TermNames
) -> TermNameTraversalTable
where TermNames.Element == TermName
{
    var traversalTable: TermNameTraversalTable = [:]
    for termName in termNames {
        for wordIndex in termName.words.indices {
            let currentWords = TermName(Array(termName.words[...wordIndex]))
            let subsequentWords = TermName(Array(termName.words[(wordIndex + 1)...]))
            if traversalTable.keys.contains(currentWords) {
                traversalTable[currentWords]!.append(subsequentWords)
            } else {
                traversalTable[currentWords] = [subsequentWords]
            }
        }
    }
    return traversalTable
}


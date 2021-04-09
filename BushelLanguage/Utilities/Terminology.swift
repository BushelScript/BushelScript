import Bushel

public typealias TermNameTraversalTable = [Term.Name : [Term.Name]]

public func findComplexTermName(from dictionary: TermNameTraversalTable, in source: Substring) -> (termString: Substring, termName: Term.Name?) {
    let line = source
        .removingLeadingWhitespace()
        .prefix(while: { !$0.isNewline })
        .removingTrailingWhitespace()
    
    // Advance endIndex to 1 past the end of each word in the line until
    // a term name matches those words, or we reach the end of the line.
    var endIndex = line.startIndex
    var largestMatchEndIndex = endIndex
    while true {
        func largestMatch() -> (termString: Substring, termName: Term.Name?) {
            let matchedSource = line[..<largestMatchEndIndex]
            return (matchedSource, matchedSource.isEmpty ? nil : Term.Name(matchedSource))
        }
        
        endIndex =
            line[endIndex...]
            .drop(while: { $0.isWhitespace })
            .drop(while: { !$0.isWhitespace })
            .startIndex
        
        guard let subsequentWords = dictionary[Term.Name(line[..<endIndex])] else {
            // There are no possible larger matches than whatever we've already matched.
            return largestMatch()
        }
        
        if subsequentWords.contains(Term.Name([])) {
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
where TermNames.Element == Term.Name
{
    var traversalTable: TermNameTraversalTable = [:]
    for termName in termNames {
        for wordIndex in termName.words.indices {
            let currentWords = Term.Name(Array(termName.words[...wordIndex]))
            let subsequentWords = Term.Name(Array(termName.words[(wordIndex + 1)...]))
            if traversalTable.keys.contains(currentWords) {
                traversalTable[currentWords]!.append(subsequentWords)
            } else {
                traversalTable[currentWords] = [subsequentWords]
            }
        }
    }
    return traversalTable
}


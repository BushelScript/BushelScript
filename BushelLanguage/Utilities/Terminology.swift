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
    while true {
        let subsequentWordsStartIndex = endIndex
        endIndex =
            line[endIndex...]
            .drop(while: { $0.isWhitespace })
            .drop(while: { !$0.isWhitespace })
            .startIndex
        guard let subsequentWords = dictionary[TermName(line[..<endIndex])] else {
            // There are no possible longer matches of what we've already matched.
            // Return the last match (or no match if there is no last match).
            let matchedSource = line[..<subsequentWordsStartIndex]
            return (matchedSource, matchedSource.isEmpty ? nil : TermName(matchedSource))
        }
        if subsequentWords.contains(TermName([])) {
            // Can match this iteration.
            if subsequentWords.count == 1 || endIndex == line.endIndex {
                // Exact match with no possible longer matches.
                let matchedSource = line[..<endIndex]
                return (matchedSource, TermName(matchedSource))
            } else {
                // We could have matched this iteration,
                // but longer matches are also possible.
                continue
            }
        } else {
            // Cannot possibly match this iteration.
            if endIndex == line.endIndex {
                // No matches possible.
                return (line[..<line.startIndex], nil)
            } else {
                // Possible match in future iteration.
                continue
            }
        }
    }
    
    // TMR: This is slow because we are not backing out early enough.
    //      Need to ideally filter the set word by word, and abort
    //      the moment the set reaches 1 matching element, or 0 elements.
    //      Might use hash table to expedite reaching that new set (precompute them all).
    // ["a": ["b", "c", "b c"], "a b": ["", "c"]]
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


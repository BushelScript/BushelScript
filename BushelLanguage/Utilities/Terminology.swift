import Bushel

public extension TerminologySource {
    
    // TODO: Should move to SourceParser and take TerminologySource as a
    //       parameter so proper source locations can be constructed.
    func findTerm(in sourceCode: Substring) throws -> (termString: Substring, term: Term?) {
        var termString = sourceCode
        while let lastNonWhitespace = termString.lastIndex(where: { !$0.isWhitespace }) {
            termString = termString[...lastNonWhitespace]
            
            var termName = TermName(String(termString))
            let scopes = termName.scopes
            
            if scopes.isEmpty {
                if let term = self.term(named: termName) {
                    return (termString, term)
                } else {
                    termString.removeLast(termName.words.last!.count)
                }
            } else {
                let outerSource = self.term(named: scopes.first!) as? TermDictionaryContainer
                guard
                    let innermostSource = scopes.dropFirst().reduce(outerSource?.terminology, { (source: TermDictionary?, scopeName: TermName) -> TermDictionary? in
                        (source?.term(named: scopeName) as? TermDictionaryContainer)?.terminology
                    })
                else {
                    throw ParseError(description: "no such dictionary ‘\(termName.normalizedScopes)’", location: SourceLocation(termString.range, source: String(sourceCode)))
                }
                
                let scopelessTermName = TermName(termName.words)
                if let term = innermostSource.term(named: scopelessTermName) as? Term {
                    return (termString, term)
                } else {
                    termString.removeLast(termName.words.last!.count)
                    termName = TermName(termString)
                }
            }
        }
        
        let startIndex = sourceCode.startIndex
        if var rawFormString = sourceCode.removingPrefix("«") {
            rawFormString.removeLeadingWhitespace()
            
            let kind: RawSpecifierKind
            if rawFormString.removePrefix("constant") {
                kind = .constant
            } else if rawFormString.removePrefix("class") {
                kind = .class_
            } else if rawFormString.removePrefix("property") {
                kind = .property
            } else if rawFormString.removePrefix("parameter") {
                kind = .parameter
            } else {
                throw ParseError(description: "invalid raw specifier type", location: SourceLocation(at: rawFormString.startIndex, source: String(sourceCode)))
            }
            
            rawFormString.removeLeadingWhitespace()
            if rawFormString.removePrefix("»") {
                guard let term = kind.termType.init("empty-\(UUID().uuidString)", name: TermName(""), code: nil) as? Self.Term else {
                    throw ParseError(description: "wrong type of term for context", location: SourceLocation(at: rawFormString.startIndex, source: String(sourceCode)))
                }
                return (sourceCode[startIndex..<rawFormString.endIndex], term)
            }
            
            guard rawFormString.count >= 5 else {
                throw ParseError(description: "expected four-character code string", location: SourceLocation(at: rawFormString.startIndex, source: String(sourceCode)))
            }
            guard let code = try? FourCharCode(fourByteString: String(rawFormString[..<rawFormString.index(rawFormString.startIndex, offsetBy: 4)])) else {
                throw ParseError(description: "could not parse four-character code", location: SourceLocation(at: rawFormString.startIndex, source: String(sourceCode)))
            }
            rawFormString.removeFirst(4)
            rawFormString.removeLeadingWhitespace()
            guard rawFormString.removePrefix("»") else {
                throw ParseError(description: "expected ‘»’", location: SourceLocation(at: rawFormString.startIndex, source: String(sourceCode)))
            }

            // TODO: incorporate dictionary name and term type into uid
            guard let term = kind.termType.init("\(String(fourCharCode: code))", name: TermName(""), code: code) as? Self.Term else {
                throw ParseError(description: "wrong type of term for context", location: SourceLocation(at: rawFormString.startIndex, source: String(sourceCode)))
            }
            return (sourceCode[startIndex..<rawFormString.endIndex], term)
        }
        
        return (termString, nil)
    }
    
}

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

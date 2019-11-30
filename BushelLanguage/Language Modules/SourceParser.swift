import Bushel

public struct ParseError: Error {
    
    public let description: String
    public var location: SourceLocation
    public let fixes: [SourceFix]
    
    public init(description: String, location: SourceLocation, fixes: [SourceFix] = []) {
        self.description = description
        self.location = location
        self.fixes = fixes
    }
}

extension ParseError: CodableLocalizedError {
    
    public var errorDescription: String? {
        return description
    }
    
}

public typealias KeywordHandler = () throws -> Expression.Kind?

/// Parses source code into an AST.
public protocol SourceParser: AnyObject {
    
    var entireSource: String { get }
    var source: Substring { get set }
    var expressionStartIndex: String.Index { get set }
    
    var lexicon: Lexicon { get set }
    var currentElements: [[PrettyPrintable]] { get set }
    
    var keywords: [TermName : KeywordHandler] { get }
    var defaultTerms: [TermDescriptor] { get }
    var binaryOperators: [TermName : BinaryOperation] { get }
    
    init(source: String)
    
    func handle(term: LocatedTerm) throws -> Expression.Kind?
    
    /// For any required post-processing.
    /// e.g., possessive specifiers (like "xyz's first widget") modify
    ///       the preceding primary.
    /// Return nil to accept `primary` as-is.
    /// This method is called repeatedly, and its result used as the new primary
    /// expression, until the result is nil.
    func postprocess(primary: Expression) throws -> Expression.Kind?
    
}

public extension SourceParser {
    
    func parse() throws -> Program {
        signpostBegin()
        defer { signpostEnd() }
        
        guard !source.isEmpty else {
            return Program(Expression.empty(at: source.startIndex), source: entireSource, terms: TermPool())
        }
        
        currentElements = []
        
        lexicon.add(ParameterDescriptor(.direct, name: TermName("")).realize(lexicon.pool))
        
        for descriptor in defaultTerms {
            lexicon.add(descriptor.realize(lexicon.pool))
        }
        
        do {
            let ast: Expression
            if let sequence = try parseSequence() {
                ast = Expression(.scoped(sequence), at: SourceLocation(entireSource.range, source: entireSource))
            } else {
                ast = Expression(.empty, at: SourceLocation(entireSource.range, source: entireSource))
            }
            return Program(ast, source: entireSource, terms: lexicon.pool)
        } catch var error as ParseError {
            if !entireSource.range.contains(error.location.range.lowerBound) {
                error.location.range = entireSource.index(before: entireSource.endIndex)..<entireSource.endIndex
            }
            throw error
        }
    }
    
    func parseSequence(stoppingAt stopKeywords: [String] = []) throws -> Sequence? {
        var expressions: [Expression] = []
        
        func eatNewlines() {
            source.removeLeadingWhitespace()
            while let newline = parseNewline() {
                expressions.append(newline)
            }
        }
        
        eatNewlines()
        
        while true {
            if source.isEmpty || stopKeywords.contains(where: { source.hasPrefix($0) }) {
                break
            }
            
            if let primary = try parsePrimary() {
                expressions.append(primary)
                if case Expression.Kind.end = primary.kind {
                    break
                }
            }
            
            source.removeLeadingWhitespace()
            guard parseNewline() != nil || source.isEmpty else {
                let nextNewline = source.firstIndex(where: { $0.isNewline }) ?? source.endIndex
                let location = SourceLocation(source.startIndex..<nextNewline, source: entireSource)
                throw ParseError(description: "expected line break after sequenced expression", location: location, fixes: [PrependingFix(prepending: "\n", at: location)])
            }
            
            eatNewlines()
        }
        
        return expressions.isEmpty ? nil : Sequence(expressions: expressions, location: SourceLocation(expressions.first!.location.range.lowerBound..<expressions.last!.location.range.upperBound, source: entireSource))
    }
    
    func parsePrimary(lastOperation: BinaryOperation? = nil) throws -> Expression? {
        currentElements.append([])
        defer {
            currentElements.removeLast()
        }
        
        guard var primary = try parseUnprocessedPrimary() else {
            return nil
        }
        
        while let processedPrimary = try processOperators(after: primary, lastOperation: lastOperation) {
            primary = processedPrimary
        }
        
        while let processedPrimary = try postprocess(primary: primary) {
            primary = Expression(processedPrimary, primary.elements, at: expressionLocation)
        }
        
        return primary
    }
    
    private func processOperators(after lhs: Expression, lastOperation: BinaryOperation?) throws -> Expression? {
        guard let (_, operation) = findBinaryOperator() else {
            // There's no binary operator here, so we're done.
            return nil
        }
        
        // A nil lastOperation means this is the first binary operator in
        // the (potential) chain.
        let lhsPrecedence = lastOperation?.precedence ?? .identity
        let rhsPrecedence = operation.precedence
        let lhsAssociativity = lhsPrecedence.associativity
        
        // Using the expression `1 @ 2 # 3` as an example,
        // where @ and # are both binary operators...
        if
            rhsPrecedence > lhsPrecedence ||
            (lhsPrecedence == rhsPrecedence && lhsAssociativity == .right)
        {
            // If either:
            //   • # has higher precedence than @, or
            //   • @ and # have equal precedence and such precedence group
            //     is right-associative,
            // then the expression is parsed as 1 @ (2 # 3).
            // e.g., 1 + 2 * 3
            //     = 1 + (2 * 3).
            
            // We need to handle the # operator and pass the resulting
            // expression back to the parse call that's parsing the lhs.
            
            eatBinaryOperator()
            
            let totalExpressionStartIndex = expressionStartIndex
            source.removeLeadingWhitespace()
            guard let rhs = try parsePrimary(lastOperation: operation) else {
                throw ParseError(description: "expected expression after binary operator", location: currentLocation)
            }
            
            expressionStartIndex = totalExpressionStartIndex
            return Expression(.infixOperator(operation: operation, lhs: lhs, rhs: rhs), currentElements.last!, at: expressionLocation)
        } else if
            lhsPrecedence > rhsPrecedence ||
            (lhsPrecedence == rhsPrecedence && lhsAssociativity == .left)
        {
            // Otherwise, either:
            //   • @ has higher precedence than #, or
            //   • @ and # have equal precedence and such precedence group
            //     is left-associative,
            // then the expression is parsed as (1 @ 2) # 3.
            // e.g., 1 * 2 + 3    and  1 - 2 - 3
            //     = (1 * 2) + 3.    = (1 - 2) - 3, not 1 - (2 - 3).
            
            // Halt operator processing for this expression, and
            // let the outer parse call handle the # operator.
            return nil
        } else {
            fatalError("unhandled operator grouping case!")
        }
    }
    
    private func parseUnprocessedPrimary() throws -> Expression? {
        if let hashbang = eatHashbang() {
            expressionStartIndex = hashbang.location.range.lowerBound
            var hashbangs = [hashbang]
            var endHashbangLocation: SourceLocation?
            var bodies = [""]
            
            while !source.isEmpty {
                source.removeFirst() // leading newline
                if let newHashbang = eatHashbang() {
                    hashbangs.append(newHashbang)
                    if newHashbang.invocation == "bushelscript" {
                        endHashbangLocation = newHashbang.location
                        break
                    } else {
                        bodies.append("")
                    }
                } else {
                    let line = String(source.prefix { !$0.isNewline })
                    print(source)
                    bodies[bodies.index(before: bodies.endIndex)] += "\(line)\n"
                    source.removeFirst(line.count)
                }
            }
            
            let weaves = zip(hashbangs.indices, bodies).map { (pair: (Int, String)) -> Expression in
                let (hashbangIndex, body) = pair
                let hashbang = hashbangs[hashbangIndex]
                
                if hashbangs.indices.contains(hashbangIndex + 1) {
                    let nextHashbang = hashbangs[hashbangIndex + 1]
                    return Expression(.weave(hashbang: hashbang, body: body), at: SourceLocation(hashbang.location.range.lowerBound..<nextHashbang.location.range.lowerBound, source: entireSource))
                } else if let endLocation = endHashbangLocation {
                    // Program continues after a #!bushelscript at endLocation
                    return Expression(.endWeave, at: endLocation)
                } else {
                    // Program ends in a weave
                    return Expression(.weave(hashbang: hashbang, body: body), at: SourceLocation(hashbang.location.range.lowerBound..<currentIndex, source: entireSource))
                }
            }
            
            return Expression(.scoped(Sequence(expressions: weaves, location: expressionLocation)), at: expressionLocation)
        } else if case let (termString, termName?) = eatKeyword() {
            expressionStartIndex = termString.startIndex
            source.removeLeadingWhitespace()
            if let kind = try keywords[termName]!() {
                return Expression(kind, currentElements.last!, at: expressionLocation)
            } else {
                return nil
            }
        } else if case let (termString, term?) = try eatTerm() {
            expressionStartIndex = termString.startIndex
            source.removeLeadingWhitespace()
            if let kind = try handle(term: Located(term, at: SourceLocation(termString.range, source: entireSource))) {
                return Expression(kind, currentElements.last!, at: expressionLocation)
            } else {
                return nil
            }
        } else {
            source.removeLeadingWhitespace()
            guard let c = source.first else {
                return nil
            }
            
            expressionStartIndex = currentIndex
        
            if c.isNumber {
                let regex = try! NSRegularExpression(pattern: "[-+]?(?:0x)?\\d*(?:\\.\\d+(?:[ep][-+]?\\d+)?)?", options: [.caseInsensitive])
                guard let numberNSRange = regex.firstMatch(in: String(source), options: [], range: NSRange(source.range, in: source))?.range else {
                    throw ParseError(description: "unable to parse number", location: currentLocation)
                }
                let numberRange = Range(numberNSRange, in: String(source))!
                let numberEndIndex = source.index(currentIndex, offsetBy: source.distance(from: numberRange.lowerBound, to: numberRange.upperBound))
                let numberSource = source[currentIndex..<numberEndIndex]
                source.removeFirst(numberSource.count)
                
                guard let value = Double(numberSource) else {
                    throw ParseError(description: "unable to parse number", location: SourceLocation(numberSource.range, source: entireSource))
                }
                return Expression(.number(value), [Keyword(keyword: String(numberSource), styling: .number)], at: SourceLocation(numberSource.range, source: entireSource))
            } else if c == "\"" {
                let regex = try! NSRegularExpression(pattern: "\".*?(?<!\\\\)\"", options: [])
                guard let stringNSRange = regex.firstMatch(in: String(source), options: [], range: NSRange(source.range, in: source))?.range else {
                    throw ParseError(description: "unable to parse string", location: currentLocation)
                }
                let stringRange = Range(stringNSRange, in: String(source))!
                let stringEndIndex = source.index(currentIndex, offsetBy: source.distance(from: stringRange.lowerBound, to: stringRange.upperBound))
                let stringSource = source[currentIndex..<stringEndIndex]
                source.removeFirst(stringSource.count)
                
                let value = stringSource[stringSource.index(after: stringSource.startIndex)..<stringSource.index(before: stringSource.endIndex)] // Without quotes
                return Expression(.string(String(value)), [Keyword(keyword: String(stringSource), styling: .string)], at: SourceLocation(stringSource.range, source: entireSource))
            } else if c == ")" {
                let location = SourceLocation(currentIndex..<source.index(after: currentIndex), source: entireSource)
                
                let beforeNewline = entireSource[(entireSource[...location.range.lowerBound].lastIndex(where: { $0.isNewline }) ?? entireSource.startIndex)...]
                let startParenInsertLocation = SourceLocation(at: beforeNewline.firstIndex(where: { !$0.isWordBreaking }) ?? beforeNewline.startIndex, source: entireSource)
                
                throw ParseError(description: "expected expression but found stray ‘)’", location: location, fixes: [DeletingFix(at: location), PrependingFix(prepending: "(", at: startParenInsertLocation)])
            } else {
                print("undefined term source: \(source)")
                throw ParseError(description: "undefined term; perhaps you made a typo?", location: SourceLocation(currentIndex..<(source.firstIndex(where: { $0.isNewline }) ?? source.endIndex), source: entireSource))
            }
        }
    }
    
    func parseTermNameEagerly(stoppingAt: [String] = []) throws -> (TermName, SourceLocation)? {
        let restOfLine = source.prefix { !$0.isNewline }
        let startIndex = restOfLine.startIndex
        let words = TermName.words(in: restOfLine)
        
        guard !words.isEmpty else {
            return nil
        }
        
        var shrunkWords = words
        for word in words.reversed() {
            shrunkWords.removeLast()
            if stoppingAt.contains(word) {
                eatFromSource(shrunkWords)
                let endIndex = source.startIndex
                return (TermName(shrunkWords), SourceLocation(startIndex..<endIndex, source: entireSource))
            }
        }
        
        // Name did not include any word in stoppingAt
        eatFromSource(words)
        let endIndex = source.startIndex
        return (TermName(words), SourceLocation(startIndex..<endIndex, source: entireSource))
    }
    
    func parseTermNameLazily() throws -> (TermName, SourceLocation)? {
        let restOfLine = source.prefix { !$0.isNewline }
        let startIndex = restOfLine.startIndex
        let words = TermName.words(in: restOfLine)
        
        guard let firstWord = words.first else {
            return nil
        }
        
        eatFromSource([firstWord])
        if firstWord == "|" {
            for wordIndex in words.indices.dropFirst() {
                if words[wordIndex] == "|" {
                    let wordsWithoutPipes = Array(words[1..<wordIndex])
                    eatFromSource(wordsWithoutPipes + ["|"])
                    return (TermName(wordsWithoutPipes), SourceLocation(startIndex..<source.startIndex, source: entireSource))
                }
            }
            throw ParseError(description: "mismatched ‘|’", location: SourceLocation(startIndex..<source.startIndex, source: entireSource))
        } else {
            return (TermName(firstWord), SourceLocation(startIndex..<source.startIndex, source: entireSource))
        }
    }
    
    private func eatFromSource(_ words: [String]) {
        for word in words {
            source.removeLeadingWhitespace()
            source.removeFirst(word.count)
        }
    }
    
    func parseNewline() -> Expression? {
        guard source.first?.isNewline ?? false else {
            return nil
        }
        let newline = Expression(.empty, [Newline()], at: SourceLocation(source.startIndex..<source.index(after: source.startIndex), source: entireSource))
        source.removeFirst()
        return newline
    }
    
    func eatHashbang() -> Hashbang? {
        guard tryEating(prefix: "#!") else {
            return nil
        }
        
        let invocationSource = source.prefix { !$0.isNewline }
        source.removeFirst(invocationSource.count)
        
        return Hashbang(String(invocationSource), at: expressionLocation)
    }
    
    func eatKeyword() -> (termString: Substring, termName: TermName?) {
        let result = Array(keywords.keys).findTermName(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        if let name = result.termName {
            currentElements[currentElements.endIndex - 1].append(Keyword(keyword: name.normalized))
        }
        return result
    }
    
    func findBinaryOperator() -> (termName: TermName, operator: BinaryOperation)? {
        let result = Array(binaryOperators.keys).findTermName(in: source.prefix(while: { !$0.isNewline }))
        return result.termName.map { name in
            (termName: name, operator: binaryOperators[name]!)
        }
    }
    
    func eatBinaryOperator() {
        let result = Array(binaryOperators.keys).findTermName(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        guard let name = result.termName else {
            return
        }
        currentElements[currentElements.endIndex - 1].append(Keyword(keyword: name.normalized, styling: .operator))
    }
    
    func eatTerm() throws -> (termString: Substring, term: Term?) {
        let result = try lexicon.findTerm(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        if let name = result.term?.name {
            currentElements[currentElements.endIndex - 1].append(Keyword(keyword: name.normalized, styling: .variable))
        }
        return result
    }
    
    func tryEating(prefix target: String) -> Bool {
        source.removeLeadingWhitespace()
        
        if
            source.hasPrefix(target),
            target.last!.isWordBreaking || (source.dropFirst(target.count).first?.isWordBreaking ?? true)
        {
            source.removeFirst(target.count)
            currentElements[currentElements.endIndex - 1].append(Keyword(keyword: target))
            return true
        }
        return false
    }
    
    func withScope(parse: () throws -> Sequence) rethrows -> Expression {
        lexicon.push()
        defer { lexicon.pop() }
        return Expression(.scoped(try parse()), at: expressionLocation)
    }
    
    var currentLocation: SourceLocation {
        return SourceLocation(at: currentIndex, source: entireSource)
    }
    
    var currentIndex: String.Index {
        return source.startIndex
    }
    
    var expressionLocation: SourceLocation {
        return SourceLocation(expressionStartIndex..<currentIndex, source: entireSource)
    }
    
}

public extension StringProtocol {
    
    var range: Range<Index> {
        return startIndex..<endIndex
    }
    
}

// TODO: Make private once findTerm(in:) moves to this file
enum RawSpecifierKind {
    case constant, class_, property, parameter
    
    var termType: ConstantTerm.Type {
        switch self {
        case .constant: return EnumeratorTerm.self
        case .class_: return ClassTerm.self
        case .property: return PropertyTerm.self
        case .parameter: return ParameterTerm.self
        }
    }
}

import Bushel
import SDEFinitely

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
        description
    }
    
}

public typealias KeywordHandler = () throws -> Expression.Kind?

/// Parses source code into an AST.
public protocol SourceParser: AnyObject {
    
    static var sdefCache: [URL : Data] { get set }
    
    var entireSource: String { get }
    var source: Substring { get set }
    var expressionStartIndices: [String.Index] { get set }
    
    var lexicon: Lexicon { get set }
    var currentElements: [[PrettyPrintable]] { get set }
    var awaitingExpressionEndKeywords: [Set<TermName>] { get set }
    var sequenceEndTags: [TermName] { get set }
    
    var keywords: [TermName : KeywordHandler] { get }
    var defaultTerms: [TermDescriptor] { get }
    var prefixOperators: [TermName : UnaryOperation] { get }
    var postfixOperators: [TermName : UnaryOperation] { get }
    var binaryOperators: [TermName : BinaryOperation] { get }
    var lineCommentMarkers: [TermName] { get }
    var blockCommentMarkers: [(begin: TermName, end: TermName)] { get }
    
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
        
        lexicon.push(uid: .id("script"))
        do {
            let ast: Expression
            if let sequence = try parseSequence(TermName("")) {
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
    
    func eatCommentsAndWhitespace(eatingNewlines: Bool = false) {
        func eatLineComment() -> Bool {
            guard eatLineCommentMarker() else {
                return false
            }
            source.removeFirst(while: { !$0.isNewline })
            return true
        }
        func eatBlockComment() -> Bool {
            func awaitEndMarker() {
                while !eatBlockCommentEndMarker(), !source.isEmpty {
                    if eatBlockCommentBeginMarker() {
                        // Handle nested comments au façon Swift
                        /* e.g., /* must end twice */ */
                        awaitEndMarker()
                    }
                    if !source.isEmpty {
                        source.removeFirst()
                    }
                }
            }
            if eatBlockCommentBeginMarker() {
                awaitEndMarker()
                return true
            } else {
                return false
            }
        }
        
        repeat {
            source.removeLeadingWhitespace(removingNewlines: eatingNewlines)
        } while eatBlockComment() || eatLineComment()
    }
    
    func parseSequence(_ endTag: TermName, stoppingAt stopKeywords: [String] = []) throws -> Sequence? {
        sequenceEndTags.append(endTag)
        defer {
            sequenceEndTags.removeLast()
        }
        
        var expressions: [Expression] = []
        
        func eatNewlines() {
            eatCommentsAndWhitespace()
            while let newline = parseNewline() {
                expressions.append(newline)
                eatCommentsAndWhitespace()
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
            
            eatCommentsAndWhitespace()
            
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
        
        guard var primary = try (parsePrefixOperators() ?? parseUnprocessedPrimary()) else {
            return nil
        }
        
        while let processedPrimary = try processBinaryOperators(after: primary, lastOperation: lastOperation) {
            primary = processedPrimary
        }
        
        while let processedPrimary = try (
            postprocess(primary: primary).map {
                Expression($0, primary.elements, at: expressionLocation)
            } ?? parsePostfixOperators()
        ) {
            primary = processedPrimary
        }
        
        return primary
    }
    
    private func processBinaryOperators(after lhs: Expression, lastOperation: BinaryOperation?) throws -> Expression? {
        eatCommentsAndWhitespace()
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
    
    private func parsePrefixOperators() throws -> Expression? {
        eatCommentsAndWhitespace()
        var operations: [UnaryOperation] = []
        while let (_, operation) = findPrefixOperator() {
            operations.append(operation)
            eatPrefixOperator()
        }
        
        var expression: Expression?
        for operation in operations.reversed() {
            eatCommentsAndWhitespace()
            guard let operand = try expression ?? parsePrimary() else {
                throw ParseError(description: "expected expression after prefix operator", location: currentLocation)
            }
            
            expression = Expression(.prefixOperator(operation: operation, operand: operand), currentElements.last!, at: expressionLocation)
        }
        return expression
    }
    
    private func parsePostfixOperators() throws -> Expression? {
        eatCommentsAndWhitespace()
        var expression: Expression?
        while let (_, operation) = findPostfixOperator() {
            eatPostfixOperator()
            
            eatCommentsAndWhitespace()
            guard let operand = try expression ?? parsePrimary() else {
                throw ParseError(description: "expected expression after prefix operator", location: currentLocation)
            }
            
            expression = Expression(.postfixOperator(operation: operation, operand: operand), currentElements.last!, at: expressionLocation)
        }
        return expression
    }
    
    private func parseUnprocessedPrimary() throws -> Expression? {
        eatCommentsAndWhitespace()
        expressionStartIndex = currentIndex
        defer {
            expressionStartIndices.removeLast()
        }
        
        if let hashbang = eatHashbang() {
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
                    #if DEBUG
                    print(source)
                    #endif
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
        } else if let term = try eatTerm() {
            if let kind = try handle(term: Located(term, at: expressionLocation)) {
                return Expression(kind, currentElements.last!, at: expressionLocation)
            } else {
                return nil
            }
        } else if let termName = eatKeyword() {
            if let kind = try keywords[termName]!() {
                return Expression(kind, currentElements.last!, at: expressionLocation)
            } else {
                return nil
            }
        } else {
            if findExpressionEndKeyword() {
                return nil
            }
            
            guard let c = source.first else {
                return nil
            }
            
            if c.isNumber || c == "-" || c == "+" {
                func parseInteger() -> Expression? {
                    let slicedSourceCode = String(source)
                    let regex = try! NSRegularExpression(pattern: "^[-+]?\\d++(?!\\.)", options: [.caseInsensitive])
                    guard let numberNSRange = regex.firstMatch(in: slicedSourceCode, options: [], range: NSRange(source.range, in: source))?.range else {
                        return nil
                    }
                    let numberRange = Range(numberNSRange, in: slicedSourceCode)!
                    let numberEndIndex = source.index(currentIndex, offsetBy: slicedSourceCode.distance(from: numberRange.lowerBound, to: numberRange.upperBound))
                    let numberSource = source[currentIndex..<numberEndIndex]
                    guard let value = Int64(numberSource) else {
                        return nil
                    }
                    source.removeFirst(numberSource.count)
                    
                    return Expression(.integer(value), [Keyword(keyword: String(numberSource), styling: .number)], at: SourceLocation(numberSource.range, source: entireSource))
                }
                func parseDouble() throws -> Expression {
                    let slicedSourceCode = String(source)
                    let regex = try! NSRegularExpression(pattern: "^[-+]?\\d*(?:\\.\\d++(?:[ep][-+]?\\d+)?)?", options: [.caseInsensitive])
                    guard let numberNSRange = regex.firstMatch(in: slicedSourceCode, options: [], range: NSRange(source.range, in: source))?.range else {
                        throw ParseError(description: "unable to parse number", location: currentLocation)
                    }
                    let numberRange = Range(numberNSRange, in: slicedSourceCode)!
                    let numberEndIndex = source.index(currentIndex, offsetBy: slicedSourceCode.distance(from: numberRange.lowerBound, to: numberRange.upperBound))
                    let numberSource = source[currentIndex..<numberEndIndex]
                    source.removeFirst(numberSource.count)
                    
                    guard let value = Double(numberSource) else {
                        throw ParseError(description: "unable to parse number", location: SourceLocation(numberSource.range, source: entireSource))
                    }
                    return Expression(.double(value), [Keyword(keyword: String(numberSource), styling: .number)], at: SourceLocation(numberSource.range, source: entireSource))
                }
                
                return try parseInteger() ?? parseDouble()
            } else if c == "\"" {
                let slicedSourceCode = String(source)
                let regex = try! NSRegularExpression(pattern: "\".*?(?<!\\\\)\"", options: [])
                guard let stringNSRange = regex.firstMatch(in: slicedSourceCode, options: [], range: NSRange(slicedSourceCode.range, in: slicedSourceCode))?.range else {
                    throw ParseError(description: "unable to parse string", location: currentLocation)
                }
                let stringRange = Range(stringNSRange, in: slicedSourceCode)!
                let stringEndIndex = source.index(currentIndex, offsetBy: slicedSourceCode.distance(from: stringRange.lowerBound, to: stringRange.upperBound))
                
                let stringSource = source[currentIndex..<stringEndIndex]
                source.removeFirst(stringSource.count)
                
                let value = stringSource[stringSource.index(after: stringSource.startIndex)..<stringSource.index(before: stringSource.endIndex)] // Without quotes
                return Expression(.string(String(value)), [Keyword(keyword: String(stringSource), styling: .string)], at: SourceLocation(stringSource.range, source: entireSource))
            } else {
                #if DEBUG
                print("undefined term source: \(source)")
                #endif
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
    
    func parseClassTerm() throws -> Located<Bushel.ClassTerm>? {
        guard
            let typeExpression = try parsePrimary(),
            case .class_(let type) = typeExpression.kind
        else {
            return nil
        }
        return Located(type, at: typeExpression.location)
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
    
    func awaiting<Result>(endMarkers: Set<TermName>, perform action: () throws -> Result) rethrows -> Result {
        awaitingExpressionEndKeywords.append(endMarkers)
        defer {
            awaitingExpressionEndKeywords.removeLast()
        }
        return try action()
    }
    
    func awaiting<Result>(endMarker: TermName, perform action: () throws -> Result) rethrows -> Result {
        try awaiting(endMarkers: [endMarker], perform: action)
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
    
    func eatLineCommentMarker() -> Bool {
        let result = lineCommentMarkers.findTermName(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        return result.termName != nil
    }
    
    func eatBlockCommentBeginMarker() -> Bool {
        let result = blockCommentMarkers.map { $0.begin }.findTermName(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        return result.termName != nil
    }
    
    func eatBlockCommentEndMarker() -> Bool {
        let result = blockCommentMarkers.map { $0.end }.findTermName(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        return result.termName != nil
    }
    
    func eatKeyword() -> TermName? {
        let result = Array(keywords.keys).findTermName(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        if let name = result.termName {
            currentElements[currentElements.endIndex - 1].append(Keyword(keyword: name.normalized))
        }
        return result.termName
    }
    
    func findPrefixOperator() -> (termName: TermName, operator: UnaryOperation)? {
        let result = Array(prefixOperators.keys).findTermName(in: source.prefix(while: { !$0.isNewline }))
        return result.termName.map { name in
            (termName: name, operator: prefixOperators[name]!)
        }
    }
    
    func eatPrefixOperator() {
        let result = Array(prefixOperators.keys).findTermName(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        guard let name = result.termName else {
            return
        }
        currentElements[currentElements.endIndex - 1].append(Keyword(keyword: name.normalized, styling: .operator))
    }
    
    func findPostfixOperator() -> (termName: TermName, operator: UnaryOperation)? {
        let result = Array(postfixOperators.keys).findTermName(in: source.prefix(while: { !$0.isNewline }))
        return result.termName.map { name in
            (termName: name, operator: postfixOperators[name]!)
        }
    }
    
    func eatPostfixOperator() {
        let result = Array(postfixOperators.keys).findTermName(in: source.prefix(while: { !$0.isNewline }))
        source.removeFirst(result.termString.count)
        guard let name = result.termName else {
            return
        }
        currentElements[currentElements.endIndex - 1].append(Keyword(keyword: name.normalized, styling: .operator))
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
    
    func eatTerm() throws -> Term? {
        let term = try eatTerm(terminology: lexicon)
        if let name = term?.name {
            currentElements[currentElements.endIndex - 1].append(Keyword(keyword: name.normalized, styling: .variable))
        }
        return term
    }
    
    func tryEating(termName: TermName) -> Bool {
        let rollbackSource = source
        for word in termName.words {
            guard tryEating(prefix: word) else {
                source = rollbackSource
                return false
            }
        }
        return true
    }
    
    func tryEating(prefix target: String) -> Bool {
        eatCommentsAndWhitespace()
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
    
    func findExpressionEndKeyword() -> Bool {
        if case (_, _?)? = awaitingExpressionEndKeywords.last.map({ Array($0) })?.findTermName(in: source) ?? nil {
            return true
        }
        return false
    }
    
    func withScope(parse: () throws -> Sequence) rethrows -> Expression {
        lexicon.push()
        defer { lexicon.pop() }
        return Expression(.scoped(try parse()), at: expressionLocation)
    }
    
    func withTerminology<Result>(of expression: Expression, parse: () throws -> Result) throws -> Result {
        var terminologyPushed = false
        defer {
            if terminologyPushed {
                lexicon.pop()
            }
        }
        
        noTerminology: do {
            let appBundle: Bundle
            switch expression.kind {
            case .specifier(let specifier):
                guard specifier.idTerm.term.uid == TermUID(TypeUID.application) else {
                    break noTerminology
                }
                
                switch specifier.kind {
                case .simple(let dataExpression), .name(let dataExpression):
                    guard case .string(let name) = dataExpression.kind else {
                        break noTerminology
                    }
                    guard let bundle = Bundle(applicationName: name) else {
                        throw ParseError(description: "no application found with name ‘\(name)’", location: expression.location)
                    }
                    appBundle = bundle
                case .id(let dataExpression):
                    guard case .string(let bundleID) = dataExpression.kind else {
                        break noTerminology
                    }
                    guard let bundle = Bundle(applicationBundleIdentifier: bundleID) else {
                        throw ParseError(description: "no application found for bundle identifier ‘\(bundleID)’", location: expression.location)
                    }
                    appBundle = bundle
                default:
                    break noTerminology
                }
                
                let dictionary = lexicon.push()
                terminologyPushed = true
                try loadTerminology(at: appBundle.bundleURL, into: dictionary)
            case .use(let term),
                 .resource(let term):
                lexicon.push(for: term.term)
                terminologyPushed = true
            default:
                break noTerminology
            }
        } catch let error as ParseError {
            throw error
        } catch {
            throw ParseError(description: "an error occurred while retrieving terminology: \(error)", location: expression.location)
        }
        
        return try parse()
    }
    
    func loadTerminology(at url: URL, into dictionaryContainer: TermDictionaryDelayedInitContainer) throws {
        try loadTerminology(at: url, into: dictionaryContainer.makeDictionary(under: lexicon.pool))
    }
    
    func loadTerminology(at url: URL, into dictionary: TermDictionary) throws {
        let sdef: Data
        do {
            sdef = try Self.getSDEF(from: url)
        } catch is SDEFError {
            return
        }
        dictionary.add(try Bushel.parse(sdef: sdef, under: lexicon))
    }
    
    static func getSDEF(from url: URL) throws -> Data {
        if let sdef = sdefCache[url] {
            return sdef
        }
        let sdef = try SDEFinitely.readSDEF(from: url)
        sdefCache[url] = sdef
        return sdef
    }
    
    var currentLocation: SourceLocation {
        SourceLocation(at: currentIndex, source: entireSource)
    }
    
    var currentIndex: String.Index {
        source.startIndex
    }
    
    var expressionLocation: SourceLocation {
        SourceLocation(expressionStartIndex..<currentIndex, source: entireSource)
    }
    
    var expressionStartIndex: String.Index {
        get {
            expressionStartIndices.last ?? entireSource.startIndex
        }
        set {
            expressionStartIndices.append(newValue)
        }
    }
    
    func eatTerm<Terminology: TerminologySource>(terminology: Terminology) throws -> Term? {
        func eatDefinedTerm() -> Term? {
            func findTerm<Terminology: TerminologySource>(in dictionary: Terminology) -> (termString: Substring, term: Term)? {
                eatCommentsAndWhitespace()
                var termString = source.prefix { !$0.isWordBreaking || $0.isWhitespace || $0 == ":" }
                while let lastNonBreakingIndex = termString.lastIndex(where: { !$0.isWordBreaking }) {
                    termString = termString[...lastNonBreakingIndex]
                    let termName = TermName(String(termString))
                    if let term = dictionary.term(named: termName) {
                        return (termString, term)
                    } else {
                        termString.removeLast(termName.words.last!.count)
                    }
                }
                return nil
            }
            
            guard var (termString, term) = findTerm(in: terminology) else {
                return nil
            }
            source.removeFirst(termString.count)
            eatCommentsAndWhitespace()
            var sourceWithColon: Substring = source
            while tryEating(prefix: ":") {
                // For explicit term specification Lhs : rhs,
                // avoid eating the colon unless:
                //  a) Lhs contains a dictionary, *and*
                //  b) rhs is a term defined by that dictionary.
                guard
                    let dictionary = (term as? TermDictionaryContainer)?.terminology,
                    let result = findTerm(in: dictionary)
                else {
                    // Restore the colon. It may have come from some other construct,
                    // e.g., a record key such as: {Math : pi: "the constant pi"}
                    source = sourceWithColon
                    
                    return term
                }
                
                // Eat rhs.
                (termString, term) = result
                source.removeFirst(termString.count)
                eatCommentsAndWhitespace()
                
                // We're committed to this colon forming an explicit specification
                sourceWithColon = source
            }
            return term
        }
        func eatRawFormTerm() throws -> Term? {
            guard source.removePrefix("«") else {
                return nil
            }
            
            eatCommentsAndWhitespace()
            
            let kindString = source.prefix(while: { !$0.isWhitespace })
            source.removeFirst(kindString.count)
            guard let kind = TypedTermUID.Kind(rawValue: String(kindString)) else {
                throw ParseError(description: "invalid raw term type", location: currentLocation)
            }
            
            eatCommentsAndWhitespace()
            
            guard let closeBracketRange = source.range(of: "»") else {
                throw ParseError(description: "expected term UID followed by ‘»’", location: currentLocation)
            }
            let uidString = source[..<closeBracketRange.lowerBound]
            source = source[closeBracketRange.upperBound...]
            guard let uid = TermUID(normalized: String(uidString)) else {
                throw ParseError(description: "expected term UID", location: currentLocation)
            }
            
            var maybeTerm = lexicon.term(forUID: TypedTermUID(kind, uid))
            if maybeTerm == nil {
                let termType = kind.termType
                maybeTerm = termType.init(uid, name: TermName(""))
                guard maybeTerm != nil else {
                    throw ParseError(description: "this term is undefined and cannot be ad-hoc constructed", location: currentLocation)
                }
            }
            
            guard let term = maybeTerm as? Terminology.Term else {
                throw ParseError(description: "wrong type of term for context", location: currentLocation)
            }
            return term
        }
        
        return try eatDefinedTerm() ?? eatRawFormTerm()
    }
    
}

public extension StringProtocol {
    
    var range: Range<Index> {
        return startIndex..<endIndex
    }
    
}

public extension TypedTermUID.Kind {
    
    var termType: Term.Type {
        switch self {
        case .enumerator:
            return EnumeratorTerm.self
        case .dictionary:
            return DictionaryTerm.self
        case .type:
            return ClassTerm.self
        case .property:
            return PropertyTerm.self
        case .command:
            return CommandTerm.self
        case .parameter:
            return ParameterTerm.self
        case .variable:
            return VariableTerm.self
        case .resource:
            return ResourceTerm.self
        }
    }
    
}

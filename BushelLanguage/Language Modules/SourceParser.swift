import Bushel
import SDEFinitely
import os
import Regex

private let log = OSLog(subsystem: logSubsystem, category: "Source parser")

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
public typealias ResourceTypeHandler = (_ name: TermName) throws -> ResourceTerm

/// Parses source code into an AST.
public protocol SourceParser: AnyObject {
    
    var entireSource: String { get set }
    var source: Substring { get set }
    var expressionStartIndices: [String.Index] { get set }
    var termNameStartIndex: String.Index { get set }
    
    var lexicon: Lexicon { get set }
    var sequenceNestingLevel: Int { get set }
    var elements: Set<SourceElement> { get set }
    var awaitingExpressionEndKeywords: [Set<TermName>] { get set }
    var sequenceEndTags: [TermName] { get set }
    
    var keywords: [TermName : KeywordHandler] { get }
    var resourceTypes: [TermName : (hasName: Bool, stoppingAt: [String], handler: ResourceTypeHandler)] { get }
    var prefixOperators: [TermName : UnaryOperation] { get }
    var postfixOperators: [TermName : UnaryOperation] { get }
    var binaryOperators: [TermName : BinaryOperation] { get }
    var stringMarkers: [(begin: TermName, end: TermName)] { get }
    var expressionGroupingMarkers: [(begin: TermName, end: TermName)] { get }
    var listMarkers: [(begin: TermName, end: TermName, itemSeparators: [TermName])] { get }
    var recordMarkers: [(begin: TermName, end: TermName, itemSeparators: [TermName], keyValueSeparators: [TermName])] { get }
    var listAndRecordMarkers: [(begin: TermName, end: TermName, itemSeparators: [TermName], keyValueSeparators: [TermName])] { get }
    var lineCommentMarkers: [TermName] { get }
    var blockCommentMarkers: [(begin: TermName, end: TermName)] { get }
    
    init()
    
    func handle(term: Term) throws -> Expression.Kind?
    
    /// For any required post-processing.
    /// e.g., possessive specifiers (like "xyz's first widget") modify
    ///       the preceding primary.
    /// Return nil to accept `primary` as-is.
    /// This method is called repeatedly, and its result used as the new primary
    /// expression, until the result is nil.
    func postprocess(primary: Expression) throws -> Expression.Kind?
    
}

public extension SourceParser {
    
    init(translations: [Translation]) {
        self.init()
        for translation in translations {
            lexicon.add(translation.makeTerms(under: lexicon.pool))
        }
    }
    
    func parse(source: String) throws -> Program {
        signpostBegin()
        defer { signpostEnd() }
        
        self.entireSource = source
        self.source = Substring(source)
        self.expressionStartIndex = source.startIndex
        self.sequenceNestingLevel = -1
        self.elements = []
        
        guard !source.isEmpty else {
            return Program(Expression.empty(at: currentLocation), [], source: entireSource, terms: TermPool())
        }
        
        lexicon.add(ParameterTerm(TermUID(ParameterUID.direct), name: nil))
        
        lexicon.pushDictionaryTerm(forUID: .id("script"))
        defer { lexicon.pop() }
        do {
            return Program(try parseDocument(), elements, source: entireSource, terms: lexicon.pool)
        } catch var error as ParseError {
            if !entireSource.range.contains(error.location.range.lowerBound) {
                error.location.range = entireSource.index(before: entireSource.endIndex)..<entireSource.endIndex
            }
            throw error
        }
    }
    
    func eatCommentsAndWhitespace(eatingNewlines: Bool = false, isSignificant: Bool = false) {
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
        
        func addAsSourceElement(from startIndex: String.Index) {
            elements.insert(SourceElement(Terminal(String(entireSource[startIndex..<currentIndex]), at: location(from: startIndex), styling: .comment)))
        }
        
        withCurrentIndex { startIndex in
            source.removeLeadingWhitespace(removingNewlines: eatingNewlines)
            
            if isSignificant, currentIndex != startIndex {
                addAsSourceElement(from: startIndex)
            }
        }
            
        while
            withCurrentIndex(parse: { startIndex in
                guard eatBlockComment() || eatLineComment() else {
                    return false
                }
                addAsSourceElement(from: startIndex)
                
                withCurrentIndex { startIndex in
                    source.removeLeadingWhitespace(removingNewlines: eatingNewlines)
                    if isSignificant {
                        addAsSourceElement(from: startIndex)
                    }
                }
                return true
            })
        {
        }
    }
    
    private func addElement(from startIndex: String.Index, styling: Styling, spacing: Spacing) {
        guard startIndex != currentIndex else {
            return
        }
        
        let slice = String(entireSource[startIndex..<currentIndex])
        let loc = location(from: startIndex)
        elements.insert(SourceElement(Terminal(slice, at: loc, spacing: spacing, styling: styling)))
    }
    
    func addingElement<Result>(_ styling: Styling = .keyword, spacing: Spacing = .leftRight, parse: () throws -> Result) rethrows -> Result {
        try withCurrentIndex { startIndex in
            defer {
                addElement(from: startIndex, styling: styling, spacing: spacing)
            }
            return try parse()
        }
    }
    
    func parseDocument() throws -> Expression {
        let sequence = try parseSequence(TermName(""))
        
        eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true)
        
        return sequence
    }
    
    func parseSequence(_ endTag: TermName, stoppingAt stopKeywords: [String] = []) throws -> Expression {
        sequenceEndTags.append(endTag)
        defer {
            sequenceEndTags.removeLast()
        }
        
        // Matched by .end check below
        sequenceNestingLevel += 1
        
        var expressions: [Expression] = []
        
        func eatNewlines() {
            eatCommentsAndWhitespace()
            while let newline = parseNewline() {
                expressions.append(newline)
                addIndentation()
            }
        }
        
        eatNewlines()
        
        while true {
            if source.isEmpty || stopKeywords.contains(where: { source.hasPrefix($0) }) {
                break
            }
            
            let indentation = addIndentation()
            
            if let primary = try parsePrimary() {
                expressions.append(primary)
                if case Expression.Kind.end = primary.kind {
                    sequenceNestingLevel -= 1
                    
                    elements.remove(indentation)
                    elements.insert(SourceElement(Indentation(level: sequenceNestingLevel, location: indentation.location)))
                    
                    break
                }
            }
            
            eatCommentsAndWhitespace()
            
            let newline = parseNewline()
            
            if source.isEmpty {
                if let newline = newline {
                    expressions.append(newline)
                }
                break
            }
            
            guard newline != nil else {
                let nextNewline = source.firstIndex(where: { $0.isNewline }) ?? source.endIndex
                let location = SourceLocation(source.startIndex..<nextNewline, source: entireSource)
                throw ParseError(description: "expected line break after sequenced expression", location: location, fixes: [PrependingFix(prepending: "\n", at: location)])
            }
            
            if stopKeywords.contains(where: { source.hasPrefix($0) }) {
                expressions.append(newline!)
                break
            }
            
            eatNewlines()
        }
        
        let result = Expression(.sequence(expressions), at: expressionLocation)
        eatCommentsAndWhitespace()
        return result
    }
    
    func parsePrimary(lastOperation: BinaryOperation? = nil) throws -> Expression? {
        guard var primary = try (parsePrefixOperators() ?? parseUnprocessedPrimary()) else {
            return nil
        }
        
        while let processedPrimary = try processBinaryOperators(after: primary, lastOperation: lastOperation) {
            primary = processedPrimary
        }
        
        while let processedPrimary = try (
            postprocess(primary: primary).map {
                Expression($0, at: expressionLocation)
            } ?? parsePostfixOperators()
        ) {
            primary = processedPrimary
        }
        
        eatCommentsAndWhitespace()
        
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
            return Expression(.infixOperator(operation: operation, lhs: lhs, rhs: rhs), at: expressionLocation)
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
            
            expression = Expression(.prefixOperator(operation: operation, operand: operand), at: expressionLocation)
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
            
            expression = Expression(.postfixOperator(operation: operation, operand: operand), at: expressionLocation)
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
                addingElement(.weave, spacing: .none) {
                    _ = source.removeFirst() // Eat leading newline
                }
                
                let rollbackSource = source // Preserve leading whitespace
                let rollbackElements = elements
                if let newHashbang = eatHashbang() {
                    hashbangs.append(newHashbang)
                    bodies.append("")
                    if newHashbang.invocation.allSatisfy({ $0.isWhitespace }) {
                        endHashbangLocation = newHashbang.location
                        break
                    }
                } else {
                    source = rollbackSource
                    elements = rollbackElements
                    let line = String(source.prefix { !$0.isNewline })
                    bodies[bodies.index(before: bodies.endIndex)] += "\(line)\n"
                    addingElement(.weave, spacing: .none) {
                        source.removeFirst(line.count)
                    }
                }
            }
            
            let weaves = zip(hashbangs.indices, bodies).map { (pair: (Int, String)) -> Expression in
                let (hashbangIndex, body) = pair
                let hashbang = hashbangs[hashbangIndex]
                
                if hashbangs.indices.contains(hashbangIndex + 1) {
                    let nextHashbang = hashbangs[hashbangIndex + 1]
                    return Expression(.weave(hashbang: hashbang, body: body), at: SourceLocation(hashbang.location.range.lowerBound..<nextHashbang.location.range.lowerBound, source: entireSource))
                } else if let endLocation = endHashbangLocation {
                    // Program continues after an empty #! at endLocation
                    return Expression(.endWeave, at: endLocation)
                } else {
                    // Program ends in a weave
                    return Expression(.weave(hashbang: hashbang, body: body), at: SourceLocation(hashbang.location.range.lowerBound..<currentIndex, source: entireSource))
                }
            }
            
            return Expression(.sequence(weaves), at: expressionLocation)
        } else if let (_, endMarker) = eatStringBeginMarker() {
            guard
                let match = tryEating(try! Regex(string: "(.*?)(?<!\\\\)\(endMarker)"), .string, spacing: .right),
                let string = match.captures[0]
            else {
                throw ParseError(description: "unable to parse string", location: currentLocation)
            }
            return Expression(.string(string), at: expressionLocation)
        } else if let (beginMarker, endMarker) = eatExpressionGroupingBeginMarker() {
            return try awaiting(endMarker: endMarker) {
                eatCommentsAndWhitespace(eatingNewlines: true)
                
                guard let enclosed = try parsePrimary() else {
                    throw ParseError(description: "expected grouped expression after ‘\(beginMarker)’", location: expressionLocation)
                }
                
                eatCommentsAndWhitespace(eatingNewlines: true)
                guard tryEating(endMarker, spacing: .right) else {
                    throw ParseError(description: "expected ‘\(endMarker)’ to end grouped expression", location: expressionLocation)
                }
                
                return Expression(.parentheses(enclosed), at: expressionLocation)
            }
        } else if let (_, endMarker, itemSeparators, keyValueSeparators) = eatListAndRecordBeginMarker() {
            return try awaiting(endMarkers: Set([endMarker] + itemSeparators + keyValueSeparators)) {
                eatCommentsAndWhitespace(eatingNewlines: true)
                
                guard !tryEating(endMarker, spacing: .right) else {
                    return Expression(.list([]), at: expressionLocation)
                }
                if let initialKeyValueSeparator = tryEating(oneOf: keyValueSeparators, spacing: .right) {
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(description: "expected key expression before ‘\(initialKeyValueSeparator)’, or ‘\(endMarker)’ after for an empty record", location: currentLocation)
                    }
                    return Expression(.record([]), at: expressionLocation)
                }
                
                let first = try parseListItem(as: "list item or record key")
                
                if tryEating(endMarker, spacing: .right) {
                    return Expression(.list([first]), at: expressionLocation)
                } else if let itemSeparator = tryEating(oneOf: itemSeparators, spacing: .right) {
                    var items: [Expression] = [first]
                    repeat {
                        items.append(try parseListItem(as: "list item"))
                    } while tryEating(itemSeparator, spacing: .right)
                    
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(description: "expected ‘\(endMarker)’ to end list or ‘\(itemSeparator)’ to separate additional items", location: currentLocation)
                    }
                    return Expression(.list(items), at: expressionLocation)
                } else if let keyValueSeparator = tryEating(oneOf: keyValueSeparators, spacing: .right) {
                    let first = (key: first, value: try parseListItem(as: "record item"))
                    var items: [(key: Expression, value: Expression)] = [first]
                    
                    if let itemSeparator = tryEating(oneOf: itemSeparators, spacing: .right) {
                        repeat {
                            let key = try parseListItem(as: "record key")
                            guard tryEating(keyValueSeparator, spacing: .right) else {
                                throw ParseError(description: "expected ‘\(keyValueSeparator)’ after key in record", location: currentLocation)
                            }
                            let value = try parseListItem(as: "record item")
                            items.append((key: key, value: value))
                        } while tryEating(itemSeparator, spacing: .right)
                    }
                    
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(description: "expected ‘\(endMarker)’ to end record or ‘\(itemSeparators.first!)’ to separate additional items", location: currentLocation)
                    }
                    return Expression(.record(items), at: expressionLocation)
                } else {
                    throw ParseError(description: "expected ‘\(endMarker)’ to end list, ‘\(itemSeparators.first!)’ to separate additional items or ‘\(keyValueSeparators.first!)’ to make a record", location: currentLocation)
                }
            }
        } else if let (_, endMarker, itemSeparators) = eatListBeginMarker() {
            return try awaiting(endMarkers: Set([endMarker] + itemSeparators)) {
                eatCommentsAndWhitespace(eatingNewlines: true)
                
                guard !tryEating(endMarker, spacing: .right) else {
                    return Expression(.list([]), at: expressionLocation)
                }
                
                let first = try parseListItem(as: "list item")
                
                if tryEating(endMarker, spacing: .right) {
                    return Expression(.list([first]), at: expressionLocation)
                } else if let itemSeparator = tryEating(oneOf: itemSeparators, spacing: .right) {
                    var items: [Expression] = [first]
                    repeat {
                        items.append(try parseListItem(as: "list item"))
                    } while tryEating(itemSeparator, spacing: .right)
                    
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(description: "expected ‘\(endMarker)’ to end list or ‘\(itemSeparator)’ to separate additional items", location: currentLocation)
                    }
                    return Expression(.list(items), at: expressionLocation)
                } else {
                    throw ParseError(description: "expected ‘\(endMarker)’ to end list or ‘\(itemSeparators.first!)’ to separate additional items", location: currentLocation)
                }
            }
        } else if let (_, endMarker, itemSeparators, keyValueSeparators) = eatRecordBeginMarker() {
            return try awaiting(endMarkers: Set([endMarker] + itemSeparators + keyValueSeparators)) {
                eatCommentsAndWhitespace(eatingNewlines: true)
                
                guard !tryEating(endMarker, spacing: .right) else {
                    return Expression(.record([]), at: expressionLocation)
                }
                if let initialKeyValueSeparator = tryEating(oneOf: keyValueSeparators, spacing: .right) {
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(description: "expected key expression before ‘\(initialKeyValueSeparator)’, or ‘\(endMarker)’ after for an empty record", location: currentLocation)
                    }
                    return Expression(.record([]), at: expressionLocation)
                }
                
                let firstKey = try parseListItem(as: "record key")
                guard let keyValueSeparator = tryEating(oneOf: keyValueSeparators, spacing: .right) else {
                    throw ParseError(description: "expected ‘\(keyValueSeparators.first!)’ after key in record", location: currentLocation)
                }
                let first = (key: firstKey, value: try parseListItem(as: "record item"))
                
                var items: [(key: Expression, value: Expression)] = [first]
                if let itemSeparator = tryEating(oneOf: itemSeparators, spacing: .right) {
                    repeat {
                        let key = try parseListItem(as: "record key")
                        guard tryEating(keyValueSeparator, spacing: .right) else {
                            throw ParseError(description: "expected ‘\(keyValueSeparator)’ after key in record", location: currentLocation)
                        }
                        let value = try parseListItem(as: "record item")
                        items.append((key: key, value: value))
                    } while tryEating(itemSeparator, spacing: .right)
                }
                
                guard tryEating(endMarker, spacing: .right) else {
                    throw ParseError(description: "expected ‘\(endMarker)’ to end record or ‘\(itemSeparators.first!)’ to separate additional items", location: currentLocation)
                }
                return Expression(.record(items), at: expressionLocation)
            }
        } else if let term = try eatTerm() {
            if let kind = try handle(term: term) {
                return Expression(kind, at: expressionLocation)
            } else {
                return nil
            }
        } else if let termName = eatKeyword() {
            if let kind = try keywords[termName]!() {
                return Expression(kind, at: expressionLocation)
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
            
            if c.isNumber || c == "." {
                return try withCurrentIndex { startIndex in
                    eatCommentsAndWhitespace()
                    
                    func parseInteger() -> Expression? {
                        guard
                            let match = tryEating(Regex("^\\d++(?!\\.)"), .number),
                            let value = Int64(match.matchedString)
                        else {
                            return nil
                        }
                        return Expression(.integer(value), at: expressionLocation)
                    }
                    func parseDouble() throws -> Expression {
                        guard
                            let match = tryEating(Regex("^\\d*(?:\\.\\d++(?:[ep][-+]?\\d+)?)?", options: .ignoreCase), .number),
                            let value = Double(match.matchedString)
                        else {
                            throw ParseError(description: "unable to parse number", location: expressionLocation)
                        }
                        return Expression(.double(value), at: expressionLocation)
                    }
                    return try parseInteger() ?? parseDouble()
                }
            } else {
                os_log("Undefined term source: %@", log: log, type: .debug, String(source))
                throw ParseError(description: "undefined term; perhaps you made a typo?", location: SourceLocation(currentIndex..<(source.firstIndex(where: { $0.isNewline }) ?? source.endIndex), source: entireSource))
            }
        }
    }
    
    // MARK: Off-the-shelf keyword handlers
    
    func handleUse() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        
        let typeNamesLongestFirst = resourceTypes.keys
            .sorted(by: { lhs, rhs in lhs.normalized.caseInsensitiveCompare(rhs.normalized) == .orderedAscending })
            .reversed()
        
        guard let typeName = typeNamesLongestFirst.first(where: { tryEating($0) }) else {
            let formattedTypeNames =
                typeNamesLongestFirst
                    .reversed()
                    .map { $0.normalized }
                    .joined(separator: ", ")
            
            throw ParseError(description: "invalid resource type; valid types are: \(formattedTypeNames)", location: SourceLocation(currentIndex..<source.endIndex, source: entireSource))
        }
        
        let (hasName, stoppingAt, handler) = resourceTypes[typeName]!
        
        eatCommentsAndWhitespace()
        
        guard !source.hasPrefix("\"") else {
            throw ParseError(description: "‘use’ binds a resource term; remove the quotation mark(s)", location: currentLocation)
        }
        
        eatCommentsAndWhitespace()
        
        var name = TermName("")
        if hasName {
            guard let name_ = try parseTermNameEagerly(stoppingAt: stoppingAt) else {
                throw ParseError(description: "expected resource name", location: currentLocation)
            }
            name = name_
        }
        
        eatCommentsAndWhitespace()
        
        let resourceTerm = try handler(name)
        return .use(resource: resourceTerm)
    }
    
    func handleEnd() throws -> Expression.Kind? {
        if findExpressionEndKeyword() || source.hasPrefix("\n") || source.isEmpty {
            return .end
        }
        let endTag = sequenceEndTags.last!
        guard tryEating(endTag) else {
            throw ParseError(description: "expected ‘\(endTag)’ or line break", location: currentLocation, fixes: [SequencingFix(fixes: [DeletingFix(at: SourceLocation(currentIndex..<(source.firstIndex(where: { $0.isNewline }) ?? source.endIndex), source: entireSource)), AppendingFix(appending: "\(endTag)", at: currentLocation)]), AppendingFix(appending: "\(endTag)\n", at: currentLocation)])
        }
        return .end
    }
    
    func handleReturn() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        
        if source.first?.isNewline ?? true {
            return .return_(Expression.empty(at: currentLocation))
        } else {
            return .return_(try parsePrimary())
        }
    }
    
    func handleThat() throws -> Expression.Kind? {
        .that
    }
    
    func handleIt() throws -> Expression.Kind? {
        .it
    }
    
    func parseVariableTerm(stoppingAt: [String] = []) throws -> VariableTerm? {
        guard
            let termName = try parseTermNameEagerly(stoppingAt: stoppingAt, styling: .variable),
            !termName.words.isEmpty
        else {
            return nil
        }
        return VariableTerm(lexicon.makeUID(forName: termName), name: termName)
    }
    
    func parseTermNameEagerly(stoppingAt: [String] = [], styling: Styling = .keyword) throws -> TermName? {
        let restOfLine = source.prefix { !$0.isNewline }
        let startIndex = restOfLine.startIndex
        let allWords = TermName.words(in: restOfLine)
        
        guard !allWords.isEmpty else {
            return nil
        }
        guard allWords.first! != "|" else {
            // Lazy parsing handles pipe escapes
            return try parseTermNameLazily()
        }
        
        var words: [String] = []
        for word in allWords {
            guard !stoppingAt.contains(word) else {
                break
            }
            words.append(word)
        }
        
        guard !words.isEmpty else {
            return nil
        }
        
        eatFromSource(words, styling: styling)
        termNameStartIndex = startIndex
        return TermName(words)
    }
    
    func parseTypeTerm() throws -> Bushel.ClassTerm? {
        switch try eatTerm()?.enumerated {
        case .class_(let typeTerm),
             .pluralClass(let typeTerm as Bushel.ClassTerm):
            return typeTerm
        default:
            throw ParseError(description: "expected type name", location: currentLocation)
        }
        
    }
    
    func parseString() throws -> (expression: Expression, value: String)? {
        guard let expression = try parsePrimary() else {
            return nil
        }
        switch expression.kind {
        case .string(let value):
            return (expression, value)
        default:
            return nil
        }
    }
    
    func parseTermNameLazily(styling: Styling = .keyword) throws -> TermName? {
        let restOfLine = source.prefix { !$0.isNewline }
        let startIndex = restOfLine.startIndex
        let words = TermName.words(in: restOfLine)
        
        guard let firstWord = words.first else {
            return nil
        }
        
        eatFromSource([firstWord], styling: styling)
        if firstWord == "|" {
            for wordIndex in words.indices.dropFirst() {
                if words[wordIndex] == "|" {
                    let wordsWithoutPipes = Array(words[1..<wordIndex])
                    eatFromSource(wordsWithoutPipes + ["|"], styling: styling)
                    termNameStartIndex = startIndex
                    return TermName(wordsWithoutPipes)
                }
            }
            throw ParseError(description: "mismatched ‘|’", location: SourceLocation(termNameStartIndex..<source.startIndex, source: entireSource))
        } else {
            termNameStartIndex = startIndex
            return TermName(firstWord)
        }
    }
    
    private func eatFromSource(_ words: [String], styling: Styling = .keyword) {
        for word in words {
            source.removeLeadingWhitespace()
            addingElement(styling) {
                source.removeFirst(word.count)
            }
        }
    }
    
    private func parseListItem(as location: String) throws -> Expression {
        eatCommentsAndWhitespace(eatingNewlines: true)
        
        guard let item = try parsePrimary() else {
            throw ParseError(description: "expected \(location)", location: currentLocation)
        }
        
        eatCommentsAndWhitespace(eatingNewlines: true)
        return item
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
        
        let newline = Expression(.empty, at: currentLocation)
        addingElement(.comment, spacing: .none) {
            _ = source.removeFirst()
        }
        
        eatCommentsAndWhitespace()
        
        return newline
    }
    
    @discardableResult
    func addIndentation() -> SourceElement {
        withCurrentIndex { startIndex in
            eatCommentsAndWhitespace()
            
            let loc = SourceLocation(at: location(from: startIndex))
            let element = SourceElement(Indentation(level: sequenceNestingLevel, location: loc))
            elements.insert(element)
            return element
        }
    }
    
    func eatHashbang() -> Hashbang? {
        guard tryEating(prefix: "#!", spacing: .left) else {
            return nil
        }
        
        let invocationSource = source.prefix { !$0.isNewline }
        addingElement {
            source.removeFirst(invocationSource.count)
        }
        
        return Hashbang(String(invocationSource), at: expressionLocation)
    }
    
    func eatLineCommentMarker() -> Bool {
        let result = lineCommentMarkers.findTermName(in: source)
        source.removeFirst(result.termString.count)
        return result.termName != nil
    }
    
    func eatBlockCommentBeginMarker() -> Bool {
        let result = blockCommentMarkers.map { $0.begin }.findTermName(in: source)
        source.removeFirst(result.termString.count)
        return result.termName != nil
    }
    
    func eatBlockCommentEndMarker() -> Bool {
        let result = blockCommentMarkers.map { $0.end }.findTermName(in: source)
        source.removeFirst(result.termString.count)
        return result.termName != nil
    }
    
    func eatKeyword() -> TermName? {
        let result = Array(keywords.keys).findTermName(in: source)
        guard let termName = result.termName else {
            return nil
        }
        addingElement(spacing: termName.normalized.last!.isWordBreaking ? .left : .leftRight) {
            source.removeFirst(result.termString.count)
        }
        return termName
    }
    
    func findPrefixOperator() -> (termName: TermName, operator: UnaryOperation)? {
        let result = Array(prefixOperators.keys).findTermName(in: source)
        return result.termName.map { name in
            (termName: name, operator: prefixOperators[name]!)
        }
    }
    
    func eatPrefixOperator() {
        let result = Array(prefixOperators.keys).findTermName(in: source)
        guard result.termName != nil else {
            return
        }
        addingElement(.operator) {
            source.removeFirst(result.termString.count)
        }
    }
    
    func findPostfixOperator() -> (termName: TermName, operator: UnaryOperation)? {
        let result = Array(postfixOperators.keys).findTermName(in: source)
        return result.termName.map { name in
            (termName: name, operator: postfixOperators[name]!)
        }
    }
    
    func eatPostfixOperator() {
        let result = Array(postfixOperators.keys).findTermName(in: source)
        guard result.termName != nil else {
            return
        }
        addingElement(.operator) {
            source.removeFirst(result.termString.count)
        }
    }
    
    func findBinaryOperator() -> (termName: TermName, operator: BinaryOperation)? {
        let result = Array(binaryOperators.keys).findTermName(in: source)
        return result.termName.map { name in
            (termName: name, operator: binaryOperators[name]!)
        }
    }
    
    func eatBinaryOperator() {
        let result = Array(binaryOperators.keys).findTermName(in: source)
        guard result.termName != nil else {
            return
        }
        addingElement(.operator) {
            source.removeFirst(result.termString.count)
        }
    }
    
    func eatStringBeginMarker() -> (begin: TermName, end: TermName)? {
        let result = stringMarkers.map { $0.begin }.findTermName(in: source)
        guard let termName = result.termName else {
            return nil
        }
        addingElement(.string, spacing: .left) {
            source.removeFirst(result.termString.count)
        }
        return stringMarkers.first { $0.begin == termName }
    }
    
    func eatExpressionGroupingBeginMarker() -> (begin: TermName, end: TermName)? {
        let result = expressionGroupingMarkers.map { $0.begin }.findTermName(in: source)
        guard let termName = result.termName else {
            return nil
        }
        assume(tryEating(termName, spacing: .left))
        return expressionGroupingMarkers.first { $0.begin == termName }
    }
    
    func eatListBeginMarker() -> (begin: TermName, end: TermName, itemSeparators: [TermName])? {
        let result = listMarkers.map { $0.begin }.findTermName(in: source)
        guard let termName = result.termName else {
            return nil
        }
        assume(tryEating(termName, spacing: .left))
        return listMarkers.first { $0.begin == termName }
    }
    
    func eatRecordBeginMarker() -> (begin: TermName, end: TermName, itemSeparators: [TermName], keyValueSeparators: [TermName])? {
        let result = recordMarkers.map { $0.begin }.findTermName(in: source)
        guard let termName = result.termName else {
            return nil
        }
        assume(tryEating(termName, spacing: .left))
        return recordMarkers.first { $0.begin == termName }
    }
    
    func eatListAndRecordBeginMarker() -> (begin: TermName, end: TermName, itemSeparators: [TermName], keyValueSeparators: [TermName])? {
        let result = listAndRecordMarkers.map { $0.begin }.findTermName(in: source)
        guard let termName = result.termName else {
            return nil
        }
        assume(tryEating(termName, spacing: .left))
        return listAndRecordMarkers.first { $0.begin == termName }
    }
    
    func eatTerm() throws -> Term? {
        try eatTerm(terminology: lexicon)
    }
    
    func tryEating(_ termName: TermName, _ styling: Styling = .keyword, spacing: Spacing = .leftRight) -> Bool {
        let rollbackSource = source
        for word in termName.words {
            guard tryEating(prefix: word, styling, spacing: spacing) else {
                source = rollbackSource
                return false
            }
        }
        return true
    }
    
    func tryEating(oneOf termNames: [TermName], _ styling: Styling = .keyword, spacing: Spacing = .leftRight) -> TermName? {
        termNames.first { tryEating($0, styling, spacing: spacing) }
    }
    
    func tryEating(prefix target: String, _ styling: Styling = .keyword, spacing: Spacing = .leftRight) -> Bool {
        eatCommentsAndWhitespace()
        
        guard
            source.hasPrefix(target),
            target.last!.isWordBreaking || (source.dropFirst(target.count).first?.isWordBreaking ?? true)
        else {
            return false
        }
        
        addingElement(styling, spacing: spacing) {
            source.removeFirst(target.count)
        }
        return true
    }
    
    func tryEating(_ regex: Regex, _ styling: Styling = .keyword, spacing: Spacing = .leftRight) -> MatchResult? {
        let restOfLine = String(source.prefix { !$0.isNewline })
        guard let match = regex.firstMatch(in: restOfLine) else {
            return nil
        }
        
        addingElement(styling, spacing: spacing) {
            source.removeFirst(match.matchedString.count)
        }
        
        return match
    }
    
    func findExpressionEndKeyword() -> Bool {
        if case (_, _?)? = awaitingExpressionEndKeywords.last.map({ Array($0) })?.findTermName(in: source) ?? nil {
            return true
        }
        return false
    }
    
    func withScope(parse: () throws -> Expression) rethrows -> Expression {
        lexicon.pushUnnamedDictionary()
        defer { lexicon.pop() }
        return Expression(.scoped(try parse()), at: expressionLocation)
    }
    
    func withTerminology<Result>(of term: Term, parse: () throws -> Result) throws -> Result {
        guard let term = term as? TermDictionaryContainer else {
            return try parse()
        }
        
        lexicon.push(for: term)
        defer {
            lexicon.pop()
        }
        
        return try parse()
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
                guard specifier.idTerm.uid == TermUID(TypeUID.application) else {
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
                
                let dictionary = lexicon.pushUnnamedDictionary()
                terminologyPushed = true
                try dictionary.loadTerminology(at: appBundle.bundleURL)
            case .use(let term),
                 .resource(let term):
                lexicon.push(for: term)
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
    
    var currentLocation: SourceLocation {
        SourceLocation(at: currentIndex, source: entireSource)
    }
    
    var currentIndex: String.Index {
        source.startIndex
    }
    
    var expressionLocation: SourceLocation {
        location(from: expressionStartIndex)
    }
    
    var expressionStartIndex: String.Index {
        get {
            expressionStartIndices.last ?? entireSource.startIndex
        }
        set {
            expressionStartIndices.append(newValue)
        }
    }
    
    var termNameLocation: SourceLocation {
        location(from: termNameStartIndex)
    }
    
    private func withCurrentIndex<Result>(parse: (String.Index) throws -> Result) rethrows -> Result {
        try parse(currentIndex)
    }
    
    private func location(from index: String.Index) -> SourceLocation {
        SourceLocation(index..<currentIndex, source: entireSource)
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
            
            addingElement(styling(for: term)) {
                source.removeFirst(termString.count)
            }
            eatCommentsAndWhitespace()
            
            var sourceWithColon: Substring = source
            while tryEating(prefix: ":") {
                // For explicit term specification Lhs : rhs,
                // avoid eating the colon unless:
                //  a) Lhs contains a dictionary, *and*
                //  b) rhs is a term defined by that dictionary.
                guard
                    let dictionary = (term as? TermDictionaryContainer)?.storedDictionary,
                    let result = findTerm(in: dictionary)
                else {
                    // Restore the colon. It may have come from some other construct,
                    // e.g., a record key such as: {Math : pi: "the constant pi"}
                    source = sourceWithColon
                    
                    return term
                }
                
                // Eat rhs.
                (termString, term) = result
                
                addingElement(styling(for: term)) {
                    source.removeFirst(termString.count)
                }
                eatCommentsAndWhitespace()
                
                // We're committed to this colon forming an explicit specification
                sourceWithColon = source
            }
            
            return term
        }
        func eatRawFormTerm() throws -> Term? {
            return try withCurrentIndex { startIndex in
                guard source.removePrefix("«") else {
                    return nil
                }
                
                eatCommentsAndWhitespace()
                
                guard let kind = eatTermTypeName() else {
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
                    lexicon.pool.add(maybeTerm!)
                }
                
                guard let term = maybeTerm as? Terminology.Term else {
                    throw ParseError(description: "wrong type of term for context", location: currentLocation)
                }
                
                addElement(from: startIndex, styling: styling(for: term), spacing: .leftRight)
                
                return term
            }
        }
        
        return try eatDefinedTerm() ?? eatRawFormTerm()
    }
    
    func parseTermTypeName() -> TypedTermUID.Kind? {
        addingElement {
            eatTermTypeName()
        }
    }
    
    func eatTermTypeName() -> TypedTermUID.Kind? {
        guard let kindString = TermName.nextWord(in: source) else {
            return nil
        }
        source.removeLeadingWhitespace()
        source.removeFirst(kindString.count)
        return TypedTermUID.Kind(rawValue: String(kindString))
    }
    
    func styling(for term: Term) -> Styling {
        styling(for: term.typedUID.kind)
    }
    
    func styling(for termKind: TypedTermUID.Kind) -> Styling {
        switch termKind {
        case .dictionary:
            return .dictionary
        case .type:
            return .type
        case .property:
            return .property
        case .constant:
            return .constant
        case .command:
            return .command
        case .parameter:
            return .parameter
        case .variable:
            return .variable
        case .resource:
            return .resource
        }
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
        case .constant:
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

/// An `assert()` that always evaluates its condition.
///
/// - Parameters:
///   - condition: The condition to test; always evaluated.
///   - message: A string to print if condition is evaluated to false.
///              The default is an empty string.
///   - file: The file name to print with message if the assertion fails.
///           The default is the file where `assume(_:_:file:line:)` is called.
///   - line: The line number to print along with message if the assertion fails.
///           The default is the line number where `assume(_:_:file:line:)` is called.
private func assume(_ condition: Bool, _ message: @autoclosure () -> String = String(), file: StaticString = #file, line: UInt = #line) {
    assert(condition, message(), file: file, line: line)
}

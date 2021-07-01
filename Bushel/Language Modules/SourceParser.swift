import SDEFinitely
import os
import Regex

private let log = OSLog(subsystem: logSubsystem, category: "Source parser")

public typealias KeywordHandler = () throws -> Expression.Kind?
public typealias ResourceTypeHandler = (_ name: Term.Name) throws -> Term

/// Parses source code into an AST.
public protocol SourceParser: AnyObject {
    
    var messageFormatter: MessageFormatter { get }
    
    var entireSource: String { get set }
    var source: Substring { get set }
    var expressionStartIndices: [String.Index] { get set }
    var termNameStartIndex: String.Index { get set }
    
    var lexicon: Lexicon { get set }
    var typeTree: TypeTree { get set }
    var sequenceNestingLevel: Int { get set }
    var elements: Set<SourceElement> { get set }
    var awaitingExpressionEndKeywords: [Set<Term.Name>] { get set }
    var endExpression: Bool { get set }
    var allowSuffixSpecifierStack: [Bool] { get set }
    
    var keywordsTraversalTable: TermNameTraversalTable { get set }
    var prefixOperatorsTraversalTable: TermNameTraversalTable { get set }
    var postfixOperatorsTraversalTable: TermNameTraversalTable { get set }
    var binaryOperatorsTraversalTable: TermNameTraversalTable { get set }
    
    var nativeImports: Set<URL> { get set }
    
    var keywords: [Term.Name : KeywordHandler] { get }
    var resourceTypes: [Term.Name : (hasName: Bool, stoppingAt: [String], handler: ResourceTypeHandler)] { get }
    var prefixOperators: [Term.Name : UnaryOperation] { get }
    var postfixOperators: [Term.Name : UnaryOperation] { get }
    var infixOperators: [Term.Name : BinaryOperation] { get }
    var suffixSpecifierMarkers: [Term.Name] { get }
    var stringMarkers: [(begin: Term.Name, end: Term.Name)] { get }
    var expressionGroupingMarkers: [(begin: Term.Name, end: Term.Name)] { get }
    var listMarkers: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name])] { get }
    var recordMarkers: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])] { get }
    var listAndRecordMarkers: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])] { get }
    var lineCommentMarkers: [Term.Name] { get }
    var blockCommentMarkers: [(begin: Term.Name, end: Term.Name)] { get }
    
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

// MARK: Consumer interface
extension SourceParser {
    
    public init(translations allTranslations: [Translation]) {
        self.init()
        
        self.entireSource = ""
        
        // Handle top-level Script and Core terms specially:
        // Push Script, then push Core.
        var translations = allTranslations
        for index in allTranslations.indices {
            var translation = allTranslations[index]
            
            if let scriptTermNames = translation.mappings[Lexicon.defaultRootTermID] {
                translation.mappings.removeValue(forKey: Lexicon.defaultRootTermID)
                
                lexicon.rootTerm = Term(Lexicon.defaultRootTermID, name: scriptTermNames.first!)
            }
            
            let coreTermID = Term.ID(Variables.Core)
            if let coreTermNames = translation.mappings[coreTermID] {
                translation.mappings.removeValue(forKey: coreTermID)
                
                let coreTerm = Term(coreTermID, name: coreTermNames.first!, exports: true)
                lexicon.addPush(coreTerm)
            }
            
            translations[index] = translation
        }
        
        // Add all other terms.
        for translation in translations {
            lexicon.add(translation.makeTerms(typeTree: typeTree))
        }
        
        lexicon.add(Term(Term.ID(Parameters.direct)))
        lexicon.add(Term(Term.ID(Parameters.target)))
        
        // Pop the Core term.
        lexicon.pop()
    }
    
    public func parse(source: String, at url: URL?) throws -> Program {
        try parse(source: source, ignoringImports: url.map { [$0] } ?? [])
    }
    
    public func parse(source: String, ignoringImports: Set<URL> = []) throws -> Program {
        self.entireSource = source
        self.source = Substring(source)
        self.nativeImports = ignoringImports
        return try parseDocument()
    }
    
    public func continueParsing(from newSource: String) throws -> Program {
        let previousSource = self.entireSource
        self.entireSource += newSource
        self.source = self.entireSource[self.entireSource.index(self.entireSource.startIndex, offsetBy: previousSource.count)...]
        return try parseDocument()
    }
    
    private func parseDocument() throws -> Program {
        signpostBegin()
        defer { signpostEnd() }
        
        self.sequenceNestingLevel = -1
        self.elements = []
        
        guard !entireSource.isEmpty else {
            return Program(Expression(.sequence([]), at: currentLocation), [], source: entireSource, rootTerm: lexicon.rootTerm, typeTree: typeTree)
        }
        
        buildTraversalTables()
        
        defer {
            lexicon.pop()
        }
        do {
            let sequence = try parseSequence()
            eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true)
            return Program(sequence, elements, source: entireSource, rootTerm: lexicon.rootTerm, typeTree: typeTree)
        } catch var error as ParseErrorProtocol {
            if !entireSource.range.contains(error.location.range.lowerBound) {
                error.location.range = entireSource.index(before: entireSource.endIndex)..<entireSource.endIndex
            }
            throw messageFormatter.format(error: error)
        }
    }
    
    private func buildTraversalTables() {
        keywordsTraversalTable = buildTraversalTable(for: keywords.keys)
        prefixOperatorsTraversalTable = buildTraversalTable(for: prefixOperators.keys)
        postfixOperatorsTraversalTable = buildTraversalTable(for: postfixOperators.keys)
        binaryOperatorsTraversalTable = buildTraversalTable(for: infixOperators.keys)
    }
    
}

// MARK: Off-the-shelf keyword handlers
extension SourceParser {
    
    public func handleUse() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        
        let typeNamesLongestFirst = resourceTypes.keys
            .sorted(by: { lhs, rhs in lhs.normalized.caseInsensitiveCompare(rhs.normalized) == .orderedAscending })
            .reversed()
        
        guard let typeName = typeNamesLongestFirst.first(where: { tryEating($0) }) else {
            throw ParseError(.invalidResourceType(validTypes: typeNamesLongestFirst
            .reversed()), at: SourceLocation(currentIndex..<source.endIndex, source: entireSource))
        }
        
        let (hasName, stoppingAt, handler) = resourceTypes[typeName]!
        
        eatCommentsAndWhitespace()
        
        guard !source.hasPrefix("\"") else {
            throw ParseError(.quotedResourceTerm, at: currentLocation)
        }
        
        eatCommentsAndWhitespace()
        
        var name = Term.Name("")
        if hasName {
            guard let name_ = try parseTermNameEagerly(stoppingAt: stoppingAt, styling: .resource) else {
                throw ParseError(.missing([.resourceName]), at: currentLocation)
            }
            name = name_
        }
        
        eatCommentsAndWhitespace()
        
        let resourceTerm = try handler(name)
        lexicon.add(resourceTerm)
        return .use(resource: resourceTerm)
    }
    
    public func handleEnd() throws -> Expression.Kind? {
        endExpression = true
        return nil
    }
    
    public func handleReturn() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        return .return_(source.first?.isNewline ?? true ? nil : try parsePrimary())
    }
    
    public func handleRaise(_ keyword: Term.Name) -> () throws -> Expression.Kind? {
        { [weak self] in
            try self?.handleRaise(keyword)
        }
    }
    
    public func handleRaise(_ keyword: Term.Name) throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        
        guard let error = try parsePrimary() else {
            throw ParseError(.missing([.expression], .afterKeyword(keyword)), at: currentLocation)
        }
        return .raise(error)
    }
    
    public func handleThat() throws -> Expression.Kind? {
        .that
    }
    
    public func handleIt() throws -> Expression.Kind? {
        .it
    }
    
    public func handleNull() throws -> Expression.Kind? {
        .null
    }
    
    public func handleRef(_ keyword: Term.Name) -> () throws -> Expression.Kind? {
        { [weak self] in
            try self?.handleRef(keyword)
        }
    }
    
    public func handleRef(_ keyword: Term.Name) throws -> Expression.Kind? {
        guard let expression = try parsePrimary() else {
            throw ParseError(.missing([.expression], .afterKeyword(keyword)), at: currentLocation)
        }
        return .reference(to: expression)
    }
    
    public func handleGet(_ keyword: Term.Name) -> () throws -> Expression.Kind? {
        { [weak self] in
            try self?.handleGet(keyword)
        }
    }
    
    public func handleGet(_ keyword: Term.Name) throws -> Expression.Kind? {
        guard let expression = try self.parsePrimary() else {
            throw ParseError(.missing([.expression], .afterKeyword(keyword)), at: currentLocation)
        }
        return .get(expression)
    }
    
    public func handleDebugInspectTerm() throws -> Expression.Kind? {
        guard let term = try eatTerm() else {
            throw ParseError(.missing([.term()]), at: expressionLocation)
        }
        let inspection = term.debugDescriptionLong
        printDebugMessage(inspection)
        return .debugInspectTerm(term: term, message: inspection)
    }
    
    public func handleDebugInspectLexicon() throws -> Expression.Kind? {
        let inspection = lexicon.debugDescription
        printDebugMessage(inspection)
        return .debugInspectLexicon(message: inspection)
    }
    
    private func printDebugMessage(_ message: String) {
        os_log("%@:\n%@", log: log, String(entireSource[expressionLocation.range]), message)
    }
    
}
    
// MARK: Primary and sequence parsing
extension SourceParser {
    
    public func parseSequence(stoppingAt stopKeywords: [String] = []) throws -> Expression {
        // Matched by endExpression check below
        sequenceNestingLevel += 1
        
        var expressions: [Expression] = []
        
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
            }
            if endExpression {
                endExpression = false
                sequenceNestingLevel -= 1
                
                elements.remove(indentation)
                elements.insert(SourceElement(Indentation(level: sequenceNestingLevel, location: indentation.location)))
                
                break
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
                throw ParseError(.missing([.lineBreak], .afterSequencedExpression), at: location, fixes: [PrependingFix(prepending: "\n", at: location)])
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
    
    public func parsePrimaryOrThrow(_ context: ParseError.Error.Context, allowSuffixSpecifier: Bool = true) throws -> Expression {
        guard let expression = try parsePrimary(allowSuffixSpecifier: allowSuffixSpecifier) else {
            throw ParseError(.missing([.expression], context), at: currentLocation)
        }
        return expression
    }
    public func parsePrimary(lastOperation: BinaryOperation? = nil, allowSuffixSpecifier: Bool = true) throws -> Expression? {
        expressionStartIndices.append(currentIndex)
        allowSuffixSpecifierStack.append(allowSuffixSpecifier)
        defer {
            eatCommentsAndWhitespace()
            allowSuffixSpecifierStack.removeLast()
            expressionStartIndices.removeLast()
        }
        
        guard var primary: Expression = try ({
            do {
                return try parseUnprocessedPrimary()
            } catch {
                if let prefix = try parsePrefixOperators() {
                    return prefix
                } else {
                    throw error
                }
            }
        }()) else {
            return nil
        }
        
        if !(allowSuffixSpecifierStack.last!), findSuffixSpecifierMarker() != nil {
            return primary
        }
        
        while let processedPrimary = try (
            postprocess(primary: primary).map {
                Expression($0, at: expressionLocation)
            } ?? parsePostfixOperators()
        ) {
            primary = processedPrimary
        }
        
        while let processedPrimary = try processBinaryOperators(after: primary, lastOperation: lastOperation) {
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
            
            source.removeLeadingWhitespace()
            guard let rhs = try parsePrimary(lastOperation: operation) else {
                throw ParseError(.missing([.expression], .afterInfixOperator), at: currentLocation)
            }
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
                throw ParseError(.missing([.expression], .afterPrefixOperator), at: expressionLocation)
            }
            
            expression = Expression(.prefixOperator(operation: operation, operand: operand), at: expressionLocation)
        }
        return expression
    }
    
    private func parsePostfixOperators() throws -> Expression? {
        eatCommentsAndWhitespace()
        var expression: Expression?
        while let (_, operation) = eatPostfixOperator() {
            
            eatCommentsAndWhitespace()
            guard let operand = try expression ?? parsePrimary() else {
                throw ParseError(.missing([.expression], .afterPostfixOperator), at: expressionLocation)
            }
            
            expression = Expression(.postfixOperator(operation: operation, operand: operand), at: expressionLocation)
        }
        return expression
    }
    
    private func parseUnprocessedPrimary() throws -> Expression? {
        eatCommentsAndWhitespace()
        
        if let bihash = try eatBihash() {
            var body = ""
            
            while !source.isEmpty {
                addingElement(.string, spacing: .none) {
                    source.removeLeadingWhitespace()
                    // Remove leading newline
                    if source.first?.isNewline ?? false {
                        _ = source.removeFirst()
                    }
                }
                
                let rollbackSource = source // Preserve leading whitespace
                let rollbackElements = elements
                if let _ = try eatBihash(delimiter: bihash.delimiter) {
                    break
                } else {
                    source = rollbackSource
                    elements = rollbackElements
                    let line = String(source.prefix { !$0.isNewline })
                    body += "\(line)\n"
                    addingElement(.string, spacing: .none) {
                        source.removeFirst(line.count)
                    }
                }
            }
            
            return Expression(.multilineString(bihash: bihash, body: body), at: expressionLocation)
        } else if let hashbang = eatHashbang() {
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
                    return Expression(.weave(hashbang: hashbang, body: body), at: endLocation)
                } else {
                    // Program ends in a weave
                    return Expression(.weave(hashbang: hashbang, body: body), at: SourceLocation(hashbang.location.range.lowerBound..<currentIndex, source: entireSource))
                }
            }
            
            return Expression(.sequence(weaves), at: expressionLocation)
        } else if let (startMarker, endMarker) = eatStringBeginMarker() {
            guard
                let match = tryEating(try! Regex(string: #"(.*?)(?:(?<!\\)|(?<=\\\\))\#(endMarker)"#, options: .dotMatchesLineSeparators), .string, spacing: .right),
                let string = match.captures[0]
            else {
                throw ParseError(.invalidString, at: currentLocation)
            }
            let entireLiteral = "\(startMarker)\(match.matchedString)"
            
            var finalString = ""
            var index = string.startIndex
            while index < string.endIndex {
                if string[index] == "\\" {
                    index = string.index(after: index)
                    guard index < string.endIndex else {
                        throw ParseError(.invalidString, at: currentLocation)
                    }
                    finalString.append(try {
                        switch string[index] {
                        case "\\":
                            return "\\"
                        case "t":
                            return "\t"
                        case "n":
                            return "\n"
                        case "r":
                            return "\r"
                        case endMarker.words.first!.first!:
                            return endMarker.words.first!.first!
                        default:
                            let escSequenceOffset = string.distance(from: string.startIndex, to: index)
                            let escSequenceStartIndex = entireSource.index(expressionStartIndex, offsetBy: startMarker.normalized.count + escSequenceOffset - 1)
                            throw ParseError(.invalidString, at: SourceLocation(escSequenceStartIndex..<entireSource.index(escSequenceStartIndex, offsetBy: 2), source: entireSource))
                        }
                    }() as Character)
                } else {
                    finalString.append(string[index])
                }
                index = string.index(after: index)
            }
            
            return Expression(.string(finalString, raw: entireLiteral), at: expressionLocation)
        } else if let groupedExpression = try parseGroupedExpression() {
            return groupedExpression
        } else if let (_, endMarker, itemSeparators, keyValueSeparators) = eatListAndRecordBeginMarker() {
            return try awaiting(endMarkers: Set([endMarker] + itemSeparators + keyValueSeparators)) {
                eatCommentsAndWhitespace(eatingNewlines: true)
                
                guard !tryEating(endMarker, spacing: .right) else {
                    return Expression(.list([]), at: expressionLocation)
                }
                if let initialKeyValueSeparator = tryEating(oneOf: keyValueSeparators, spacing: .right) {
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(.missing([.recordKeyBeforeKeyValueSeparatorOrEndMarkerAfter(keyValueSeparator: initialKeyValueSeparator, endMarker: endMarker)]), at: currentLocation)
                    }
                    return Expression(.record([]), at: expressionLocation)
                }
                
                let first = try parseListItem(as: [.listItem, .recordKey])
                
                if tryEating(endMarker, spacing: .right) {
                    return Expression(.list([first]), at: expressionLocation)
                } else if let itemSeparator = tryEating(oneOf: itemSeparators, spacing: .right) {
                    var items: [Expression] = [first]
                    repeat {
                        items.append(try parseListItem(as: [.listItem]))
                    } while tryEating(itemSeparator, spacing: .right)
                    
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(.missing([.listItemSeparatorOrEndMarker(itemSeparator: itemSeparator, endMarker: endMarker)]), at: currentLocation)
                    }
                    return Expression(.list(items), at: expressionLocation)
                } else if let keyValueSeparator = tryEating(oneOf: keyValueSeparators, spacing: .right) {
                    let first = (key: first, value: try parseListItem(as: [.recordItem]))
                    var items: [(key: Expression, value: Expression)] = [first]
                    
                    if let itemSeparator = tryEating(oneOf: itemSeparators, spacing: .right) {
                        repeat {
                            let key = try parseListItem(as: [.recordKey])
                            guard tryEating(keyValueSeparator, spacing: .right) else {
                                throw ParseError(.missing([.recordKeyValueSeparatorAfterKey(keyValueSeparator: keyValueSeparator)]), at: currentLocation)
                            }
                            let value = try parseListItem(as: [.recordItem])
                            items.append((key: key, value: value))
                        } while tryEating(itemSeparator, spacing: .right)
                    }
                    
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(.missing(
                            [.recordItemSeparatorOrEndMarker(
                                itemSeparator: itemSeparators.first!,
                                endMarker: endMarker
                            )]
                        ), at: currentLocation)
                    }
                    return Expression(.record(items), at: expressionLocation)
                } else {
                    throw ParseError(.missing(
                        [.listAndRecordItemSeparatorOrKeyValueSeparatorOrEndMarker(
                            itemSeparator: itemSeparators.first!,
                            keyValueSeparator: keyValueSeparators.first!,
                            endMarker: endMarker
                        )]
                    ), at: currentLocation)
                }
            }
        } else if let (_, endMarker, itemSeparators) = eatListBeginMarker() {
            return try awaiting(endMarkers: Set([endMarker] + itemSeparators)) {
                eatCommentsAndWhitespace(eatingNewlines: true)
                
                guard !tryEating(endMarker, spacing: .right) else {
                    return Expression(.list([]), at: expressionLocation)
                }
                
                let first = try parseListItem(as: [.listItem])
                
                if tryEating(endMarker, spacing: .right) {
                    return Expression(.list([first]), at: expressionLocation)
                } else if let itemSeparator = tryEating(oneOf: itemSeparators, spacing: .right) {
                    var items: [Expression] = [first]
                    repeat {
                        items.append(try parseListItem(as: [.listItem]))
                    } while tryEating(itemSeparator, spacing: .right)
                    
                    guard tryEating(endMarker, spacing: .right) else {
                        throw ParseError(.missing([.listItemSeparatorOrEndMarker(itemSeparator: itemSeparator, endMarker: endMarker)]), at: currentLocation)
                    }
                    return Expression(.list(items), at: expressionLocation)
                } else {
                    throw ParseError(.missing([.listItemSeparatorOrEndMarker(itemSeparator: itemSeparators.first!, endMarker: endMarker)]), at: currentLocation)
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
                        throw ParseError(.missing(
                            [.recordKeyBeforeKeyValueSeparatorOrEndMarkerAfter(
                                keyValueSeparator: initialKeyValueSeparator,
                                endMarker: endMarker
                            )]
                        ), at: currentLocation)
                    }
                    return Expression(.record([]), at: expressionLocation)
                }
                
                let firstKey = try parseListItem(as: [.recordKey])
                guard let keyValueSeparator = tryEating(oneOf: keyValueSeparators, spacing: .right) else {
                    throw ParseError(.missing([.recordKeyValueSeparatorAfterKey(keyValueSeparator: keyValueSeparators.first!)]), at: currentLocation)
                }
                let first = (key: firstKey, value: try parseListItem(as: [.recordItem]))
                
                var items: [(key: Expression, value: Expression)] = [first]
                if let itemSeparator = tryEating(oneOf: itemSeparators, spacing: .right) {
                    repeat {
                        let key = try parseListItem(as: [.recordKey])
                        guard tryEating(keyValueSeparator, spacing: .right) else {
                            throw ParseError(.missing([.recordKeyValueSeparatorAfterKey(keyValueSeparator: keyValueSeparator)]), at: currentLocation)
                        }
                        let value = try parseListItem(as: [.recordItem])
                        items.append((key: key, value: value))
                    } while tryEating(itemSeparator, spacing: .right)
                }
                
                guard tryEating(endMarker, spacing: .right) else {
                    throw ParseError(.missing([.recordItemSeparatorOrEndMarker(itemSeparator: itemSeparators.first!, endMarker: endMarker)]), at: currentLocation)
                }
                return Expression(.record(items), at: expressionLocation)
            }
        } else if let termName = eatKeyword() {
            if let kind = try keywords[termName]!() {
                return Expression(kind, at: expressionLocation)
            } else {
                return nil
            }
        } else if let term = try eatTerm() {
            if let kind = try handle(term: term) {
                return Expression(kind, at: expressionLocation)
            } else {
                return nil
            }
        } else if
            let endKeyword = awaitingExpressionEndKeywords.last,
            endKeyword.contains(where: isNext)
        {
            // Allow outer awaiting() call to eat.
            return nil
        } else {
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
                            throw ParseError(.invalidNumber, at: expressionLocation)
                        }
                        return Expression(.double(value), at: expressionLocation)
                    }
                    return try parseInteger() ?? parseDouble()
                }
            } else {
                os_log("Undefined term: %@", log: log, type: .debug, String(source))
                throw ParseError(.undefinedTerm, at: SourceLocation(currentIndex..<(source.firstIndex(where: { $0.isNewline }) ?? source.endIndex), source: entireSource))
            }
        }
    }
    
}

// MARK: Parse helpers
extension SourceParser {
    
    public func parseGroupedExpression() throws -> Expression? {
        guard let (beginMarker, endMarker) = eatExpressionGroupingBeginMarker() else {
            return nil
        }
        return try awaiting(endMarker: endMarker) {
            eatCommentsAndWhitespace(eatingNewlines: true)
            
            guard let enclosed = try parsePrimary() else {
                throw ParseError(.missing([.expression], .afterKeyword(beginMarker)), at: expressionLocation)
            }
            
            eatCommentsAndWhitespace(eatingNewlines: true)
            guard tryEating(endMarker, spacing: .right) else {
                throw ParseError(.missing([.keyword(endMarker)], .adHoc("to end grouped expression")), at: expressionLocation)
            }
            
            return Expression(.parentheses(enclosed), at: expressionLocation)
        }
    }
    
    public func parseVariableTermOrThrow(stoppingAt: [String] = [], _ context: ParseError.Error.Context? = nil) throws -> Term {
        guard let variable = try parseVariableTerm(stoppingAt: stoppingAt) else {
            throw ParseError(.missing([.variableName], context), at: currentLocation)
        }
        return variable
    }
    public func parseVariableTerm(stoppingAt: [String] = []) throws -> Term? {
        guard
            let termName = try parseTermNameEagerly(stoppingAt: stoppingAt, styling: .variable),
            !termName.words.isEmpty
        else {
            return nil
        }
        return Term(.variable, lexicon.makeURI(forName: termName), name: termName)
    }
    
    public func parseTermNameEagerlyOrThrow(stoppingAt: [String] = [], styling: Styling = .keyword, _ context: ParseError.Error.Context? = nil) throws -> Term.Name {
        guard let name = try parseTermNameEagerly(stoppingAt: stoppingAt, styling: styling) else {
            throw ParseError(.missing([.termName], context), at: currentLocation)
        }
        return name
    }
    public func parseTermNameEagerly(stoppingAt: [String] = [], styling: Styling = .keyword) throws -> Term.Name? {
        let restOfLine = source.prefix { !$0.isNewline }
        let startIndex = restOfLine.startIndex
        let allWords = Term.Name.words(in: restOfLine)
        
        guard !allWords.isEmpty else {
            return nil
        }
        guard allWords.first! != "|" else {
            // Lazy parsing handles pipe escapes
            return try parseTermNameLazily(styling: styling)
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
        return Term.Name(words)
    }
    
    public func parseTypeTermOrThrow(_ context: ParseError.Error.Context? = nil) throws -> Term {
        guard let type = try parseTypeTerm() else {
            throw ParseError(.missing([.term(.type)], context), at: currentLocation)
        }
        return type
    }
    public func parseTypeTerm() throws -> Term? {
        let term = try eatTerm()
        switch term?.role {
        case .type:
            return term
        default:
            return nil
        }
    }
    
    public func parseString() throws -> (expression: Expression, value: String)? {
        guard let expression = try parsePrimary() else {
            return nil
        }
        switch expression.kind {
        case .string(let value, _):
            return (expression, value)
        default:
            return nil
        }
    }
    
    public func parseTermNameLazily(styling: Styling = .keyword) throws -> Term.Name? {
        let restOfLine = source.prefix { !$0.isNewline }
        let startIndex = restOfLine.startIndex
        let words = Term.Name.words(in: restOfLine)
        
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
                    return Term.Name(wordsWithoutPipes)
                }
            }
            throw ParseError(.mismatchedPipe, at: SourceLocation(termNameStartIndex..<source.startIndex, source: entireSource))
        } else {
            termNameStartIndex = startIndex
            return Term.Name(firstWord)
        }
    }
    
    public func parseTermRoleName() -> Term.SyntacticRole? {
        addingElement {
            eatTermRoleName()
        }
    }
    
    private func eatTermRoleName() -> Term.SyntacticRole? {
        guard let kindString = Term.Name.nextWord(in: source) else {
            return nil
        }
        source.removeLeadingWhitespace()
        source.removeFirst(kindString.count)
        return Term.SyntacticRole(rawValue: String(kindString))
    }
    
    private func eatFromSource(_ words: [String], styling: Styling = .keyword) {
        for word in words {
            source.removeLeadingWhitespace()
            addingElement(styling) {
                source.removeFirst(word.count)
            }
        }
    }
    
    private func parseListItem(as elements: [ParseError.Error.Element]) throws -> Expression {
        eatCommentsAndWhitespace(eatingNewlines: true)
        
        guard let item = try parsePrimary() else {
            throw ParseError(.missing(elements), at: currentLocation)
        }
        
        eatCommentsAndWhitespace(eatingNewlines: true)
        return item
    }
    
    private func parseNewline() -> Expression? {
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
    
    private func eatBihash(delimiter: String? = nil) throws -> Bihash? {
        guard tryEating(prefix: "##") else {
            return nil
        }
        if let delimiter = delimiter {
            guard
                delimiter.isEmpty || (
                    tryEating(prefix: "(", spacing: .none) &&
                    tryEating(prefix: delimiter, .weave) &&
                    tryEating(prefix: ")", spacing: .right)
                )
            else {
                return nil
            }
        }
        
        var delimiter = delimiter
        if
            delimiter == nil,
            tryEating(prefix: "(", spacing: .none)
        {
            source.removeLeadingWhitespace()
            
            let line = source[..<(source.firstIndex { $0.isNewline } ?? source.endIndex)]
            
            guard let endDelimiterIndex = line.firstIndex(of: ")") else {
                throw ParseError(.missing([.weaveDelimiter]), at: currentLocation)
            }
            let newDelimiter = String(line[..<endDelimiterIndex].dropLast(while: { $0.isWhitespace }))
            delimiter = newDelimiter
            if newDelimiter.isEmpty {
                throw ParseError(.missing([.weaveDelimiter]), at: currentLocation)
            }
            assume(tryEating(prefix: newDelimiter, .weave))
            
            guard tryEating(prefix: ")", spacing: .right) else {
                throw ParseError(.missing([.weaveDelimiterEndMarker]), at: currentLocation)
            }
        }
        
        return Bihash(delimiter: delimiter ?? "")
    }
    
    private func eatHashbang() -> Hashbang? {
        guard tryEating(prefix: "#!", spacing: .left) else {
            return nil
        }
        
        let invocationSource = source.prefix { !$0.isNewline }
        addingElement {
            source.removeFirst(invocationSource.count)
        }
        
        return Hashbang(String(invocationSource), at: expressionLocation)
    }
    
    private func eatLineCommentMarker() -> Bool {
        lineCommentMarkers.first { tryRemovingPrefix($0, withComments: false) } != nil
    }
    
    private func eatBlockCommentBeginMarker() -> Bool {
        blockCommentMarkers.first { tryRemovingPrefix($0.begin, withComments: false) } != nil
    }
    
    private func eatBlockCommentEndMarker() -> Bool {
        blockCommentMarkers.first { tryRemovingPrefix($0.end, withComments: false) } != nil
    }
    
    private func eatKeyword() -> Term.Name? {
        let result = findComplexTermName(from: keywordsTraversalTable, in: source)
        guard let termName = result.termName else {
            return nil
        }
        addingElement(spacing: termName.normalized.last!.isWordBreaking ? .left : .leftRight) {
            source.removeFirst(result.termString.count)
        }
        return termName
    }
    
    private func findPrefixOperator() -> (termName: Term.Name, operator: UnaryOperation)? {
        let result = findComplexTermName(from: prefixOperatorsTraversalTable, in: source)
        return result.termName.map { name in
            (termName: name, operator: prefixOperators[name]!)
        }
    }
    
    private func eatPrefixOperator() {
        let result = findComplexTermName(from: prefixOperatorsTraversalTable, in: source)
        guard result.termName != nil else {
            return
        }
        addingElement(.operator) {
            source.removeFirst(result.termString.count)
        }
    }
    
    private func eatPostfixOperator() -> (termName: Term.Name, operator: UnaryOperation)? {
        let result = findComplexTermName(from: postfixOperatorsTraversalTable, in: source)
        guard result.termName != nil else {
            return nil
        }
        addingElement(.operator) {
            source.removeFirst(result.termString.count)
        }
        return result.termName.map { termName in
            (termName: termName, operator: postfixOperators[termName]!)
        }
    }
    
    private func findBinaryOperator() -> (termName: Term.Name, operator: BinaryOperation)? {
        let result = findComplexTermName(from: binaryOperatorsTraversalTable, in: source)
        return result.termName.map { name in
            (termName: name, operator: infixOperators[name]!)
        }
    }
    
    private func eatBinaryOperator() {
        let result = findComplexTermName(from: binaryOperatorsTraversalTable, in: source)
        guard result.termName != nil else {
            return
        }
        addingElement(.operator) {
            source.removeFirst(result.termString.count)
        }
        eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true)
    }
    
    private func findSuffixSpecifierMarker() -> Term.Name? {
        suffixSpecifierMarkers.first { isNext($0) }
    }
    
    public func eatSuffixSpecifierMarker() -> Term.Name? {
        suffixSpecifierMarkers.first { tryEating($0) }
    }
    
    private func eatStringBeginMarker() -> (begin: Term.Name, end: Term.Name)? {
        stringMarkers.first { tryEating($0.begin, .string, spacing: .left) }
    }
    
    private func eatExpressionGroupingBeginMarker() -> (begin: Term.Name, end: Term.Name)? {
        expressionGroupingMarkers.first { tryEating($0.begin, spacing: .left) }
    }
    
    private func eatListBeginMarker() -> (begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name])? {
        listMarkers.first { tryEating($0.begin, spacing: .left) }
    }
    
    private func eatRecordBeginMarker() -> (begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])? {
        recordMarkers.first { tryEating($0.begin, spacing: .left) }
    }
    
    private func eatListAndRecordBeginMarker() -> (begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])? {
        listAndRecordMarkers.first { tryEating($0.begin, spacing: .left) }
    }
    
}

// MARK: Parse primitives
extension SourceParser {
    
    public func tryEating(_ termName: Term.Name, _ styling: Styling = .keyword, spacing: Spacing = .leftRight) -> Bool {
        addingElement(styling, spacing: spacing) {
            tryRemovingPrefix(termName)
        }
    }
    
    public func tryEating(oneOf termNames: [Term.Name], _ styling: Styling = .keyword, spacing: Spacing = .leftRight) -> Term.Name? {
        termNames.first { tryEating($0, styling, spacing: spacing) }
    }
    
    public func eatLineBreakOrThrow(_ context: ParseError.Error.Context? = nil) throws {
        guard tryEatingLineBreak() else {
            throw ParseError(.missing([.lineBreak], context), at: currentLocation)
        }
    }
    public func tryEatingLineBreak() -> Bool {
        tryEating(Regex("\r?\n|\r")) != nil
    }
    
    public func eatOrThrow(prefix: String, _ styling: Styling = .keyword, spacing: Spacing = .leftRight) throws {
        guard tryEating(prefix: prefix, styling, spacing: spacing) else {
            throw ParseError(.missing([.keyword(Term.Name(prefix))]), at: currentLocation)
        }
    }
    public func tryEating(prefix: String, _ styling: Styling = .keyword, spacing: Spacing = .leftRight) -> Bool {
        addingElement(styling, spacing: spacing) {
            tryRemovingPrefix(prefix)
        }
    }
    
    public func tryEating(_ regex: Regex, _ styling: Styling = .keyword, spacing: Spacing = .leftRight) -> MatchResult? {
        // TODO: Patch Regex to accept substrings?
        let restOfSource = String(source)
        guard
            let match = regex.firstMatch(in: restOfSource),
            match.range.lowerBound == restOfSource.startIndex
        else {
            return nil
        }
        
        addingElement(styling, spacing: spacing) {
            source.removeFirst(match.matchedString.count)
        }
        
        return match
    }
    
    public func tryRemovingPrefix(_ termName: Term.Name, withComments: Bool = true) -> Bool {
        let rollbackSource = source
        for word in termName.words {
            guard tryRemovingPrefix(word, withComments: withComments) else {
                source = rollbackSource
                return false
            }
        }
        return true
    }
    
    public func tryRemovingPrefix(_ prefix: String, withComments: Bool = true) -> Bool {
        if withComments {
            eatCommentsAndWhitespace()
        } else {
            source.removeLeadingWhitespace()
        }
        guard isNext(prefix) else {
            return false
        }
        
        source.removeFirst(prefix.count)
        return true
    }
    
    public func isNext(_ termName: Term.Name) -> Bool {
        var source = self.source
        for word in termName.words {
            source.removeLeadingWhitespace()
            guard Self.isNext(word, source: source) else {
                return false
            }
            source.removeFirst(word.count)
        }
        return true
    }
    
    public func isNext(_ prefix: String) -> Bool {
        Self.isNext(prefix, source: source)
    }
    
    public static func isNext(_ prefix: String, source: Substring) -> Bool {
        source.hasPrefix(prefix) &&
            (prefix.last!.isWordBreaking || (source.dropFirst(prefix.count).first?.isWordBreaking ?? true))
    }
    
    public func awaiting<Result>(endMarkers: Set<Term.Name>, perform action: () throws -> Result) rethrows -> Result {
        awaitingExpressionEndKeywords.append(endMarkers)
        defer {
            awaitingExpressionEndKeywords.removeLast()
        }
        return try action()
    }
    
    public func awaiting<Result>(endMarker: Term.Name, perform action: () throws -> Result) rethrows -> Result {
        try awaiting(endMarkers: [endMarker], perform: action)
    }
    
    public func withScope(parse: () throws -> Expression) rethrows -> Expression {
        lexicon.pushUnnamedDictionary()
        defer { lexicon.pop() }
        return Expression(.scoped(try parse()), at: expressionLocation)
    }
    
    public func withTerminology<Result>(of term: Term, parse: () throws -> Result) throws -> Result {
        lexicon.push(term)
        defer {
            lexicon.pop()
        }
        
        return try parse()
    }
    
    public func withTerminology<Result>(of expression: Expression, parse: () throws -> Result) throws -> Result {
        if let term = expression.term() {
            return try withTerminology(of: term, parse: parse)
        } else {
            return try parse()
        }
    }
    
    public var currentLocation: SourceLocation {
        SourceLocation(at: currentIndex, source: entireSource)
    }
    
    public var currentIndex: String.Index {
        source.startIndex
    }
    
    public var expressionLocation: SourceLocation {
        location(from: expressionStartIndex)
    }
    
    public var expressionStartIndex: String.Index {
        expressionStartIndices.last ?? entireSource.startIndex
    }
    
    public var termNameLocation: SourceLocation {
        location(from: termNameStartIndex)
    }
    
    private func withCurrentIndex<Result>(parse: (String.Index) throws -> Result) rethrows -> Result {
        try parse(currentIndex)
    }
    
    private func location(from index: String.Index) -> SourceLocation {
        SourceLocation(index..<currentIndex, source: entireSource)
    }
    
    public func eatTermOrThrow(_ context: ParseError.Error.Context? = nil) throws -> Term {
        guard let term = try eatTerm() else {
            throw ParseError(.missing([.term()], context), at: currentLocation)
        }
        return term
    }
    public func eatTerm() throws -> Term? {
        try eatTerm(from: lexicon)
    }
    
    public func eatTerm<Terminology: ByNameTermLookup>(from dictionary: Terminology, role: Term.SyntacticRole? = nil) throws -> Term? {
        func eatDefinedTerm() -> Term? {
            func findTerm<Terminology: ByNameTermLookup>(in dictionary: Terminology) -> (termString: Substring, term: Term)? {
                eatCommentsAndWhitespace()
                var termString = source.prefix { !$0.isNewline }.prefix { !$0.isWordBreaking || $0.isWhitespace || $0 == ":" }
                while let lastNonBreakingIndex = termString.lastIndex(where: { !$0.isWordBreaking }) {
                    termString = termString[...lastNonBreakingIndex]
                    let termName = Term.Name(String(termString))
                    if let term = dictionary.term(named: termName) {
                        return (termString, term)
                    } else {
                        termString.removeLast(termName.words.last!.count)
                    }
                }
                return nil
            }
            
            guard var (termString, term) = findTerm(in: dictionary) else {
                return nil
            }
            
            if role == nil, tryEating(prefix: ":") {
                addingElement(styling(for: term)) {
                    source.removeFirst(termString.count)
                }
                eatCommentsAndWhitespace()
                
                var sourceWithColon: Substring = source
                repeat {
                    // For explicit term specification Lhs : rhs,
                    // only eat the colon if rhs is the name of a term defined
                    // in the dictionary of Lhs.
                    guard let result = findTerm(in: term.dictionary) else {
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
                } while tryEating(prefix: ":")
                
                return term
            } else if role == nil || term.role == role {
                addingElement(styling(for: term)) {
                    source.removeFirst(termString.count)
                }
                return term
            } else {
                return nil
            }
            
        }
        func eatRawFormTerm() throws -> Term? {
            return try withCurrentIndex { startIndex in
                guard source.removePrefix("«") else {
                    return nil
                }
                
                eatCommentsAndWhitespace()
                
                guard let role = eatTermRoleName() else {
                    throw ParseError(.invalidTermRole, at: currentLocation)
                }
                
                eatCommentsAndWhitespace()
                
                guard let closeBracketRange = source.range(of: "»") else {
                    throw ParseError(.missing([.termURIAndRawFormEndMarker]), at: currentLocation)
                }
                let uidString = source[..<closeBracketRange.lowerBound]
                source = source[closeBracketRange.upperBound...]
                guard let uid = Term.SemanticURI(normalized: String(uidString)) else {
                    throw ParseError(.missing([.termURI]), at: currentLocation)
                }
                
                let term = lexicon.term(id: Term.ID(role, uid)) ?? Term(role, uid)
                
                addElement(from: startIndex, styling: styling(for: term), spacing: .leftRight)
                
                return term
            }
        }
        
        return try eatDefinedTerm() ?? eatRawFormTerm()
    }
    
    public func eatCommentsAndWhitespace(eatingNewlines: Bool = false, isSignificant: Bool = false) {
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
    
    public func addingElement<Result>(_ styling: Styling = .keyword, spacing: Spacing = .leftRight, parse: () throws -> Result) rethrows -> Result {
        try withCurrentIndex { startIndex in
            defer {
                addElement(from: startIndex, styling: styling, spacing: spacing)
            }
            return try parse()
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
    
    public func styling(for term: Term) -> Styling {
        styling(for: term.role)
    }
    
    public func styling(for role: Term.SyntacticRole) -> Styling {
        switch role {
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

extension StringProtocol {
    
    public var range: Range<Index> {
        return startIndex..<endIndex
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
private func assume(_ condition: Bool, _ message: @autoclosure () -> String = String(), file: StaticString = #fileID, line: UInt = #line) {
    assert(condition, message(), file: file, line: line)
}

import SDEFinitely
import os
import Regex

private let log = OSLog(subsystem: logSubsystem, category: "Source parser")

public struct KeywordHandler {
    public init<Weak: AnyObject>(_ weak: Weak, _ fn: @escaping (Weak) -> () throws -> Expression.Kind?) {
        self.fn = { [weak `weak`] in try fn(weak!)() }
    }
    public let fn: () throws -> Expression.Kind?
    public func callAsFunction() throws -> Expression.Kind? {
        try fn()
    }
}

public struct SourceParserState {
    
    public var entireSource: String = ""
    public lazy var source: Substring = Substring(entireSource)
    public var expressionStartIndices: [String.Index] = []
    public lazy var termNameStartIndex: String.Index = entireSource.startIndex
    
    public var lexicon = Lexicon()
    public var cache = globalCache
    public var sequenceNestingLevel: Int = 0
    public var elements: Set<SourceElement> = []
    public var awaitingExpressionEndKeywords: [Set<Term.Name>] = []
    public var lastEndKeyword: Term.Name?
    public var allowSuffixSpecifierStack: [Bool] = []
    
    public var keywordsTraversalTable: TermNameTraversalTable = [:]
    public var prefixOperatorsTraversalTable: TermNameTraversalTable = [:]
    public var postfixOperatorsTraversalTable: TermNameTraversalTable = [:]
    public var binaryOperatorsTraversalTable: TermNameTraversalTable = [:]
    
    public var nativeImports: Set<URL> = []
    
    public init() {
    }
    
}

public struct SourceParserConfig {
    
    public struct Delimiters {
        
        public var suffixSpecifier: [Term.Name]
        public var string: [(begin: Term.Name, end: Term.Name)]
        public var expressionGrouping: [(begin: Term.Name, end: Term.Name)]
        public var list: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name])]
        public var record: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])]
        public var listAndRecord: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])]
        public var lineComment: [Term.Name]
        public var blockComment: [(begin: Term.Name, end: Term.Name)]
        
        public init(suffixSpecifier: [Term.Name], string: [(begin: Term.Name, end: Term.Name)], expressionGrouping: [(begin: Term.Name, end: Term.Name)], list: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name])], record: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])], listAndRecord: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])], lineComment: [Term.Name], blockComment: [(begin: Term.Name, end: Term.Name)]) {
            self.suffixSpecifier = suffixSpecifier
            self.string = string
            self.expressionGrouping = expressionGrouping
            self.list = list
            self.record = record
            self.listAndRecord = listAndRecord
            self.lineComment = lineComment
            self.blockComment = blockComment
        }
        
    }
    
    public struct Operators {
        
        public var prefix: [Term.Name : UnaryOperation]
        public var postfix: [Term.Name : UnaryOperation]
        public var infix: [Term.Name : BinaryOperation]
        
        public init(prefix: [Term.Name : UnaryOperation], postfix: [Term.Name : UnaryOperation], infix: [Term.Name : BinaryOperation]) {
            self.prefix = prefix
            self.postfix = postfix
            self.infix = infix
        }
        
    }
    
    public var defaultEndKeyword: Term.Name
    
    public var keywords: [Term.Name : KeywordHandler]
    public var resourceTypes: [Term.Name : (hasName: Bool, stoppingAt: [String], kind: Resource.Kind)]
    
    public var operators: Operators
    public var delimiters: Delimiters
    
    public init(defaultEndKeyword: Term.Name, keywords: [Term.Name : KeywordHandler], resourceTypes: [Term.Name : (hasName: Bool, stoppingAt: [String], kind: Resource.Kind)], operators: Operators, delimiters: Delimiters) {
        self.defaultEndKeyword = defaultEndKeyword
        self.keywords = keywords
        self.resourceTypes = resourceTypes
        self.operators = operators
        self.delimiters = delimiters
    }
    
}

/// Parses source code into an AST.
public protocol SourceParser: AnyObject {
    
    var messageFormatter: MessageFormatter { get }
    
    var state: SourceParserState { get set }
    var config: SourceParserConfig { get }
    
    init()
    
    func handleType(_ typeTerm: Term) throws -> Expression.Kind?
    func handleCommand(_ commandTerm: Term) throws -> Expression.Kind?
    
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
        
        self.state.entireSource = ""
        
        // Handle top-level Script and Core terms specially:
        // Push Script, then push Core.
        var translations = allTranslations
        for index in allTranslations.indices {
            var translation = allTranslations[index]
            
            if let scriptTermName = translation[Lexicon.defaultRootTermID] {
                translation.removeTerm(for: Lexicon.defaultRootTermID)
                
                state.lexicon = Lexicon(Stack(bottom: Term(Lexicon.defaultRootTermID, name: scriptTermName)))
            }
            
            let coreTermID = Term.ID(Variables.Core)
            if let coreTermName = translation[coreTermID] {
                translation.removeTerm(for: coreTermID)
                
                let coreTerm = Term(coreTermID, name: coreTermName, exports: true)
                state.lexicon.addPush(coreTerm)
            }
            
            translations[index] = translation
        }
        
        // Add all other terms.
        for translation in translations {
            let newTerms = translation.makeTerms(cache: state.cache)
            state.lexicon.top.dictionary.merge(newTerms)
            let newDocs = translation.makeTermDocs(for: newTerms)
            globalTermDocs.value.merge(newDocs, uniquingKeysWith: { old, new in new })
        }
        
        state.lexicon.add(Term(Term.ID(Parameters.direct)))
        state.lexicon.add(Term(Term.ID(Parameters.target)))
        
        // Pop the Core term.
        state.lexicon.pop()
    }
    
    public func parse(source: String, at url: URL?) throws -> Program {
        try parse(source: source, ignoringImports: url.map { [$0] } ?? [])
    }
    
    public func parse(source: String, ignoringImports: Set<URL> = []) throws -> Program {
        self.state.entireSource = source
        self.state.source = Substring(source)
        self.state.nativeImports = ignoringImports
        return try parseDocument()
    }
    
    public func continueParsing(from newSource: String) throws -> Program {
        let previousSource = self.state.entireSource
        self.state.entireSource += newSource
        self.state.source = self.state.entireSource[self.state.entireSource.index(self.state.entireSource.startIndex, offsetBy: previousSource.count)...]
        return try parseDocument()
    }
    
    private func parseDocument() throws -> Program {
        signpostBegin()
        defer { signpostEnd() }
        
        self.state.sequenceNestingLevel = -1
        self.state.elements = []
        
        guard !state.entireSource.isEmpty else {
            return Program(Expression(.sequence([]), at: currentLocation), [], source: state.entireSource, rootTerm: state.lexicon.bottom, termDocs: globalTermDocs, typeTree: globalTypeTree)
        }
        
        buildTraversalTables()
        
        defer {
            state.lexicon.pop()
        }
        do {
            let sequence = try parseSequence()
            eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true)
            return Program(sequence, state.elements, source: state.entireSource, rootTerm: state.lexicon.bottom, termDocs: globalTermDocs, typeTree: globalTypeTree)
        } catch var error as ParseErrorProtocol {
            if !state.entireSource.range.contains(error.location.range.lowerBound) {
                error.location.range = state.entireSource.index(before: state.entireSource.endIndex)..<state.entireSource.endIndex
            }
            throw messageFormatter.format(error: error)
        }
    }
    
    private func buildTraversalTables() {
        state.keywordsTraversalTable = buildTraversalTable(for: config.keywords.keys)
        state.prefixOperatorsTraversalTable = buildTraversalTable(for: config.operators.prefix.keys)
        state.postfixOperatorsTraversalTable = buildTraversalTable(for: config.operators.postfix.keys)
        state.binaryOperatorsTraversalTable = buildTraversalTable(for: config.operators.infix.keys)
    }
    
}

// MARK: Off-the-shelf keyword handlers
extension SourceParser {
    
    public func handleRequire() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        
        let typeNamesLongestFirst = config.resourceTypes.keys
            .sorted(by: { lhs, rhs in lhs.normalized.caseInsensitiveCompare(rhs.normalized) == .orderedAscending })
            .reversed()
        
        guard let typeName = typeNamesLongestFirst.first(where: { tryEating($0) }) else {
            throw ParseError(.invalidResourceType(validTypes: typeNamesLongestFirst
            .reversed()), at: SourceLocation(currentIndex..<state.source.endIndex, source: state.entireSource))
        }
        
        let (hasName, stoppingAt, resourceKind) = config.resourceTypes[typeName]!
        
        eatCommentsAndWhitespace()
        
        guard !state.source.hasPrefix("\"") else {
            throw ParseError(.quotedResourceTerm, at: currentLocation)
        }
        
        eatCommentsAndWhitespace()
        
        let name = try hasName ?
            {
                guard let name = try parseTermNameEagerly(stoppingAt: stoppingAt, styling: .resource) else {
                    throw ParseError(.missing([.resourceName]), at: currentLocation)
                }
                return name
            }() :
            typeName
        
        eatCommentsAndWhitespace()
        
        let resourceTerm: Term = try {
            switch resourceKind {
            case .bushelscript:
                return Term(.resource, .res(""), name: name, resource: .bushelscript)
            case .system:
                let term = Term(.resource, .res("system"), name: name, resource: .system(version:
                    try tryEating(prefix: "version") ? {
                        eatCommentsAndWhitespace()
                        guard let match = tryEating(OperatingSystemVersion.dottedDecimalRegex) else {
                            throw AdHocParseError("Expected OS version number", at: currentLocation)
                        }
                        let osVersion = OperatingSystemVersion(dottedDecimalRegexMatch: match)
                        guard ProcessInfo.processInfo.isOperatingSystemAtLeast(osVersion) else {
                            throw ParseError(.unmetResourceRequirement(.system(version: match.matchedString)), at: termNameLocation)
                        }
                        return osVersion
                    }() : nil
                ))
                try state.cache.dictionaryCache.loadResourceDictionary(for: term)
                return term
            case .applicationByName:
                guard let bundle = try state.cache.resourceCache.app(named: name.normalized) else {
                    throw ParseError(.unmetResourceRequirement(.applicationByName(name: name.normalized)), at: termNameLocation)
                }
                let term = Term(.resource, .res("app:\(name)"), name: name, resource: .applicationByName(bundle: bundle))
                try state.cache.dictionaryCache.loadResourceDictionary(for: term)
                return term
            case .applicationByID:
                guard let bundle = try state.cache.resourceCache.app(id: name.normalized) else {
                    throw ParseError(.unmetResourceRequirement(.applicationByBundleID(bundleID: name.normalized)), at: termNameLocation)
                }
                let term = Term(.resource, .res("appid:\(name)"), name: name, resource: .applicationByID(bundle: bundle))
                try state.cache.dictionaryCache.loadResourceDictionary(for: term)
                return term
            case .libraryByName:
                guard let (url, library) = try state.cache.resourceCache.library(named: name.normalized, ignoring: state.nativeImports) else {
                    throw ParseError(.unmetResourceRequirement(.libraryByName(name: name.normalized)), at: termNameLocation)
                }
                state.nativeImports.insert(url)
                let term = Term(.resource, .res("library:\(name)"), name: name, resource: .libraryByName(name: name.normalized, url: url, library: library))
                try state.cache.dictionaryCache.loadResourceDictionary(for: term)
                return term
            case .applescriptAtPath:
                try eatOrThrow(prefix: "at")
                
                let pathStartIndex = currentIndex
                guard var (_, path) = try parseString() else {
                    throw AdHocParseError("Expected path string", at: currentLocation)
                }
                
                path = (path as NSString).expandingTildeInPath
                
                guard let applescript = try state.cache.resourceCache.applescript(at: path) else {
                    throw ParseError(.unmetResourceRequirement(.applescriptAtPath(path: path)), at: SourceLocation(pathStartIndex..<currentIndex, source: state.entireSource))
                }
                let term = Term(.resource, .res("as:\(path)"), name: name, resource: .applescriptAtPath(path: path, script: applescript))
                try state.cache.dictionaryCache.loadResourceDictionary(for: term)
                return term
            }
        }()
        state.lexicon.add(resourceTerm)
        return .require(resource: resourceTerm)
    }
    
    public func handleUse() throws -> Expression.Kind? {
        .use(module: try parsePrimaryOrThrow())
    }
    
    public func handleReturn() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        return .return_(state.source.first?.isNewline ?? true ? nil : try parsePrimary())
    }
    
    public func handleRaise() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        
        guard let error = try parsePrimary() else {
            throw ParseError(.missing([.expression]), at: currentLocation)
        }
        return .raise(error)
    }
    
    public func handleThat() throws -> Expression.Kind? {
        .that
    }
    
    public func handleIt() throws -> Expression.Kind? {
        .it
    }
    
    public func handleMissing() throws -> Expression.Kind? {
        .missing
    }
    
    public func handleUnspecified() throws -> Expression.Kind? {
        .unspecified
    }
    
    public func handleRef() throws -> Expression.Kind? {
        guard let expression = try parsePrimary() else {
            throw ParseError(.missing([.expression]), at: currentLocation)
        }
        return .reference(to: expression)
    }
    
    public func handleGet() throws -> Expression.Kind? {
        guard let expression = try self.parsePrimary() else {
            throw ParseError(.missing([.expression]), at: currentLocation)
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
        let inspection = state.lexicon.debugDescription
        printDebugMessage(inspection)
        return .debugInspectLexicon(message: inspection)
    }
    
    private func printDebugMessage(_ message: String) {
        os_log("%@:\n%@", log: log, String(state.entireSource[expressionLocation.range]), message)
    }
    
}
    
// MARK: Primary and sequence parsing
extension SourceParser {
    
    public func parseSequence(stoppingAt endKeywords: [Term.Name] = []) throws -> Expression {
        let endKeywords = endKeywords + [config.defaultEndKeyword]
        
        state.sequenceNestingLevel += 1
        defer {
            state.sequenceNestingLevel -= 1
        }
        
        var expressions: [Expression] = []
        
        @discardableResult
        func addIndentation(_ level: Int) -> SourceElement {
            withCurrentIndex { startIndex in
                eatCommentsAndWhitespace()
                
                let loc = SourceLocation(at: location(from: startIndex))
                let element = SourceElement(Indentation(level: level >= 0 ? level : 0, location: loc))
                state.elements.insert(element)
                return element
            }
        }
        func eatEndKeyword() -> Bool {
            if let endKeyword = endKeywords.first(where: { tryEating($0) }) {
                state.lastEndKeyword = endKeyword
                return true
            }
            return false
        }
        
        while true {
            let indentation = addIndentation(state.sequenceNestingLevel)
            if state.source.isEmpty || eatEndKeyword() {
                state.elements.remove(indentation)
                state.elements.insert(SourceElement(Indentation(level: state.sequenceNestingLevel > 0 ? state.sequenceNestingLevel - 1 : 0, location: indentation.location)))
                break
            }
            if let primary = try parsePrimary() {
                expressions.append(primary)
            }
            guard tryEatingLineBreak() || state.source.isEmpty else {
                let nextNewline = state.source.firstIndex(where: { $0.isNewline }) ?? state.source.endIndex
                let location = SourceLocation(state.source.startIndex..<nextNewline, source: state.entireSource)
                throw ParseError(.missing([.lineBreak], .afterSequencedExpression), at: location)
            }
        }
        
        defer {
            eatCommentsAndWhitespace()
        }
        return Expression(.sequence(expressions), at: expressionLocation)
    }
    
    public func parsePrimaryOrThrow(_ context: ParseError.Error.Context? = nil, allowSuffixSpecifier: Bool = true) throws -> Expression {
        guard let expression = try parsePrimary(allowSuffixSpecifier: allowSuffixSpecifier) else {
            throw ParseError(.missing([.expression], context), at: currentLocation)
        }
        return expression
    }
    public func parsePrimary(lastOperation: BinaryOperation? = nil, allowSuffixSpecifier: Bool = true) throws -> Expression? {
        state.expressionStartIndices.append(currentIndex)
        state.allowSuffixSpecifierStack.append(allowSuffixSpecifier)
        defer {
            eatCommentsAndWhitespace()
            state.allowSuffixSpecifierStack.removeLast()
            state.expressionStartIndices.removeLast()
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
        
        if !(state.allowSuffixSpecifierStack.last!), findSuffixSpecifierMarker() != nil {
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
            
            state.source.removeLeadingWhitespace()
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
        
        if state.source.first?.isNewline ?? true {
            return Expression(.empty, at: expressionLocation)
        } else if let bihash = try eatBihash() {
            var body = ""
            
            while !state.source.isEmpty {
                addingElement(.string, spacing: .none) {
                    state.source.removeLeadingWhitespace()
                    // Remove leading newline
                    if state.source.first?.isNewline ?? false {
                        _ = state.source.removeFirst()
                    }
                }
                
                let rollbackSource = state.source // Preserve leading whitespace
                let rollbackElements = state.elements
                if let _ = try eatBihash(delimiter: bihash.delimiter) {
                    break
                } else {
                    state.source = rollbackSource
                    state.elements = rollbackElements
                    let line = String(state.source.prefix { !$0.isNewline })
                    body += "\(line)\n"
                    addingElement(.string, spacing: .none) {
                        state.source.removeFirst(line.count)
                    }
                }
            }
            
            return Expression(.multilineString(bihash: bihash, body: body), at: expressionLocation)
        } else if let hashbang = eatHashbang() {
            var hashbangs = [hashbang]
            var endHashbangLocation: SourceLocation?
            var bodies = [""]
            
            while !state.source.isEmpty {
                addingElement(.weave, spacing: .none) {
                    _ = state.source.removeFirst() // Eat leading newline
                }
                
                let rollbackSource = state.source // Preserve leading whitespace
                let rollbackElements = state.elements
                if let newHashbang = eatHashbang() {
                    hashbangs.append(newHashbang)
                    bodies.append("")
                    if newHashbang.invocation.allSatisfy({ $0.isWhitespace }) {
                        endHashbangLocation = newHashbang.location
                        break
                    }
                } else {
                    state.source = rollbackSource
                    state.elements = rollbackElements
                    let line = String(state.source.prefix { !$0.isNewline })
                    bodies[bodies.index(before: bodies.endIndex)] += "\(line)\n"
                    addingElement(.weave, spacing: .none) {
                        state.source.removeFirst(line.count)
                    }
                }
            }
            
            let weaves = zip(hashbangs.indices, bodies).map { (pair: (Int, String)) -> Expression in
                let (hashbangIndex, body) = pair
                let hashbang = hashbangs[hashbangIndex]
                
                if hashbangs.indices.contains(hashbangIndex + 1) {
                    let nextHashbang = hashbangs[hashbangIndex + 1]
                    return Expression(.weave(hashbang: hashbang, body: body), at: SourceLocation(hashbang.location.range.lowerBound..<nextHashbang.location.range.lowerBound, source: state.entireSource))
                } else if let endLocation = endHashbangLocation {
                    // Program continues after an empty #! at endLocation
                    return Expression(.weave(hashbang: hashbang, body: body), at: endLocation)
                } else {
                    // Program ends in a weave
                    return Expression(.weave(hashbang: hashbang, body: body), at: SourceLocation(hashbang.location.range.lowerBound..<currentIndex, source: state.entireSource))
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
                            let escSequenceStartIndex = state.entireSource.index(expressionStartIndex, offsetBy: startMarker.normalized.count + escSequenceOffset - 1)
                            throw ParseError(.invalidString, at: SourceLocation(escSequenceStartIndex..<state.entireSource.index(escSequenceStartIndex, offsetBy: 2), source: state.entireSource))
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
            if let kind = try config.keywords[termName]!() {
                return Expression(kind, at: expressionLocation)
            } else {
                return nil
            }
        } else if let term = try eatTerm() {
            if let kind: Expression.Kind = try ({
                switch term.role {
                case .constant: // MARK: .constant
                    return .enumerator(term)
                case .type: // MARK: .type
                    return try handleType(term)
                case .property: // MARK: .property
                    return .specifier(Specifier(term: term, kind: .property))
                case .command: // MARK: .command
                    return try handleCommand(term)
                case .parameter: // MARK: .parameter
                    throw ParseError(.wrongTermRoleForContext, at: expressionLocation)
                case .variable: // MARK: .variable
                    return .variable(term)
                case .resource: // MARK: .resource
                    return .resource(term)
                }
            }()) {
                return Expression(kind, at: expressionLocation)
            } else {
                return nil
            }
        } else if
            let endKeyword = state.awaitingExpressionEndKeywords.last,
            endKeyword.contains(where: isNext)
        {
            // Allow outer awaiting() call to eat.
            return nil
        } else if let integer = try parseInteger() {
            return integer
        } else if let double = try parseDouble() {
            return double
        } else {
            os_log("Undefined term: %@", log: log, type: .debug, String(state.source))
            throw ParseError(.undefinedTerm, at: SourceLocation(currentIndex..<(state.source.firstIndex(where: { $0.isNewline }) ?? state.source.endIndex), source: state.entireSource))
        }
    }
    
}

private let integerRegex = Regex("^[-+]?\\d++(?!\\.)")
private let doubleRegex = Regex("^[-+]?\\d*(?:\\.\\d++(?:[ep][-+]?\\d+)?)?", options: .ignoreCase)

// MARK: Parse helpers
extension SourceParser {
    
    public func parseInteger() throws -> Expression? {
        let rollbackSource = state.source
        let rollbackElements = state.elements
        guard
            let match = tryEating(integerRegex, .number),
            let value = Int64(match.matchedString)
        else {
            state.source = rollbackSource
            state.elements = rollbackElements
            return nil
        }
        return Expression(.integer(value), at: expressionLocation)
    }
    
    public func parseDouble() throws -> Expression? {
        let rollbackSource = state.source
        let rollbackElements = state.elements
        guard
            let match = tryEating(doubleRegex, .number),
            let value = Double(match.matchedString)
        else {
            state.source = rollbackSource
            state.elements = rollbackElements
            return nil
        }
        return Expression(.double(value), at: expressionLocation)
    }
    
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
        return Term(.variable, state.lexicon.makeIDURI(forName: termName), name: termName)
    }
    
    public func parseTermNameEagerlyOrThrow(stoppingAt: [String] = [], styling: Styling = .keyword, _ context: ParseError.Error.Context? = nil) throws -> Term.Name {
        guard let name = try parseTermNameEagerly(stoppingAt: stoppingAt, styling: styling) else {
            throw ParseError(.missing([.termName], context), at: currentLocation)
        }
        return name
    }
    public func parseTermNameEagerly(stoppingAt: [String] = [], styling: Styling = .keyword) throws -> Term.Name? {
        let restOfLine = state.source.prefix { !$0.isNewline }
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
        state.termNameStartIndex = startIndex
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
        let restOfLine = state.source.prefix { !$0.isNewline }
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
                    state.termNameStartIndex = startIndex
                    return Term.Name(wordsWithoutPipes)
                }
            }
            throw ParseError(.mismatchedPipe, at: SourceLocation(state.termNameStartIndex..<state.source.startIndex, source: state.entireSource))
        } else {
            state.termNameStartIndex = startIndex
            return Term.Name(firstWord)
        }
    }
    
    public func eatTermRoleName() -> Term.SyntacticRole? {
        addingElement {
            eatCommentsAndWhitespace()
            guard let kindString = Term.Name.nextWord(in: state.source) else {
                return nil
            }
            state.source.removeFirst(kindString.count)
            return Term.SyntacticRole(rawValue: String(kindString))
        }
    }
    
    private func eatFromSource(_ words: [String], styling: Styling = .keyword) {
        for word in words {
            state.source.removeLeadingWhitespace()
            addingElement(styling) {
                state.source.removeFirst(word.count)
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
            state.source.removeLeadingWhitespace()
            
            let line = state.source[..<(state.source.firstIndex { $0.isNewline } ?? state.source.endIndex)]
            
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
        
        let invocationSource = state.source.prefix { !$0.isNewline }
        addingElement {
            state.source.removeFirst(invocationSource.count)
        }
        
        return Hashbang(String(invocationSource), at: expressionLocation)
    }
    
    private func eatLineCommentMarker() -> Bool {
        config.delimiters.lineComment.first { tryRemovingPrefix($0, withComments: false) } != nil
    }
    
    private func eatBlockCommentBeginMarker() -> Bool {
        config.delimiters.blockComment.first { tryRemovingPrefix($0.begin, withComments: false) } != nil
    }
    
    private func eatBlockCommentEndMarker() -> Bool {
        config.delimiters.blockComment.first { tryRemovingPrefix($0.end, withComments: false) } != nil
    }
    
    private func eatKeyword() -> Term.Name? {
        let result = findComplexTermName(from: state.keywordsTraversalTable, in: state.source)
        guard let termName = result.termName else {
            return nil
        }
        addingElement(spacing: termName.normalized.last!.isWordBreaking ? .left : .leftRight) {
            state.source.removeFirst(result.termString.count)
        }
        return termName
    }
    
    private func findPrefixOperator() -> (termName: Term.Name, operator: UnaryOperation)? {
        let result = findComplexTermName(from: state.prefixOperatorsTraversalTable, in: state.source)
        return result.termName.map { name in
            (termName: name, operator: config.operators.prefix[name]!)
        }
    }
    
    private func eatPrefixOperator() {
        let result = findComplexTermName(from: state.prefixOperatorsTraversalTable, in: state.source)
        guard result.termName != nil else {
            return
        }
        addingElement(.operator) {
            state.source.removeFirst(result.termString.count)
        }
        eatCommentsAndWhitespace()
    }
    
    private func eatPostfixOperator() -> (termName: Term.Name, operator: UnaryOperation)? {
        let result = findComplexTermName(from: state.postfixOperatorsTraversalTable, in: state.source)
        guard result.termName != nil else {
            return nil
        }
        addingElement(.operator) {
            state.source.removeFirst(result.termString.count)
        }
        return result.termName.map { termName in
            (termName: termName, operator: config.operators.postfix[termName]!)
        }
    }
    
    private func findBinaryOperator() -> (termName: Term.Name, operator: BinaryOperation)? {
        let result = findComplexTermName(from: state.binaryOperatorsTraversalTable, in: state.source)
        return result.termName.map { name in
            (termName: name, operator: config.operators.infix[name]!)
        }
    }
    
    private func eatBinaryOperator() {
        let result = findComplexTermName(from: state.binaryOperatorsTraversalTable, in: state.source)
        guard result.termName != nil else {
            return
        }
        addingElement(.operator) {
            state.source.removeFirst(result.termString.count)
        }
        eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true)
    }
    
    private func findSuffixSpecifierMarker() -> Term.Name? {
        config.delimiters.suffixSpecifier.first { isNext($0) }
    }
    
    public func eatSuffixSpecifierMarker() -> Term.Name? {
        config.delimiters.suffixSpecifier.first { tryEating($0) }
    }
    
    private func eatStringBeginMarker() -> (begin: Term.Name, end: Term.Name)? {
        config.delimiters.string.first { tryEating($0.begin, .string, spacing: .left) }
    }
    
    private func eatExpressionGroupingBeginMarker() -> (begin: Term.Name, end: Term.Name)? {
        config.delimiters.expressionGrouping.first { tryEating($0.begin, spacing: .left) }
    }
    
    private func eatListBeginMarker() -> (begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name])? {
        config.delimiters.list.first { tryEating($0.begin, spacing: .left) }
    }
    
    private func eatRecordBeginMarker() -> (begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])? {
        config.delimiters.record.first { tryEating($0.begin, spacing: .left) }
    }
    
    private func eatListAndRecordBeginMarker() -> (begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])? {
        config.delimiters.listAndRecord.first { tryEating($0.begin, spacing: .left) }
    }
    
}

private let lineBreakRegex = Regex("\r?\n|\r")

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
        tryEating(lineBreakRegex) != nil
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
        let restOfSource = String(state.source)
        guard
            let match = regex.firstMatch(in: restOfSource),
            match.range.lowerBound == restOfSource.startIndex
        else {
            return nil
        }
        
        addingElement(styling, spacing: spacing) {
            state.source.removeFirst(match.matchedString.count)
        }
        
        return match
    }
    
    public func tryRemovingPrefix(_ termName: Term.Name, withComments: Bool = true) -> Bool {
        let rollbackSource = state.source
        for word in termName.words {
            guard tryRemovingPrefix(word, withComments: withComments) else {
                state.source = rollbackSource
                return false
            }
        }
        return true
    }
    
    public func tryRemovingPrefix(_ prefix: String, withComments: Bool = true) -> Bool {
        if withComments {
            eatCommentsAndWhitespace()
        } else {
            state.source.removeLeadingWhitespace()
        }
        guard isNext(prefix) else {
            return false
        }
        
        state.source.removeFirst(prefix.count)
        return true
    }
    
    public func isNext(_ termName: Term.Name) -> Bool {
        var source = self.state.source
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
        Self.isNext(prefix, source: state.source)
    }
    
    public static func isNext(_ prefix: String, source: Substring) -> Bool {
        source.hasPrefix(prefix) &&
            (prefix.last!.isWordBreaking || (source.dropFirst(prefix.count).first?.isWordBreaking ?? true))
    }
    
    public func awaiting<Result>(endMarkers: Set<Term.Name>, perform action: () throws -> Result) rethrows -> Result {
        state.awaitingExpressionEndKeywords.append(endMarkers)
        defer {
            state.awaitingExpressionEndKeywords.removeLast()
        }
        return try action()
    }
    
    public func awaiting<Result>(endMarker: Term.Name, perform action: () throws -> Result) rethrows -> Result {
        try awaiting(endMarkers: [endMarker], perform: action)
    }
    
    public func withScope(parse: () throws -> Expression) rethrows -> Expression {
        state.lexicon.pushUnnamedDictionary()
        defer { state.lexicon.pop() }
        return Expression(.scoped(try parse()), at: expressionLocation)
    }
    
    public func withTerminology<Result>(of term: Term, parse: () throws -> Result) throws -> Result {
        state.lexicon.push(term)
        defer {
            state.lexicon.pop()
        }
        
        return try parse()
    }
    
    public func withTerminology<Result>(of expression: Expression, parse: () throws -> Result) throws -> Result {
        if let term = expression.principalTerm() {
            return try withTerminology(of: term, parse: parse)
        } else {
            return try parse()
        }
    }
    
    public var currentLocation: SourceLocation {
        SourceLocation(at: currentIndex, source: state.entireSource)
    }
    
    public var currentIndex: String.Index {
        state.source.startIndex
    }
    
    public var expressionLocation: SourceLocation {
        location(from: expressionStartIndex)
    }
    
    public var expressionStartIndex: String.Index {
        state.expressionStartIndices.last ?? state.entireSource.startIndex
    }
    
    public var termNameLocation: SourceLocation {
        location(from: state.termNameStartIndex)
    }
    
    private func withCurrentIndex<Result>(parse: (String.Index) throws -> Result) rethrows -> Result {
        try parse(currentIndex)
    }
    
    private func location(from index: String.Index) -> SourceLocation {
        SourceLocation(index..<currentIndex, source: state.entireSource)
    }
    
    public func eatTermOrThrow(_ context: ParseError.Error.Context? = nil) throws -> Term {
        guard let term = try eatTerm() else {
            throw ParseError(.missing([.term()], context), at: currentLocation)
        }
        return term
    }
    public func eatTerm() throws -> Term? {
        try eatTerm(from: state.lexicon)
    }
    
    public func eatTerm<Terminology: ByNameTermLookup>(from dictionary: Terminology, role: Term.SyntacticRole? = nil) throws -> Term? {
        func eatDefinedTerm() throws -> Term? {
            func findTerm<Terminology: ByNameTermLookup>(in dictionary: Terminology) throws -> (termString: Substring, term: Term)? {
                eatCommentsAndWhitespace()
                
                let restOfLine = state.source.prefix(while: { !$0.isNewline })
                
                if state.source.hasPrefix("|") {
                    guard let nextPipeIndex = restOfLine.dropFirst().firstIndex(where: { $0 == "|" }) else {
                        throw ParseError(.mismatchedPipe, at: expressionLocation)
                    }
                    let termString = restOfLine[...nextPipeIndex]
                    let termName = Term.Name(String(termString.dropFirst().dropLast()))
                    guard let term = dictionary.term(named: termName) else {
                        return nil
                    }
                    return (termString, term)
                } else {
                    var termString = restOfLine.prefix { !$0.isWordBreaking || $0.isWhitespace || $0 == ":" }
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
            }
            
             guard var (termString, term) = try findTerm(in: dictionary) else {
                return nil
            }
            guard role == nil || term.role == role else {
                return nil
            }
            addingElement(Styling(for: term.role)) {
                state.source.removeFirst(termString.count)
            }
            if role == nil {
                var sourceWithSlash: Substring = state.source
                while tryEating(prefix: "/") {
                    // For explicit term specification lhs / rhs,
                    // only eat the slash if rhs is the name of a term defined
                    // in the dictionary of lhs.
                    guard let result = try findTerm(in: term.dictionary) else {
                        // Restore the slash. It may have come from some other construct.
                        state.source = sourceWithSlash
                        
                        return term
                    }
                    
                    // Eat rhs.
                    (termString, term) = result
                    addingElement(Styling(for: term.role)) {
                        state.source.removeFirst(termString.count)
                    }
                    eatCommentsAndWhitespace()
                    
                    // We're committed to this slash forming an explicit specification
                    sourceWithSlash = state.source
                }
            }
            return term
            
        }
        func eatRawFormTerm() throws -> Term? {
            return try withCurrentIndex { startIndex in
                guard tryEating(prefix: "#", spacing: .left) else {
                    return nil
                }
                
                eatCommentsAndWhitespace()
                
                guard let role = eatTermRoleName() else {
                    throw ParseError(.invalidTermRole, at: currentLocation)
                }
                
                eatCommentsAndWhitespace()
                
                let uri = try eatTermURI(Styling(for: role)) ?? state.lexicon.makeUniqueURI()
                
                let term = state.lexicon.term(id: Term.ID(role, uri)) ?? Term(role, uri)
                
                return term
            }
        }
        
        return try eatDefinedTerm() ?? eatRawFormTerm()
    }
    
    public func eatTermURI(_ styling: Styling) throws -> Term.SemanticURI? {
        let start = "[", stop = "]"
        guard tryEating(prefix: start, spacing: .left) else {
            return nil
        }
        let uri: Term.SemanticURI = try {
            if tryEating(prefix: "direct") {
                return Term.SemanticURI(Parameters.direct)
            } else if tryEating(prefix: "target") {
                return Term.SemanticURI(Parameters.target)
            } else {
                guard let stopRange = state.source.range(of: stop) else {
                    throw ParseError(.missing([.termURIEndMarker]), at: currentLocation)
                }
                let uriString = state.source[..<stopRange.lowerBound]
                guard let uri = Term.SemanticURI(normalized: String(uriString)) else {
                    throw ParseError(.missing([.termURI]), at: currentLocation)
                }
                addingElement(styling) {
                    state.source = state.source[stopRange.lowerBound...]
                }
                return uri
            }
        }()
        try eatOrThrow(prefix: stop, spacing: .right)
        return uri
    }
    
    public func eatCommentsAndWhitespaceToEndOfLine() -> Bool {
        eatCommentsAndWhitespace()
        return atEndOfLine
    }
    
    public var atEndOfLine: Bool {
        return state.source.first?.isNewline ?? true
    }
    
    public func eatCommentsAndWhitespace(eatingNewlines: Bool = false, isSignificant: Bool = false) {
        func eatLineComment() -> Bool {
            guard eatLineCommentMarker() else {
                return false
            }
            state.source.removeFirst(while: { !$0.isNewline })
            return true
        }
        func eatBlockComment() -> Bool {
            func awaitEndMarker() {
                while !eatBlockCommentEndMarker(), !state.source.isEmpty {
                    if eatBlockCommentBeginMarker() {
                        // Handle nested comments au façon Swift
                        /* e.g., /* must end twice */ */
                        awaitEndMarker()
                    }
                    if !state.source.isEmpty {
                        state.source.removeFirst()
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
            state.elements.insert(SourceElement(Terminal(String(state.entireSource[startIndex..<currentIndex]), at: location(from: startIndex), styling: .comment)))
        }
        
        withCurrentIndex { startIndex in
            state.source.removeLeadingWhitespace(removingNewlines: eatingNewlines)
            
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
                    state.source.removeLeadingWhitespace(removingNewlines: eatingNewlines)
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
        
        let slice = String(state.entireSource[startIndex..<currentIndex])
        let loc = location(from: startIndex)
        state.elements.insert(SourceElement(Terminal(slice, at: loc, spacing: spacing, styling: styling)))
    }
    
}

extension Styling {
    
    public init(for role: Term.SyntacticRole) {
        self = {
            switch role {
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
        }()
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

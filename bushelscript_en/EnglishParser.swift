import Bushel
import Regex

public final class EnglishParser: SourceParser {
    
    public static var sdefCache: [URL : Data] = [:]
    
    public let messageFormatter: MessageFormatter = EnglishMessageFormatter()
    
    public var entireSource: String = ""
    public lazy var source: Substring = Substring(entireSource)
    public var expressionStartIndices: [String.Index] = []
    public lazy var termNameStartIndex: String.Index = entireSource.startIndex
    
    public var lexicon: Lexicon = Lexicon()
    public var sequenceNestingLevel: Int = 0
    public var elements: Set<SourceElement> = []
    public var awaitingExpressionEndKeywords: [Set<Term.Name>] = []
    public var endExpression: Bool = false
    
    public var keywordsTraversalTable: TermNameTraversalTable = [:]
    public var prefixOperatorsTraversalTable: TermNameTraversalTable = [:]
    public var postfixOperatorsTraversalTable: TermNameTraversalTable = [:]
    public var binaryOperatorsTraversalTable: TermNameTraversalTable = [:]
    
    public var nativeImports: Set<URL> = []
    
    public init() {
    }
    
    public let prefixOperators: [Term.Name : UnaryOperation] = [
        Term.Name("not"): .not
    ]
    
    public let postfixOperators: [Term.Name : UnaryOperation] = [:]
    
    public let binaryOperators: [Term.Name : BinaryOperation] = [
        Term.Name("or"): .or,
        Term.Name("xor"): .xor,
        Term.Name("and"): .and,
        Term.Name("is a"): .isA,
        Term.Name("is an"): .isA,
        Term.Name("is not a"): .isNotA,
        Term.Name("is not an"): .isNotA,
        Term.Name("isn't a"): .isNotA,
        Term.Name("isn’t a"): .isNotA,
        Term.Name("isn't an"): .isNotA,
        Term.Name("isn’t an"): .isNotA,
        Term.Name("equals"): .equal,
        Term.Name("equal to"): .equal,
        Term.Name("equals to"): .equal,
        Term.Name("is equal to"): .equal,
        Term.Name("is"): .equal,
        Term.Name("="): .equal,
        Term.Name("=="): .equal,
        Term.Name("not equal to"): .notEqual,
        Term.Name("is not equal to"): .notEqual,
        Term.Name("isn't equal to"): .notEqual,
        Term.Name("isn’t equal to"): .notEqual,
        Term.Name("unequal to"): .notEqual,
        Term.Name("is unequal to"): .notEqual,
        Term.Name("is not"): .notEqual,
        Term.Name("isn't"): .notEqual,
        Term.Name("isn’t"): .notEqual,
        Term.Name("not ="): .notEqual,
        Term.Name("!="): .notEqual,
        Term.Name("≠"): .notEqual,
        Term.Name("less than"): .less,
        Term.Name("is less than"): .less,
        Term.Name("<"): .less,
        Term.Name("less than equal to"): .lessEqual,
        Term.Name("less than or equals"): .lessEqual,
        Term.Name("less than or equal to"): .lessEqual,
        Term.Name("is less than equal to"): .lessEqual,
        Term.Name("is less than or equals"): .lessEqual,
        Term.Name("is less than or equal to"): .lessEqual,
        Term.Name("<="): .lessEqual,
        Term.Name("≤"): .lessEqual,
        Term.Name("greater than"): .greater,
        Term.Name("is greater than"): .greater,
        Term.Name(">"): .greater,
        Term.Name("greater than equal to"): .greaterEqual,
        Term.Name("greater than or equals"): .greaterEqual,
        Term.Name("greater than or equal to"): .greaterEqual,
        Term.Name("is greater than equal to"): .greaterEqual,
        Term.Name("is greater than or equals"): .greaterEqual,
        Term.Name("is greater than or equal to"): .greaterEqual,
        Term.Name(">="): .greaterEqual,
        Term.Name("≥"): .greaterEqual,
        Term.Name("starts with"): .startsWith,
        Term.Name("begins with"): .startsWith,
        Term.Name("ends with"): .endsWith,
        Term.Name("contains"): .contains,
        Term.Name("has"): .contains,
        Term.Name("does not contain"): .notContains,
        Term.Name("doesn't contain"): .notContains,
        Term.Name("doesn’t contain"): .notContains,
        Term.Name("does not have"): .notContains,
        Term.Name("doesn't have"): .notContains,
        Term.Name("doesn’t have"): .notContains,
        Term.Name("is in"): .containedBy,
        Term.Name("is contained by"): .containedBy,
        Term.Name("is not in"): .notContainedBy,
        Term.Name("isn't in"): .notContainedBy,
        Term.Name("isn’t in"): .notContainedBy,
        Term.Name("is not contained by"): .notContainedBy,
        Term.Name("isn't contained by"): .notContainedBy,
        Term.Name("isn’t contained by"): .notContainedBy,
        Term.Name("&"): .concatenate,
        Term.Name("+"): .add,
        Term.Name("-"): .subtract,
        Term.Name("−"): .subtract,
        Term.Name("*"): .multiply,
        Term.Name("×"): .multiply,
        Term.Name("/"): .divide,
        Term.Name("÷"): .divide,
        Term.Name("as"): .coerce,
    ]
    
    public let stringMarkers: [(begin: Term.Name, end: Term.Name)] = [
        (begin: Term.Name("\""), end: Term.Name("\"")),
        (begin: Term.Name("“"), end: Term.Name("”"))
    ]
    
    public let expressionGroupingMarkers: [(begin: Term.Name, end: Term.Name)] = [
        (begin: Term.Name("("), end: Term.Name(")"))
    ]
    
    public let listMarkers: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name])] = []
    
    public let recordMarkers: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])] = []
    
    public let listAndRecordMarkers: [(begin: Term.Name, end: Term.Name, itemSeparators: [Term.Name], keyValueSeparators: [Term.Name])] = [
        (begin: Term.Name("{"), end: Term.Name("}"), itemSeparators: [Term.Name(",")], keyValueSeparators: [Term.Name(":")])
    ]
    
    public let lineCommentMarkers: [Term.Name] = [
        Term.Name("--")
    ]
    
    public let blockCommentMarkers: [(begin: Term.Name, end: Term.Name)] = [
        (begin: Term.Name("--("), end: Term.Name(")--"))
    ]
    
    public lazy var keywords: [Term.Name : KeywordHandler] = [
        Term.Name("end"): handleEnd,
        Term.Name("on"): handleFunctionStart,
        Term.Name("to"): handleFunctionStart,
        Term.Name("try"): handleTry,
        Term.Name("if"): handleIf,
        Term.Name("repeat"): handleRepeat(Term.Name("repeat")),
        Term.Name("repeating"): handleRepeat(Term.Name("repeating")),
        Term.Name("tell"): handleTell,
        Term.Name("let"): handleLet,
        Term.Name("define"): handleDefine,
        Term.Name("defining"): handleDefining,
        Term.Name("return"): handleReturn,
        Term.Name("raise"): handleRaise(Term.Name("raise")),
        Term.Name("use"): handleUse,
        Term.Name("that"): handleThat,
        Term.Name("it"): handleIt,
        Term.Name("null"): handleNull,
        Term.Name("every"): handleQuantifier(.all),
        Term.Name("all"): handleQuantifier(.all),
        Term.Name("first"): handleQuantifier(.first),
        Term.Name("front"): handleQuantifier(.first),
        Term.Name("middle"): handleQuantifier(.middle),
        Term.Name("last"): handleQuantifier(.last),
        Term.Name("back"): handleQuantifier(.last),
        Term.Name("some"): handleQuantifier(.random),
        Term.Name("first position of"): handleInsertionLocation(.beginning),
        Term.Name("first position"): handleInsertionLocation(.beginning),
        Term.Name("last position of"): handleInsertionLocation(.end),
        Term.Name("last position"): handleInsertionLocation(.end),
        Term.Name("position before"): handleInsertionLocation(.before),
        Term.Name("position after"): handleInsertionLocation(.after),
        Term.Name("ref"): handleRef(Term.Name("ref")),
        Term.Name("get"): handleGet(Term.Name("get")),
        Term.Name("set"): handleSet,
    ]
    
    public lazy var resourceTypes: [Term.Name : (hasName: Bool, stoppingAt: [String], handler: ResourceTypeHandler)] = [
        Term.Name("system"): (false, [], handleUseSystem),
        
        Term.Name("app"): (true, [], handleUseApplicationName),
        Term.Name("app id"): (true, [], handleUseApplicationID),
        
        Term.Name("library"): (true, [], handleUseLibrary),
        
        Term.Name("AppleScript"): (true, ["at"], handleUseAppleScript),
    ]
    
    private func handleFunctionStart() throws -> Expression.Kind? {
        guard let termName = try parseTermNameEagerly(stoppingAt: [":"]) else {
            throw AdHocParseError("expected function name", at: SourceLocation(source.range, source: entireSource))
        }
        let functionNameTerm = Term(.variable, lexicon.makeURI(forName: termName), name: termName)
        
        var parameters: [Term] = []
        var arguments: [Term] = []
        if tryEating(prefix: ":", spacing: .right) {
            while let parameterTermName = try parseTermNameLazily() {
                parameters.append(Term(.parameter, .id(Term.SemanticURI.Pathname([parameterTermName.normalized])), name: parameterTermName))
                
                var argumentName = try parseTermNameEagerly(stoppingAt: [","]) ?? parameterTermName
                if argumentName.words.isEmpty {
                    argumentName = parameterTermName
                }
                arguments.append(Term(.variable, .id(Term.SemanticURI.Pathname([argumentName.normalized])), name: argumentName))
                
                if !tryEating(prefix: ",", spacing: .right) {
                    break
                }
            }
        }
        
        let commandTerm = Term(.command, lexicon.makeURI(forName: termName), name: termName, parameters: ParameterTermDictionary(contents: parameters))
        lexicon.add(commandTerm)
        
        guard tryEating(prefix: "\n") else {
            throw AdHocParseError("expected line break to begin function body", at: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation)])
        }
        let body = try withScope {
            lexicon.add(Set(arguments))
            lexicon.add(Term(Term.ID(Dictionaries.function), name: Term.Name("function"), dictionary: lexicon.stack.last!.makeDictionary(under: lexicon.pool)))
            return try parseSequence()
        }
        
        return .function(name: functionNameTerm, parameters: parameters, arguments: arguments, body: body)
    }
    
    private func handleTry() throws -> Expression.Kind? {
        func parseBody() throws -> Expression {
            let foundNewline = tryEating(prefix: "\n")
            if foundNewline {
                return try parseSequence(stoppingAt: ["handle"])
            } else {
                guard let bodyExpression = try parsePrimary() else {
                    throw AdHocParseError("expected expression or line break after ‘try’", at: expressionLocation)
                }
                return bodyExpression
            }
        }
        
        func parseHandle() throws -> Expression {
            eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true)
            guard tryEating(prefix: "handle") else {
                throw AdHocParseError("expected ‘handle’ after ‘try’-block body to begin ‘handle’-block", at: currentLocation)
            }
            
            if tryEating(prefix: "\n") {
                return try parseSequence()
            } else {
                guard let handleExpression = try parsePrimary() else {
                    throw AdHocParseError("expected expression or line break after ‘handle’", at: currentLocation)
                }
                eatCommentsAndWhitespace()
                return handleExpression
            }
        }
        
        return .try_(body: try parseBody(), handle: try parseHandle())
    }
    
    private func handleIf() throws -> Expression.Kind? {
        guard let condition = try parsePrimary() else {
            throw AdHocParseError("expected condition expression after ‘if’", at: currentLocation)
        }
        
        func parseThen() throws -> Expression {
            let thenStartIndex = currentIndex
            let foundThen = tryEating(prefix: "then")
            let foundNewline = tryEating(prefix: "\n")
            guard foundThen || foundNewline else {
                throw AdHocParseError("expected ‘then’ or line break after condition expression to begin ‘if’-block", at: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation), AppendingFix(appending: " then", at: currentLocation)])
            }
            
            if foundNewline {
                return try parseSequence(stoppingAt: ["else"])
            } else {
                guard let thenExpression = try parsePrimary() else {
                    let thenLocation = SourceLocation(thenStartIndex..<currentIndex, source: entireSource)
                    throw AdHocParseError("expected expression or line break after ‘then’ to begin ‘if’-block", at: thenLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it when the condition is true", at: [currentLocation]), SuggestingFix(suggesting: "{FIX} to evaluate a sequence of expressions when the condition is true", by: AppendingFix(appending: "\n", at: thenLocation))])
                }
                return thenExpression
            }
        }

        func parseElse() throws -> Expression? {
            let rollbackSource = source
            let rollbackElements = elements
            eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true)
            
            let elseStartIndex = currentIndex
            guard tryEating(prefix: "else") else {
                source = rollbackSource
                elements = rollbackElements
                return nil
            }
            
            if tryEating(prefix: "\n") {
                return try parseSequence()
            } else {
                guard let elseExpr = try parsePrimary() else {
                    let elseLocation = SourceLocation(elseStartIndex..<currentIndex, source: entireSource)
                    throw AdHocParseError("expected expression or line break after ‘else’ to begin ‘else’-block", at: elseLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it when the condition is true", by: AppendingFix(appending: " <#expression#>", at: currentLocation)), SuggestingFix(suggesting: "{FIX} to evaluate a sequence of expressions when the condition is true", by: AppendingFix(appending: "\n", at: elseLocation))])
                }
                
                eatCommentsAndWhitespace()
                
                return elseExpr
            }
        }
        
        return .if_(condition: condition, then: try parseThen(), else: try parseElse())
    }
    
    private func handleRepeat(_ keyword: Term.Name) -> () throws -> Expression.Kind? {
        { [weak self] in
            try self?.handleRepeat(keyword)
        }
    }
    
    private func handleRepeat(_ keyword: Term.Name) throws -> Expression.Kind? {
        func parseRepeatBlock() throws -> Expression {
            guard tryEating(prefix: "\n") else {
                throw AdHocParseError("expected line break to begin repeat block", at: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation)])
            }
            return try parseSequence()
        }
        
        if tryEating(prefix: "while") {
            guard let condition = try parsePrimary() else {
                throw AdHocParseError("expected condition expression after ‘\(keyword) while’", at: currentLocation)
            }
            
            return .repeatWhile(condition: condition, repeating: try parseRepeatBlock())
        } else if tryEating(prefix: "for") {
            guard let variableTerm = try parseVariableTerm(stoppingAt: ["in"]) else {
                throw AdHocParseError("expected variable name after ‘repeat for’", at: currentLocation)
            }
            
            guard tryEating(prefix: "in") else {
                throw AdHocParseError("expected ‘in’ to begin container expression in ‘repeat for’", at: currentLocation)
            }
            
            guard let expression = try parsePrimary() else {
                throw AdHocParseError("expected container expression in ‘repeat for’", at: currentLocation)
            }
            
            lexicon.add(variableTerm)
            
            return .repeatFor(variable: variableTerm, container: expression, repeating: try parseRepeatBlock())
        } else {
            guard let times = try parsePrimary() else {
                throw AdHocParseError("expected times expression after ‘\(expressionLocation.snippet(in: entireSource))’", at: currentLocation)
            }
            
            guard tryEating(prefix: "times") else {
                throw AdHocParseError("expected ‘times’ after times expression", at: currentLocation, fixes: [AppendingFix(appending: " times", at: currentLocation)])
            }
            
            return .repeatTimes(times: times, repeating: try parseRepeatBlock())
        }
    }
    
    private func handleTell() throws -> Expression.Kind? {
        guard let target = try parsePrimary() else {
            throw AdHocParseError("expected target expression after ‘tell’", at: currentLocation)
        }
        
        let toStartIndex = currentIndex
        let foundTo = tryEating(prefix: "to")
        let foundNewline = tryEating(prefix: "\n")
        guard foundTo && !foundNewline || !foundTo && foundNewline else {
            throw AdHocParseError("expected ‘to’ or line break following target expression to begin ‘tell’-block", at: currentLocation, fixes: [SuggestingFix(suggesting: "{FIX} to evaluate a single targeted expression", by: AppendingFix(appending: " to", at: currentLocation)), SuggestingFix(suggesting: "{FIX} to evaluate a targeted sequence of expressions", by: AppendingFix(appending: "\n", at: currentLocation))])
        }
        
        return try withTerminology(of: target) {
            let toExpr: Expression
            if foundNewline {
                toExpr = try parseSequence()
            } else {
                guard let toExpression = try parsePrimary() else {
                    let toLocation = SourceLocation(toStartIndex..<currentIndex, source: entireSource)
                    throw AdHocParseError("expected expression after ‘to’ in ‘tell’-expression", at: toLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it with a new target", by: AppendingFix(appending: " <#expression#>", at: currentLocation))])
                }
                toExpr = toExpression
            }
            
            return .tell(target: target, to: toExpr)
        }
    }
    
    private func handleLet() throws -> Expression.Kind? {
        guard let term = try parseVariableTerm(stoppingAt: ["be"]) else {
            throw AdHocParseError("expected variable name after ‘let’", at: currentLocation)
        }
        
        var initialValue: Expression? = nil
        if tryEating(prefix: "be") {
            guard let value = try parsePrimary() else {
                throw AdHocParseError("expected initial value expression after ‘be’", at: currentLocation)
            }
            initialValue = value
        }
        
        lexicon.add(term)
        
        return .let_(term, initialValue: initialValue)
    }
    
    private func parseDefineLine() throws -> (term: Term, existingTerm: Term?) {
        guard let role = parseTermTypeName() else {
            throw AdHocParseError("expected term type", at: currentLocation)
        }
        
        guard let termName = try parseTermNameEagerly(stoppingAt: ["as"], styling: styling(for: role)) else {
            throw AdHocParseError("expected term name", at: currentLocation)
        }
        
        let existingTerm: Term? = try {
            guard tryEating(prefix: "as") else {
                return nil
            }
            guard let existingTerm = try eatTerm() else {
                throw AdHocParseError("expected a term", at: currentLocation)
            }
            return existingTerm
        }()
        
        let term = Term(role, existingTerm?.uri ?? lexicon.makeURI(forName: termName), name: termName)
        lexicon.add(term)
        
        return (term: term, existingTerm: existingTerm)
    }
    
    private func handleDefine() throws -> Expression.Kind? {
        let (term: term, existingTerm: existingTerm) = try parseDefineLine()
        return .define(term, as: existingTerm)
    }
    
    private func handleDefining() throws -> Expression.Kind? {
        let (term: term, existingTerm: existingTerm) = try parseDefineLine()
        let body = try withTerminology(of: term) {
            try parseSequence()
        }
        return .defining(term, as: existingTerm, body: body)
    }
    
    private func handleUseSystem(name _: Term.Name) throws -> Term {
        var system = Resource.System()
        if tryEating(prefix: "version") {
            eatCommentsAndWhitespace()
            guard let match = tryEating(Regex("[vV]?(\\d+)\\.(\\d+)(?:\\.(\\d+))?")) else {
                throw AdHocParseError("expected OS version number", at: currentLocation)
            }
            
            let versionComponents = match.captures.compactMap { $0.map { Int($0)! } }
            let majorVersion = versionComponents[0]
            let minorVersion = versionComponents[1]
            let patchVersion = versionComponents.indices.contains(2) ? versionComponents[2] : 0
            
            let version = OperatingSystemVersion(majorVersion: majorVersion, minorVersion: minorVersion, patchVersion: patchVersion)
            guard let resolved = Resource.System(version: version) else {
                throw ParseError(.unmetResourceRequirement(.system(version: match.matchedString)), at: termNameLocation)
            }
            
            system = resolved
        }
        
        // Term should be defined in translation files (we don't have a name
        // for it here).
        if let term = lexicon.pool.term(id: Term.ID(Variables.Core))!.makeDictionary(under: lexicon.pool).term(id: Term.ID(Resources.system)) {
            return term
        } else {
            // Resort to empty name.
            let term = Term(.resource, .res("system"), name: Term.Name([]), resource: system.enumerated())
            try term.loadDictionary(under: lexicon.pool)
            return term
        }
    }
    
    private func handleUseApplicationName(name: Term.Name) throws -> Term {
        guard let application = Resource.ApplicationByName(name: name.normalized) else {
            throw ParseError(.unmetResourceRequirement(.applicationByName(name: name.normalized)), at: termNameLocation)
        }
        
        let term = Term(.resource, .res("app:\(name)"), name: name, resource: application.enumerated())
        try term.loadDictionary(under: lexicon.pool)
        return term
    }
    
    private func handleUseApplicationID(name: Term.Name) throws -> Term {
        guard let application = Resource.ApplicationByID(id: name.normalized) else {
            throw ParseError(.unmetResourceRequirement(.applicationByBundleID(bundleID: name.normalized)), at: termNameLocation)
        }
        let term = Term(.resource, .res("appid:\(name)"), name: name, resource: application.enumerated())
        try term.loadDictionary(under: lexicon.pool)
        return term
    }
    
    private func handleUseLibrary(name: Term.Name) throws -> Term {
        guard let library = Resource.LibraryByName(name: name.normalized, ignoring: nativeImports) else {
            throw ParseError(.unmetResourceRequirement(.libraryByName(name: name.normalized)), at: termNameLocation)
        }
        nativeImports.insert(library.url)
        let term = Term(.resource, .res("library:\(name)"), name: name, resource: library.enumerated())
        try? term.loadDictionary(under: lexicon.pool)
        return term
    }
    
    private func handleUseAppleScript(name: Term.Name) throws -> Term {
        guard tryEating(prefix: "at") else {
            throw AdHocParseError("expected ‘at’ followed by path string", at: currentLocation)
        }
        
        let pathStartIndex = currentIndex
        guard var (_, path) = try parseString() else {
            throw AdHocParseError("expected path string", at: currentLocation)
        }
        
        path = (path as NSString).expandingTildeInPath
        
        guard let applescript = Resource.AppleScriptAtPath(path: path) else {
            throw ParseError(.unmetResourceRequirement(.applescriptAtPath(path: path)), at: SourceLocation(pathStartIndex..<currentIndex, source: entireSource))
        }
        let term = Term(.resource, .res("as:\(path)"), name: name, resource: applescript.enumerated())
        try? term.loadDictionary(under: lexicon.pool)
        return term
    }
    
    private func handleSet() throws -> Expression.Kind? {
        guard let destinationExpression = try parsePrimary() else {
            throw AdHocParseError("expected destination-expression after ‘set’", at: currentLocation)
        }
        guard tryEating(prefix: "to") else {
            throw AdHocParseError("expected ‘to’ after ‘set’ destination-expression to begin new-value-expression", at: currentLocation)
        }
        guard let newValueExpression = try parsePrimary() else {
            throw AdHocParseError("expected new-value-expression after ‘to’", at: currentLocation)
        }
        return .set(destinationExpression, to: newValueExpression)
    }
    
    private func handleQuantifier(_ kind: Specifier.Kind) -> () throws -> Expression.Kind? {
        {
            try self.parseSpecifierAfterQuantifier(kind: kind)
        }
    }
    
    private func handleInsertionLocation(_ kind: InsertionSpecifier.Kind) -> () throws -> Expression.Kind? {
        {
            try self.parseInsertionSpecifierAfterInsertionLocation(kind: kind)
        }
    }
    
    public func handle(term: Term) throws -> Expression.Kind? {
        switch term.role {
        case .constant: // MARK: .constant
            return .enumerator(term)
        case .dictionary: // MARK: .dictionary
            // TODO: Such purely organizational dictionaries should probably
            // have a runtime reflection type.
            return .null
        case .type: // MARK: .type
            if let specifierKind = try parseSpecifierAfterTypeName() {
                return .specifier(Specifier(term: term, kind: specifierKind))
            } else if let specifier = try parseRelativeSpecifierAfterTypeName(term) {
                return .specifier(specifier)
            } else {
                // Just the type name
                return .type(term)
            }
        case .property: // MARK: .property
            let specifier = Specifier(term: term, kind: .property)
            return .specifier(specifier)
        case .command: // MARK: .command
            var parameters: [(Term, Expression)] = []
            func parseParameter() throws -> Bool {
                guard
                    let parameterDict = term.parameters,
                    let parameterTerm = try eatTerm(terminology: parameterDict),
                    parameterTerm.role == .parameter
                else {
                    return false
                }
                
                guard let parameterValue = try parsePrimary() else {
                    throw AdHocParseError("expected expression after parameter name, but found end of script", at: currentLocation)
                }
                
                parameters.append((parameterTerm, parameterValue))
                return true
            }
            func result() -> Expression.Kind {
                return .command(term, parameters: parameters)
            }
            
            // First, try parsing a named parameter.
            // If that fails, check if we've reached the end of the line or
            // the end of the source code.
            // If neither of those succeed, then what's in front of us must be
            // a direct parameter (e.g, "open {file1, file2}").
            if !(try parseParameter()) {
                eatCommentsAndWhitespace()
                if !(source.first?.isNewline ?? true) {
                    // Direct parameter
                    let directParameterValue: Expression
                    do {
                        guard let dpValue = try parsePrimary() else {
                            return result()
                        }
                        directParameterValue = dpValue
                    }
                    parameters.append((Term(Term.ID(Parameters.direct)), directParameterValue))
                }
            }
            
            // Parse remaining named parameters
            while try parseParameter() {
            }
            
            return result()
        case .parameter: // MARK: .parameter
            throw AdHocParseError("parameter term outside of a command invocation", at: expressionLocation)
        case .variable: // MARK: .variable
            return .variable(term)
        case .resource: // MARK: .resource
            return .resource(term)
        }
    }
    
    public func postprocess(primary: Expression) throws -> Expression.Kind? {
        return try tryParseSpecifierPhrase(chainingTo: primary)
    }
    
    public func parseSpecifierAfterTypeName() throws -> Specifier.Kind? {
        eatCommentsAndWhitespace()
        guard let firstWord = Term.Name.nextWord(in: source) else {
            return nil
        }
        
        switch firstWord {
        case "index":
            addingElement {
                source.removeFirst(firstWord.count)
            }
            return try parsePrimary().map { dataExpression in
                return .index(dataExpression)
            }
        case "named":
            addingElement {
                source.removeFirst(firstWord.count)
            }
            return try parsePrimary().map { dataExpression in
                return .name(dataExpression)
            }
        case "id":
            addingElement {
                source.removeFirst(firstWord.count)
            }
            return try parsePrimary().map { dataExpression in
                return .id(dataExpression)
            }
        case "whose", "where":
            addingElement {
                source.removeFirst(firstWord.count)
            }
            return try parsePrimary().map { expression in
                return .test(expression, expression.asTestPredicate())
            }
        default:
            guard
                !source.hasPrefix("\n"),
                let firstExpression = try? parsePrimary()
            else {
                return nil
            }
            
            eatCommentsAndWhitespace()
            let midWord = Term.Name.nextWord(in: source)
            
            switch midWord {
            case "thru", "through":
                addingElement {
                    source.removeFirst(midWord!.count)
                }
                return try parsePrimary().map { secondExpression in
                    return .range(from: firstExpression, to: secondExpression)
                }
            default:
                return .simple(firstExpression)
            }
        }
    }
    
    public func parseRelativeSpecifierAfterTypeName(_ typeTerm: Term) throws -> Specifier? {
        if tryEating(prefix: "before") {
            guard let parentExpression = try parsePrimary() else {
                // e.g., window before
                throw AdHocParseError("expected expression after ‘before’", at: currentLocation)
            }
            return Specifier(term: typeTerm, kind: .previous, parent: parentExpression)
        } else if tryEating(prefix: "after") {
            guard let parentExpression = try parsePrimary() else {
                // e.g., window before
                throw AdHocParseError("expected expression after ‘after’", at: currentLocation)
            }
            return Specifier(term: typeTerm, kind: .next, parent: parentExpression)
        } else {
            return nil
        }
    }
    
    public func parseSpecifierAfterQuantifier(kind: Specifier.Kind) throws -> Expression.Kind? {
        guard let type = try parseTypeTerm() else {
            throw ParseError(.missing(.type), at: currentLocation)
        }
        let specifier = Specifier(term: type, kind: kind)
        return .specifier(specifier)
    }
    
    public func parseInsertionSpecifierAfterInsertionLocation(kind: InsertionSpecifier.Kind) throws -> Expression.Kind? {
        .insertionSpecifier(InsertionSpecifier(kind: kind, parent: try parsePrimary()))
    }
    
    public func tryParseSpecifierPhrase(chainingTo chainTo: Expression) throws -> Expression.Kind? {
        guard
            let childSpecifier = chainTo.asSpecifier(),
            tryEating(prefix: "of") || tryEating(prefix: "in")
        else {
            return try tryParseSuffixSpecifier(chainingTo: chainTo)
        }
        
        // Add new parent to top of specifier chain
        // e.g., character 1 of "hello"
        // First expression (chainTo) must be a specifier since it is the child
        
        guard let parentExpression = try parsePrimary() else {
            // e.g., character 1 of
            throw AdHocParseError("expected expression after ‘of’ or ‘in’", at: currentLocation)
        }

        childSpecifier.setRootAncestor(parentExpression)
        
        return .specifier(childSpecifier)
    }
    
    public func tryParseSuffixSpecifier(chainingTo chainTo: Expression) throws -> Expression.Kind? {
        let possessiveStartIndex = currentIndex
        guard tryEating(prefix: "'s") || tryEating(prefix: "’s") else {
            return nil
        }
        
        // Add new child to bottom of specifier chain
        // e.g., "hello"'s first character
        // Second expression (the one about to be parsed) must be a specifier since
        // it is the child
        
        guard let newChildExpression = try parsePrimary() else {
            // e.g., "hello"'s
            let possessiveLocation = SourceLocation(possessiveStartIndex..<currentIndex, source: entireSource)
            throw AdHocParseError("expected specifier after possessive, but found end of script", at: currentLocation, fixes: [DeletingFix(at: possessiveLocation)])
        }
        
        guard let newChildSpecifier = newChildExpression.asSpecifier() else {
            // e.g., "hello"'s 123
            throw AdHocParseError("a non-specifier expression may only come first in a possessive-specifier-phrase", at: newChildExpression.location)
        }
        
        newChildSpecifier.parent = chainTo
        return .specifier(newChildSpecifier)
    }
    
}

import BushelLanguage
import Bushel
import Regex

public final class EnglishParser: BushelLanguage.SourceParser {
    
    public static var sdefCache: [URL : Data] = [:]
    
    public var entireSource: String = ""
    public lazy var source: Substring = Substring(entireSource)
    public var expressionStartIndices: [String.Index] = []
    public lazy var termNameStartIndex: String.Index = entireSource.startIndex
    
    public var lexicon: Lexicon = Lexicon()
    public var sequenceNestingLevel: Int = 0
    public var elements: Set<SourceElement> = []
    public var awaitingExpressionEndKeywords: [Set<TermName>] = []
    public var sequenceEndTags: [TermName] = []
    
    public init() {
    }
    
    public let prefixOperators: [TermName : UnaryOperation] = [
        TermName("not"): .not
    ]
    
    public let postfixOperators: [TermName : UnaryOperation] = [:]
    
    public let binaryOperators: [TermName : BinaryOperation] = [
        TermName("or"): .or,
        TermName("xor"): .xor,
        TermName("and"): .and,
        TermName("is a"): .isA,
        TermName("is an"): .isA,
        TermName("is not a"): .isNotA,
        TermName("is not an"): .isNotA,
        TermName("isn't a"): .isNotA,
        TermName("isn’t a"): .isNotA,
        TermName("isn't an"): .isNotA,
        TermName("isn’t an"): .isNotA,
        TermName("equals"): .equal,
        TermName("equal to"): .equal,
        TermName("equals to"): .equal,
        TermName("is equal to"): .equal,
        TermName("is"): .equal,
        TermName("="): .equal,
        TermName("=="): .equal,
        TermName("not equal to"): .notEqual,
        TermName("is not equal to"): .notEqual,
        TermName("isn't equal to"): .notEqual,
        TermName("isn’t equal to"): .notEqual,
        TermName("unequal to"): .notEqual,
        TermName("is unequal to"): .notEqual,
        TermName("is not"): .notEqual,
        TermName("isn't"): .notEqual,
        TermName("isn’t"): .notEqual,
        TermName("not ="): .notEqual,
        TermName("!="): .notEqual,
        TermName("≠"): .notEqual,
        TermName("less than"): .less,
        TermName("is less than"): .less,
        TermName("<"): .less,
        TermName("less than equal to"): .lessEqual,
        TermName("less than or equals"): .lessEqual,
        TermName("less than or equal to"): .lessEqual,
        TermName("is less than equal to"): .lessEqual,
        TermName("is less than or equals"): .lessEqual,
        TermName("is less than or equal to"): .lessEqual,
        TermName("<="): .lessEqual,
        TermName("≤"): .lessEqual,
        TermName("greater than"): .greater,
        TermName("is greater than"): .greater,
        TermName(">"): .greater,
        TermName("greater than equal to"): .greaterEqual,
        TermName("greater than or equals"): .greaterEqual,
        TermName("greater than or equal to"): .greaterEqual,
        TermName("is greater than equal to"): .greaterEqual,
        TermName("is greater than or equals"): .greaterEqual,
        TermName("is greater than or equal to"): .greaterEqual,
        TermName(">="): .greaterEqual,
        TermName("≥"): .greaterEqual,
        TermName("starts with"): .startsWith,
        TermName("begins with"): .startsWith,
        TermName("ends with"): .endsWith,
        TermName("contains"): .contains,
        TermName("has"): .contains,
        TermName("does not contain"): .notContains,
        TermName("doesn't contain"): .notContains,
        TermName("doesn’t contain"): .notContains,
        TermName("does not have"): .notContains,
        TermName("doesn't have"): .notContains,
        TermName("doesn’t have"): .notContains,
        TermName("is in"): .containedBy,
        TermName("is contained by"): .containedBy,
        TermName("is not in"): .notContainedBy,
        TermName("isn't in"): .notContainedBy,
        TermName("isn’t in"): .notContainedBy,
        TermName("is not contained by"): .notContainedBy,
        TermName("isn't contained by"): .notContainedBy,
        TermName("isn’t contained by"): .notContainedBy,
        TermName("&"): .concatenate,
        TermName("+"): .add,
        TermName("-"): .subtract,
        TermName("−"): .subtract,
        TermName("*"): .multiply,
        TermName("×"): .multiply,
        TermName("/"): .divide,
        TermName("÷"): .divide,
        TermName("as"): .coerce,
    ]
    
    public let stringMarkers: [(begin: TermName, end: TermName)] = [
        (begin: TermName("\""), end: TermName("\"")),
        (begin: TermName("“"), end: TermName("”"))
    ]
    
    public let expressionGroupingMarkers: [(begin: TermName, end: TermName)] = [
        (begin: TermName("("), end: TermName(")"))
    ]
    
    public let listMarkers: [(begin: TermName, end: TermName, itemSeparators: [TermName])] = []
    
    public let recordMarkers: [(begin: TermName, end: TermName, itemSeparators: [TermName], keyValueSeparators: [TermName])] = []
    
    public let listAndRecordMarkers: [(begin: TermName, end: TermName, itemSeparators: [TermName], keyValueSeparators: [TermName])] = [
        (begin: TermName("{"), end: TermName("}"), itemSeparators: [TermName(",")], keyValueSeparators: [TermName(":")])
    ]
    
    public let lineCommentMarkers: [TermName] = [
        TermName("--")
    ]
    
    public let blockCommentMarkers: [(begin: TermName, end: TermName)] = [
        (begin: TermName("--("), end: TermName(")--"))
    ]
    
    public lazy var keywords: [TermName : KeywordHandler] = [
        TermName("end"): handleEnd,
        TermName("on"): handleFunctionStart,
        TermName("to"): handleFunctionStart,
        TermName("if"): handleIf,
        TermName("repeat"): handleRepeat(TermName("repeat")),
        TermName("repeating"): handleRepeat(TermName("repeating")),
        TermName("tell"): handleTell,
        TermName("let"): handleLet,
        TermName("define"): handleDefine,
        TermName("defining"): handleDefining,
        TermName("return"): handleReturn,
        TermName("use"): handleUse,
        TermName("that"): handleThat,
        TermName("it"): handleIt,
        TermName("null"): handleNull,
        TermName("every"): handleQuantifier(.all),
        TermName("all"): handleQuantifier(.all),
        TermName("first"): handleQuantifier(.first),
        TermName("front"): handleQuantifier(.first),
        TermName("middle"): handleQuantifier(.middle),
        TermName("last"): handleQuantifier(.last),
        TermName("back"): handleQuantifier(.last),
        TermName("some"): handleQuantifier(.random),
        TermName("ref"): handleRef(TermName("ref")),
        TermName("get"): handleGet(TermName("get")),
        TermName("set"): handleSet,
    ]
    
    public lazy var resourceTypes: [TermName : (hasName: Bool, stoppingAt: [String], handler: ResourceTypeHandler)] = [
        TermName("system"): (false, [], handleUseSystem),
        TermName("operating system"): (false, [], handleUseSystem),
        TermName("OS"): (false, [], handleUseSystem),
        TermName("macOS"): (false, [], handleUseSystem),
        TermName("OS X"): (false, [], handleUseSystem),
        TermName("MacOS"): (false, [], handleUseSystem),
        TermName("Mac OS"): (false, [], handleUseSystem),
        TermName("Mac OS X"): (false, [], handleUseSystem),
        
        TermName("application"): (true, [], handleUseApplicationName),
        TermName("app"): (true, [], handleUseApplicationName),
        TermName("application id"): (true, [], handleUseApplicationID),
        TermName("app id"): (true, [], handleUseApplicationID),
        
        TermName("AppleScript"): (true, ["at"], handleUseAppleScript),
    ]
    
    private func handleFunctionStart() throws -> Expression.Kind? {
        guard let termName = try parseTermNameEagerly(stoppingAt: [":"]) else {
            throw ParseError(description: "expected function name", location: SourceLocation(source.range, source: entireSource))
        }
        let functionNameTerm = VariableTerm(.id(termName.normalized), name: termName)
        
        var parameters: [ParameterTerm] = []
        var arguments: [VariableTerm] = []
        if tryEating(prefix: ":", spacing: .right) {
            while let parameterTermName = try parseTermNameLazily() {
                parameters.append(ParameterTerm(.id(parameterTermName.normalized), name: parameterTermName))
                
                var argumentName = try parseTermNameEagerly(stoppingAt: [","]) ?? parameterTermName
                if argumentName.words.isEmpty {
                    argumentName = parameterTermName
                }
                arguments.append(VariableTerm(.id(argumentName.normalized), name: argumentName))
                
                if !tryEating(prefix: ",", spacing: .right) {
                    break
                }
            }
        }
        
        let commandTerm = CommandTerm(.id(termName.normalized), name: termName, parameters: ParameterTermDictionary(contents: parameters))
        lexicon.add(commandTerm)
        
        guard tryEating(prefix: "\n") else {
            throw ParseError(description: "expected line break to begin function body", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation)])
        }
        let body = try withScope {
            lexicon.add(Set(arguments))
            return try parseSequence(functionNameTerm.name!)
        }
        
        return .function(name: functionNameTerm, parameters: parameters, arguments: arguments, body: body)
    }
    
    private func handleIf() throws -> Expression.Kind? {
        guard let condition = try parsePrimary() else {
            throw ParseError(description: "expected condition expression after ‘if’", location: currentLocation)
        }
        
        func parseThen() throws -> Expression {
            let thenStartIndex = currentIndex
            let foundThen = tryEating(prefix: "then")
            let foundNewline = tryEating(prefix: "\n")
            guard foundThen || foundNewline else {
                throw ParseError(description: "expected ‘then’ or line break after condition expression to begin ‘if’-block", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation), AppendingFix(appending: " then", at: currentLocation)])
            }
            
            if foundNewline {
                return try parseSequence(TermName("if"), stoppingAt: ["else"])
            } else {
                guard let thenExpression = try parsePrimary() else {
                    let thenLocation = SourceLocation(thenStartIndex..<currentIndex, source: entireSource)
                    throw ParseError(description: "expected expression or line break after ‘then’ to begin ‘if’-block", location: thenLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it when the condition is true", at: [currentLocation]), SuggestingFix(suggesting: "{FIX} to evaluate a sequence of expressions when the condition is true", by: AppendingFix(appending: "\n", at: thenLocation))])
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
                return try parseSequence(TermName("if"))
            } else {
                guard let elseExpr = try parsePrimary() else {
                    let elseLocation = SourceLocation(elseStartIndex..<currentIndex, source: entireSource)
                    throw ParseError(description: "expected expression or line break after ‘else’ to begin ‘else’-block", location: elseLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it when the condition is true", by: AppendingFix(appending: " <#expression#>", at: currentLocation)), SuggestingFix(suggesting: "{FIX} to evaluate a sequence of expressions when the condition is true", by: AppendingFix(appending: "\n", at: elseLocation))])
                }
                
                eatCommentsAndWhitespace()
                
                return elseExpr
            }
        }
        
        return .if_(condition: condition, then: try parseThen(), else: try parseElse())
    }
    
    private func handleRepeat(_ keyword: TermName) -> () throws -> Expression.Kind? {
        { [weak self] in
            try self?.handleRepeat(keyword)
        }
    }
    
    private func handleRepeat(_ keyword: TermName) throws -> Expression.Kind? {
        func parseRepeatBlock() throws -> Expression {
            guard tryEating(prefix: "\n") else {
                throw ParseError(description: "expected line break to begin repeat block", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation)])
            }
            return try parseSequence(keyword)
        }
        
        if tryEating(prefix: "while") {
            guard let condition = try parsePrimary() else {
                throw ParseError(description: "expected condition expression after ‘\(keyword) while’", location: currentLocation)
            }
            
            return .repeatWhile(condition: condition, repeating: try parseRepeatBlock())
        } else if tryEating(prefix: "for") {
            guard let variableTerm = try parseVariableTerm(stoppingAt: ["in"]) else {
                throw ParseError(description: "expected variable name after ‘repeat for’", location: currentLocation)
            }
            
            guard tryEating(prefix: "in") else {
                throw ParseError(description: "expected ‘in’ to begin container expression in ‘repeat for’", location: currentLocation)
            }
            
            guard let expression = try parsePrimary() else {
                throw ParseError(description: "expected container expression in ‘repeat for’", location: currentLocation)
            }
            
            lexicon.add(variableTerm)
            
            return .repeatFor(variable: variableTerm, container: expression, repeating: try parseRepeatBlock())
        } else {
            guard let times = try parsePrimary() else {
                throw ParseError(description: "expected times expression after ‘\(expressionLocation.snippet(in: entireSource))’", location: currentLocation)
            }
            
            guard tryEating(prefix: "times") else {
                throw ParseError(description: "expected ‘times’ after times expression", location: currentLocation, fixes: [AppendingFix(appending: " times", at: currentLocation)])
            }
            
            return .repeatTimes(times: times, repeating: try parseRepeatBlock())
        }
    }
    
    private func handleTell() throws -> Expression.Kind? {
        guard let target = try parsePrimary() else {
            throw ParseError(description: "expected target expression after ‘tell’", location: currentLocation)
        }
        
        let toStartIndex = currentIndex
        let foundTo = tryEating(prefix: "to")
        let foundNewline = tryEating(prefix: "\n")
        guard foundTo && !foundNewline || !foundTo && foundNewline else {
            throw ParseError(description: "expected ‘to’ or line break following target expression to begin ‘tell’-block", location: currentLocation, fixes: [SuggestingFix(suggesting: "{FIX} to evaluate a single targeted expression", by: AppendingFix(appending: " to", at: currentLocation)), SuggestingFix(suggesting: "{FIX} to evaluate a targeted sequence of expressions", by: AppendingFix(appending: "\n", at: currentLocation))])
        }
        
        return try withTerminology(of: target) {
            let toExpr: Expression
            if foundNewline {
                toExpr = try parseSequence(TermName("tell"))
            } else {
                guard let toExpression = try parsePrimary() else {
                    let toLocation = SourceLocation(toStartIndex..<currentIndex, source: entireSource)
                    throw ParseError(description: "expected expression after ‘to’ in ‘tell’-expression", location: toLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it with a new target", by: AppendingFix(appending: " <#expression#>", at: currentLocation))])
                }
                toExpr = toExpression
            }
            
            return .tell(target: target, to: toExpr)
        }
    }
    
    private func handleLet() throws -> Expression.Kind? {
        guard let term = try parseVariableTerm(stoppingAt: ["be"]) else {
            throw ParseError(description: "expected variable name after ‘let’", location: currentLocation)
        }
        
        var initialValue: Expression? = nil
        if tryEating(prefix: "be") {
            guard let value = try parsePrimary() else {
                throw ParseError(description: "expected initial value expression after ‘be’", location: currentLocation)
            }
            initialValue = value
        }
        
        lexicon.add(term)
        
        return .let_(term, initialValue: initialValue)
    }
    
    private func parseDefineLine() throws -> (term: Term, existingTerm: Term?) {
        guard let termType = parseTermTypeName() else {
            throw ParseError(description: "expected term type", location: currentLocation)
        }
        
        guard let termName = try parseTermNameEagerly(stoppingAt: ["as"], styling: styling(for: termType)) else {
            throw ParseError(description: "expected term name", location: currentLocation)
        }
        
        let existingTerm: Term? = try {
            guard tryEating(prefix: "as") else {
                return nil
            }
            guard let existingTerm = try eatTerm() else {
                throw ParseError(description: "expected a term", location: currentLocation)
            }
            return existingTerm
        }()
        
        guard
            let term = Term.make(
                for: TypedTermUID(termType, existingTerm?.uid ?? lexicon.makeUID(forName: termName)),
                name: termName
            )
        else {
            throw ParseError(description: "this term type cannot have this definition; \(existingTerm == nil ? "try providing a valid one with 'as'" : "try a different definition or try removing 'as'")", location: currentLocation)
        }
        
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
            try parseSequence(TermName("defining"))
        }
        return .defining(term, as: existingTerm, body: body)
    }
    
    private func handleUseSystem(name: TermName) throws -> ResourceTerm {
        var system = Resource.System()
        if tryEating(prefix: "version") {
            eatCommentsAndWhitespace()
            guard let match = tryEating(Regex("[vV]?(\\d+)\\.(\\d+)(?:\\.(\\d+))?")) else {
                throw ParseError(description: "expected OS version number", location: currentLocation)
            }
            
            let versionComponents = match.captures.compactMap { $0.map { Int($0)! } }
            let majorVersion = versionComponents[0]
            let minorVersion = versionComponents[1]
            let patchVersion = versionComponents.indices.contains(2) ? versionComponents[2] : 0
            
            let version = OperatingSystemVersion(majorVersion: majorVersion, minorVersion: minorVersion, patchVersion: patchVersion)
            guard let resolved = Resource.System(version: version) else {
                let realVersion = ProcessInfo.processInfo.operatingSystemVersionString
                throw ParseError(description: "this script requires an operating system version of at least \(match.matchedString); your system is running \(realVersion)", location: expressionLocation)
            }
            
            system = resolved
        }
        
        let term = ResourceTerm(lexicon.makeUID(forName: name), name: name, resource: system.enumerated())
        
        // Terminology should be defined in translation files
        
        return term
    }
    
    private func handleUseApplicationName(name: TermName) throws -> ResourceTerm {
        guard let application = Resource.ApplicationByName(name: name.normalized) else {
            throw ParseError(description: "this script requires the application “\(name)”, which was not found on your system", location: termNameLocation)
        }
        
        let term = ResourceTerm(lexicon.makeUID(forName: name), name: name, resource: application.enumerated())
        
        try term.loadResourceTerminology(under: lexicon.pool)
        lexicon.add(term)
        
        return term
    }
    
    private func handleUseApplicationID(name: TermName) throws -> ResourceTerm {
        guard let application = Resource.ApplicationByID(id: name.normalized) else {
            throw ParseError(description: "this script requires an application with identifier “\(name)”, which was not found on your system", location: termNameLocation)
        }
        let term = ResourceTerm(lexicon.makeUID(forName: name), name: name, resource: application.enumerated())
        
        try term.loadResourceTerminology(under: lexicon.pool)
        lexicon.add(term)
        
        return term
    }
    
    private func handleUseAppleScript(name: TermName) throws -> ResourceTerm {
        guard tryEating(prefix: "at") else {
            throw ParseError(description: "expected ‘at’ (more addressing modes coming soon)", location: currentLocation)
        }
        
        let pathStartIndex = currentIndex
        guard var (_, path) = try parseString() else {
            throw ParseError(description: "expected path string", location: currentLocation)
        }
        
        path = (path as NSString).expandingTildeInPath
        
        guard let applescript = Resource.AppleScriptAtPath(path: path) else {
            throw ParseError(description: "this script requires an AppleScript script at path “\(path)”, which was not found on your system", location: SourceLocation(pathStartIndex..<currentIndex, source: entireSource))
        }
        let term = ResourceTerm(lexicon.makeUID(forName: name), name: name, resource: applescript.enumerated())
        
        try? term.loadResourceTerminology(under: lexicon.pool)
        lexicon.add(term)
        
        return term
    }
    
    private func handleSet() throws -> Expression.Kind? {
        guard let destinationExpression = try parsePrimary() else {
            throw ParseError(description: "expected destination-expression after ‘set’", location: currentLocation)
        }
        guard tryEating(prefix: "to") else {
            throw ParseError(description: "expected ‘to’ after ‘set’ destination-expression to begin new-value-expression", location: currentLocation)
        }
        guard let newValueExpression = try parsePrimary() else {
            throw ParseError(description: "expected new-value-expression after ‘to’", location: currentLocation)
        }
        return .set(destinationExpression, to: newValueExpression)
    }
    
    private func handleQuantifier(_ kind: Specifier.Kind) -> () throws -> Expression.Kind? {
        {
            try self.parseSpecifierAfterQuantifier(kind: kind, startIndex: self.expressionStartIndex)
        }
    }
    
    public func handle(term: Term) throws -> Expression.Kind? {
        switch term.enumerated {
        case .enumerator(let term): // MARK: .enumerator
            return .enumerator(term)
        case .dictionary(_): // MARK: .dictionary
            // TODO: Such purely organizational dictionaries should probably
            // have a runtime reflection type.
            return .null
        case .class_(let term): // MARK: .class_
            if let specifierKind = try parseSpecifierAfterClassName() {
                return .specifier(Specifier(class: term, kind: specifierKind))
            } else if let specifier = try parseRelativeSpecifierAfterClassName(term) {
                return .specifier(specifier)
            } else {
                // Just the class name
                return .class_(term)
            }
        case .pluralClass(let term): // MARK: .pluralClass
            if let specifierKind = try parseSpecifierAfterClassName() {
                return .specifier(Specifier(class: term, kind: specifierKind))
            } else {
                // Just the plural class name
                // Equivalent to an "all" specifier
                return .specifier(Specifier(class: term, kind: .all))
            }
        case .property(let term): // MARK: .property
            let specifier = Specifier(class: term, kind: .property)
            return .specifier(specifier)
        case .command(let term): // MARK: .command
            var parameters: [(ParameterTerm, Expression)] = []
            func parseParameter() throws -> Bool {
                guard let parameterTerm = try eatTerm(terminology: term.parameters) as? ParameterTerm else {
                    return false
                }
                
                guard let parameterValue = try parsePrimary() else {
                    throw ParseError(description: "expected expression after parameter name, but found end of script", location: currentLocation)
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
                    parameters.append((lexicon.pool.term(forUID: TypedTermUID(ParameterUID.direct)) as! ParameterTerm, directParameterValue))
                }
            }
            
            // Parse remaining named parameters
            while try parseParameter() {
            }
            
            return result()
        case .parameter: // MARK: .parameter
            throw ParseError(description: "parameter term outside of a command invocation", location: expressionLocation)
        case .variable(let term): // MARK: .variable
            return .variable(term)
        case .resource(let term): // MARK: .resource
            return .resource(term)
        }
    }
    
    public func postprocess(primary: Expression) throws -> Expression.Kind? {
        return try tryParseSpecifierPhrase(chainingTo: primary)
    }
    
    public func parseSpecifierAfterClassName() throws -> Specifier.Kind? {
        eatCommentsAndWhitespace()
        guard let firstWord = TermName.nextWord(in: source) else {
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
            let midWord = TermName.nextWord(in: source)
            
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
    
    public func parseRelativeSpecifierAfterClassName(_ term: ClassTerm) throws -> Specifier? {
        if tryEating(prefix: "before") {
            guard let parentExpression = try parsePrimary() else {
                // e.g., window before
                throw ParseError(description: "expected expression after ‘before’", location: currentLocation)
            }
            return Specifier(class: term, kind: .previous, parent: parentExpression)
        } else if tryEating(prefix: "after") {
            guard let parentExpression = try parsePrimary() else {
                // e.g., window before
                throw ParseError(description: "expected expression after ‘after’", location: currentLocation)
            }
            return Specifier(class: term, kind: .next, parent: parentExpression)
        } else {
            return nil
        }
    }
    
    public func parseSpecifierAfterQuantifier(kind: Specifier.Kind, startIndex: Substring.Index) throws -> Expression.Kind? {
        guard let type = try parseTypeTerm() else {
            throw ParseError(description: "expected type name", location: currentLocation)
        }
        let specifier = Specifier(class: type, kind: kind)
        return .specifier(specifier)
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
            throw ParseError(description: "expected expression after ‘of’ or ‘in’", location: currentLocation)
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
            throw ParseError(description: "expected specifier after possessive, but found end of script", location: currentLocation, fixes: [DeletingFix(at: possessiveLocation)])
        }
        
        guard let newChildSpecifier = newChildExpression.asSpecifier() else {
            // e.g., "hello"'s 123
            throw ParseError(description: "a non-specifier expression may only come first in a possessive-specifier-phrase", location: newChildExpression.location)
        }
        
        newChildSpecifier.parent = chainTo
        return .specifier(newChildSpecifier)
    }
    
}

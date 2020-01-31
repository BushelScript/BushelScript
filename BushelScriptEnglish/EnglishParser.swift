import BushelLanguage
import Bushel

public final class EnglishParser: BushelLanguage.SourceParser {
    
    public static var sdefCache: [URL : Data] = [:]
    
    public var entireSource: String = ""
    public lazy var source: Substring = Substring(entireSource)
    public var expressionStartIndices: [String.Index] = []
    
    public var lexicon: Lexicon = Lexicon()
    public var currentElements: [[PrettyPrintable]] = []
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
        TermName("is equal to"): .equal,
        TermName("is"): .equal,
        TermName("="): .equal,
        TermName("=="): .equal,
        TermName("not equal to"): .notEqual,
        TermName("is not equal to"): .notEqual,
        TermName("isn't"): .notEqual,
        TermName("isn’t"): .notEqual,
        TermName("not ="): .notEqual,
        TermName("!="): .notEqual,
        TermName("≠"): .notEqual,
        TermName("less than"): .less,
        TermName("<"): .less,
        TermName("less than equal"): .lessEqual,
        TermName("less than equal to"): .lessEqual,
        TermName("less than equals"): .lessEqual,
        TermName("less than or equal"): .lessEqual,
        TermName("less than or equals"): .lessEqual,
        TermName("less than or equal to"): .lessEqual,
        TermName("<="): .lessEqual,
        TermName("≤"): .lessEqual,
        TermName("greater than"): .greater,
        TermName(">"): .greater,
        TermName("greater than equal"): .greaterEqual,
        TermName("greater than equal to"): .greaterEqual,
        TermName("greater than equals"): .greaterEqual,
        TermName("greater than or equal"): .greaterEqual,
        TermName("greater than or equals"): .greaterEqual,
        TermName("greater than or equal to"): .greaterEqual,
        TermName("starts with"): .startsWith,
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
        TermName("contained by"): .containedBy,
        TermName("is contained by"): .containedBy,
        TermName("part of"): .containedBy,
        TermName("is part of"): .containedBy,
        TermName("is not in"): .notContainedBy,
        TermName("isn't in"): .notContainedBy,
        TermName("isn’t in"): .notContainedBy,
        TermName("not contained by"): .notContainedBy,
        TermName("is not contained by"): .notContainedBy,
        TermName("isn't contained by"): .notContainedBy,
        TermName("isn’t contained by"): .notContainedBy,
        TermName("not part of"): .notContainedBy,
        TermName("is not part of"): .notContainedBy,
        TermName("isn't part of"): .notContainedBy,
        TermName("isn’t part of"): .notContainedBy,
        TermName(">="): .greaterEqual,
        TermName("≥"): .greaterEqual,
        TermName("&"): .concatenate,
        TermName("+"): .add,
        TermName("-"): .subtract,
        TermName("−"): .subtract,
        TermName("*"): .multiply,
        TermName("×"): .multiply,
        TermName("/"): .divide,
        TermName("÷"): .divide,
    ]
    
    public let stringMarkers: [(begin: TermName, end: TermName)] = [
        (begin: TermName("\""), end: TermName("\"")),
        (begin: TermName("“"), end: TermName("”"))
    ]
    
    public let lineCommentMarkers: [TermName] = [
        TermName("--")
    ]
    
    public let blockCommentMarkers: [(begin: TermName, end: TermName)] = [
        (begin: TermName("--("), end: TermName(")--"))
    ]
    
    public lazy var keywords: [TermName : KeywordHandler] = [
        TermName("("): handleOpenParenthesis,
        TermName("{"): handleOpenBrace,
        TermName("end"): handleEnd,
        TermName("on"): handleFunctionStart,
        TermName("to"): handleFunctionStart,
        TermName("if"): handleIf,
        TermName("repeat"): handleRepeat(TermName("repeat")),
        TermName("repeating"): handleRepeat(TermName("repeating")),
        TermName("tell"): handleTell,
        TermName("let"): handleLet,
        TermName("return"): {
            self.eatCommentsAndWhitespace()
            if self.source.first?.isNewline ?? true {
                return .return_(Expression.empty(at: self.currentIndex))
            } else {
                return .return_(try self.parsePrimary())
            }
        },
        TermName("use application"): handleUseApplication,
        TermName("use app"): handleUseApplication,
        TermName("that"): { .that },
        TermName("it"): { .it },
        TermName("every"): handleQuantifier(.all),
        TermName("all"): handleQuantifier(.all),
        TermName("first"): handleQuantifier(.first),
        TermName("front"): handleQuantifier(.first),
        TermName("middle"): handleQuantifier(.middle),
        TermName("last"): handleQuantifier(.last),
        TermName("back"): handleQuantifier(.last),
        TermName("some"): handleQuantifier(.random),
        TermName("ref"): {
            guard let expression = try self.parsePrimary() else {
                throw ParseError(description: "expected expression after ‘ref’", location: self.currentLocation)
            }
            return .reference(to: expression)
        },
        TermName("get"): {
            guard let sourceExpression = try self.parsePrimary() else {
                throw ParseError(description: "expected source-expression after ‘get’", location: self.currentLocation)
            }
            return .get(sourceExpression)
        },
        TermName("set"): handleSet,
        TermName("null"): { .null }
    ]
    
    private func handleOpenParenthesis() throws -> Expression.Kind? {
        try awaiting(endMarker: TermName(")")) {
            eatCommentsAndWhitespace(eatingNewlines: true)
            guard let enclosed = try parsePrimary() else {
                throw ParseError(description: "expected expression after ‘(’", location: SourceLocation(source.range, source: entireSource))
            }
            eatCommentsAndWhitespace(eatingNewlines: true)
            guard tryEating(prefix: ")") else {
                throw ParseError(description: "expected ‘)’ to end bracketed expression", location: SourceLocation(source.range, source: entireSource))
            }
            
            return .parentheses(enclosed)
        }
    }
    
    private func handleOpenBrace() throws -> Expression.Kind? {
        try awaiting(endMarkers: [TermName("}"), TermName(","), TermName(":")]) {
            eatCommentsAndWhitespace(eatingNewlines: true)
            guard !tryEating(prefix: "}") else {
                return .list([])
            }
            guard !tryEating(prefix: ":") else {
                guard tryEating(prefix: "}") else {
                    throw ParseError(description: "expected key expression before ‘:’, or ‘}’ after for an empty record", location: currentLocation)
                }
                return .record([])
            }
            
            let first = try parseListItem(as: "list item or record key")
            
            if tryEating(prefix: "}") {
                return .list([first])
            } else if tryEating(prefix: ",") {
                var items: [Expression] = [first]
                repeat {
                    items.append(try parseListItem(as: "list item"))
                } while tryEating(prefix: ",")
                
                guard tryEating(prefix: "}") else {
                    throw ParseError(description: "expected ‘}’ to end list or ‘,’ to separate additional items", location: currentLocation)
                }
                return .list(items)
            } else if tryEating(prefix: ":") {
                let first = (key: first, value: try parseListItem(as: "record item"))
                var items: [(key: Expression, value: Expression)] = [first]
                while tryEating(prefix: ",") {
                    let key = try parseListItem(as: "record key")
                    guard tryEating(prefix: ":") else {
                        throw ParseError(description: "expected ‘:’ after key in record", location: currentLocation)
                    }
                    let value = try parseListItem(as: "record item")
                    items.append((key: key, value: value))
                }
                
                guard tryEating(prefix: "}") else {
                    throw ParseError(description: "expected ‘}’ to end record or ‘,’ to separate additional items", location: currentLocation)
                }
                return .record(items)
            } else {
                throw ParseError(description: "expected ‘}’ to end list, ‘,’ to separate additional items or ‘:’ to make a record", location: currentLocation)
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
    
    private func handleEnd() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        if findExpressionEndKeyword() || source.hasPrefix("\n") || source.isEmpty {
            return .end
        }
        let endTag = sequenceEndTags.last!
        guard tryEating(termName: endTag) else {
            throw ParseError(description: "expected ‘\(endTag)’ or line break", location: currentLocation, fixes: [SequencingFix(fixes: [DeletingFix(at: SourceLocation(currentIndex..<(source.firstIndex(where: { $0.isNewline }) ?? source.endIndex), source: entireSource)), AppendingFix(appending: "\(endTag)", at: currentLocation)]), AppendingFix(appending: "\(endTag)\n", at: currentLocation)])
        }
        return .end
    }
    
    private func handleFunctionStart() throws -> Expression.Kind? {
        guard let (termName, termLocation) = try parseTermNameEagerly(stoppingAt: [":"]) else {
            throw ParseError(description: "expected function name", location: SourceLocation(source.range, source: entireSource))
        }
        let functionNameTerm = Located(VariableTerm(.id(termName.normalized), name: termName), at: termLocation)
        
        var parameters: [Located<ParameterTerm>] = []
        var arguments: [Located<VariableTerm>] = []
        if tryEating(prefix: ":") {
            while let (parameterTermName, parameterTermLocation) = try parseTermNameLazily() {
                parameters.append(Located(ParameterTerm(.id(parameterTermName.normalized), name: parameterTermName), at: parameterTermLocation))
                
                var (argumentName, argumentLocation) = try parseTermNameEagerly(stoppingAt: [","]) ?? (parameterTermName, parameterTermLocation)
                if argumentName.words.isEmpty {
                    (argumentName, argumentLocation) = (parameterTermName, parameterTermLocation)
                }
                arguments.append(Located(VariableTerm(.id(argumentName.normalized), name: argumentName), at: argumentLocation))
                
                if !tryEating(prefix: ",") {
                    break
                }
            }
        }
        
        let parameterTerms = parameters.map { $0.term }
        
        let commandTerm = CommandTerm(.id(termName.normalized), name: termName, parameters: ParameterTermDictionary(contents: parameterTerms))
        lexicon.add(commandTerm)
        
        guard tryEating(prefix: "\n") else {
            throw ParseError(description: "expected line break to begin function body", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation)])
        }
        let body = try withScope {
            lexicon.add(Set(arguments.map { $0.term }))
            return try parseSequence(functionNameTerm.name!) ?? Sequence.empty(at: currentIndex)
        }
        
        return .function(name: functionNameTerm, parameters: parameters, arguments: arguments, body: body)
    }
    
    private func handleIf() throws -> Expression.Kind? {
        guard let condition = try parsePrimary() else {
            throw ParseError(description: "expected condition expression after ‘if’", location: currentLocation)
        }
        
        let thenStartIndex = currentIndex
        let foundThen = tryEating(prefix: "then")
        let foundNewline = tryEating(prefix: "\n")
        guard foundThen || foundNewline else {
            throw ParseError(description: "expected ‘then’ or line break after condition expression to begin ‘if’-block", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation), AppendingFix(appending: " then", at: currentLocation)])
        }
        
        let thenExpr: Expression
        if foundNewline {
            thenExpr = try withScope {
                return try parseSequence(TermName("if"), stoppingAt: ["else"]) ?? Sequence.empty(at: currentIndex)
            }
        } else {
            guard let thenExpression = try parsePrimary() else {
                let thenLocation = SourceLocation(thenStartIndex..<currentIndex, source: entireSource)
                throw ParseError(description: "expected expression or line break after ‘then’ to begin ‘if’-block", location: thenLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it when the condition is true", at: [currentLocation]), SuggestingFix(suggesting: "{FIX} to evaluate a sequence of expressions when the condition is true", by: AppendingFix(appending: "\n", at: thenLocation))])
            }
            thenExpr = thenExpression
        }
        
        let elseExpr = try self.parseElse()
        
        return .if_(condition: condition, then: thenExpr, else: elseExpr)
    }
    
    private func handleRepeat(_ endTag: TermName) -> () throws -> Expression.Kind? {
        {
            try self.handleRepeat(endTag)
        }
    }
    
    private func handleRepeat(_ endTag: TermName) throws -> Expression.Kind? {
        func parseRepeatBlock() throws -> Expression {
            try withScope {
                try parseSequence(endTag) ?? Sequence.empty(at: currentIndex)
            }
        }
        
        if tryEating(prefix: "while") {
            guard let condition = try parsePrimary() else {
                throw ParseError(description: "expected condition expression after ‘\(endTag) while’", location: currentLocation)
            }
            
            guard tryEating(prefix: "\n") else {
                throw ParseError(description: "expected line break to begin repeat block", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation)])
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
            guard tryEating(prefix: "\n") else {
                throw ParseError(description: "expected line break after ‘times’ to begin repeat block", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation)])
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
                toExpr = try withScope {
                    return try parseSequence(TermName("tell")) ?? Sequence.empty(at: currentIndex)
                }
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
    
    private func handleUseApplication() throws -> Expression.Kind? {
        eatCommentsAndWhitespace()
        guard !source.hasPrefix("\"") else {
            throw ParseError(description: "‘use application’ takes a raw application name, not a string, since it binds a constant; remove the quotation marks", location: currentLocation)
        }
        
        let byBundleID = tryEating(prefix: "id")
        
        let nameStartIndex = currentIndex
        guard let (name, nameLocation) = try parseTermNameEagerly() else {
            throw ParseError(description: "expected application \(byBundleID ? "identifier" : "name")", location: SourceLocation(source.range, source: entireSource))
        }
        guard let bundle = byBundleID ? Bundle(applicationBundleIdentifier: name.normalized) : Bundle(applicationName: name.normalized) else {
            throw ParseError(description: "this script requires \(byBundleID ? "an application with identifier" : "the application") “\(name)”, which was not found on your system", location: SourceLocation(nameStartIndex..<currentIndex, source: entireSource))
        }
        
        let resource: Resource = byBundleID ? .applicationByID(bundle: bundle) : .applicationByName(bundle: bundle)
        let term = Located(ResourceTerm(.id(name.normalized), name: name, resource: resource), at: nameLocation)
        
        try loadTerminology(at: bundle.bundleURL, into: term.term)
        lexicon.add(term)
        return .use(resource: term)
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
    
    public func handle(term: LocatedTerm) throws -> Expression.Kind? {
        let termLocation = term.location
        switch term.wrappedTerm.enumerated {
        case .enumerator(let term): // MARK: .enumerator
            return .enumerator(term)
        case .dictionary(let term): // MARK: .dictionary
            // FIXME: unimplemented
            return .null
        case .class_(let term): // MARK: .class_
            if let specifierKind = try parseSpecifierAfterClassName() {
                return .specifier(Specifier(class: Located(term, at: termLocation), kind: specifierKind))
            } else if let specifier = try parseRelativeSpecifierAfterClassName(term, at: termLocation) {
                return .specifier(specifier)
            } else {
                // Just the class name
                return .class_(term)
            }
        case .pluralClass(let term): // MARK: .pluralClass
            if let specifierKind = try parseSpecifierAfterClassName() {
                return .specifier(Specifier(class: Located(term, at: termLocation), kind: specifierKind))
            } else {
                // Just the plural class name
                // Equivalent to an "all" specifier
                return .specifier(Specifier(class: Located(term, at: termLocation), kind: .all))
            }
        case .property(let term): // MARK: .property
            let specifier = Specifier(class: Located(term, at: expressionLocation), kind: .property)
            return .specifier(specifier)
        case .command(let term): // MARK: .command
            let termLocation = expressionLocation
            
            var parameters: [(Located<ParameterTerm>, Expression)] = []
            func parseParameter() throws -> Bool {
                let startIndex = currentIndex
                guard let parameterTerm = try eatTerm(terminology: term.parameters) as? ParameterTerm else {
                    return false
                }
                let locatedParameterTerm = Located(parameterTerm, at: SourceLocation(startIndex..<currentIndex, source: entireSource))
                
                guard let parameterValue = try parsePrimary() else {
                    throw ParseError(description: "expected expression after parameter name, but found end of script", location: currentLocation)
                }
                parameters.append((locatedParameterTerm, parameterValue))
                return true
            }
            func result() -> Expression.Kind {
                return .command(Located(term, at: termLocation), parameters: parameters)
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
                    let directParameterLocation = currentLocation
                    let directParameterValue: Expression
                    do {
                        guard let dpValue = try parsePrimary() else {
                            return result()
                        }
                        directParameterValue = dpValue
                    }
                    parameters.append((Located(lexicon.pool.term(forUID: TypedTermUID(ParameterUID.direct)) as! ParameterTerm, at: directParameterLocation), directParameterValue))
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
            return .resource(Located(term, at: expressionLocation))
        }
    }
    
    public func postprocess(primary: Expression) throws -> Expression.Kind? {
        return try tryParseSpecifierPhrase(chainingTo: primary) ?? tryParseCoercion(of: primary)
    }
    
    public func parseElse() throws -> Expression? {
        let elseStartIndex = currentIndex
        guard tryEating(prefix: "else") else {
            return nil
        }
        if tryEating(prefix: "\n") {
            return try withScope {
                return try parseSequence(TermName("if")) ?? Sequence.empty(at: currentIndex)
            }
        } else {
            guard let elseExpr = try parsePrimary() else {
                let elseLocation = SourceLocation(elseStartIndex..<currentIndex, source: entireSource)
                throw ParseError(description: "expected expression or line break after ‘else’ to begin ‘else’-block", location: elseLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it when the condition is true", by: AppendingFix(appending: " <#expression#>", at: currentLocation)), SuggestingFix(suggesting: "{FIX} to evaluate a sequence of expressions when the condition is true", by: AppendingFix(appending: "\n", at: elseLocation))])
            }
            eatCommentsAndWhitespace()
            return elseExpr
        }
    }
    
    public func parseSpecifierAfterClassName() throws -> Specifier.Kind? {
        eatCommentsAndWhitespace()
        guard let firstWord = TermName.nextWord(in: source) else {
            return nil
        }
        
        switch firstWord {
        case "index":
            source.removeFirst(firstWord.count)
            return try parsePrimary().map { dataExpression in
                return .index(dataExpression)
            }
        case "named":
            source.removeFirst(firstWord.count)
            return try parsePrimary().map { dataExpression in
                return .name(dataExpression)
            }
        case "id":
            source.removeFirst(firstWord.count)
            return try parsePrimary().map { dataExpression in
                return .id(dataExpression)
            }
        case "whose", "where":
            source.removeFirst(firstWord.count)
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
                source.removeFirst(midWord!.count)
                return try parsePrimary().map { secondExpression in
                    return .range(from: firstExpression, to: secondExpression)
                }
            default:
                return .simple(firstExpression)
            }
        }
    }
    
    public func parseRelativeSpecifierAfterClassName(_ term: ClassTerm, at termLocation: SourceLocation) throws -> Specifier? {
        if tryEating(prefix: "before") {
            guard let parentExpression = try parsePrimary() else {
                // e.g., window before
                throw ParseError(description: "expected expression after ‘before’", location: currentLocation)
            }
            return Specifier(class: Located(term, at: termLocation), kind: .previous, parent: parentExpression)
        } else if tryEating(prefix: "after") {
            guard let parentExpression = try parsePrimary() else {
                // e.g., window before
                throw ParseError(description: "expected expression after ‘after’", location: currentLocation)
            }
            return Specifier(class: Located(term, at: termLocation), kind: .next, parent: parentExpression)
        } else {
            return nil
        }
    }
    
    public func parseSpecifierAfterQuantifier(kind: Specifier.Kind, startIndex: Substring.Index) throws -> Expression.Kind? {
        guard let type = try parseTypeTerm() else {
            throw ParseError(description: "expected type name", location: currentLocation)
        }
        let specifier = Specifier(class: Located(type.term, at: type.location), kind: kind)
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
    
    public func tryParseCoercion(of expression: Expression) throws -> Expression.Kind? {
        guard tryEating(prefix: "as") else {
            return nil
        }
        
        guard let toType = try parseTypeTerm() else {
            throw ParseError(description: "expected type name", location: currentLocation)
        }
        return .coercion(of: expression, to: toType)
    }
    
}

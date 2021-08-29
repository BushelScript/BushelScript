import Bushel
import Regex

public final class EnglishParser: SourceParser {
    
    public let messageFormatter: MessageFormatter = EnglishMessageFormatter()
    
    public var state = SourceParserState()
    public lazy var config = SourceParserConfig(
        defaultEndKeyword: Term.Name(["end"]),
        keywords: [
            Term.Name("require"): KeywordHandler(self, SourceParser.handleRequire),
            Term.Name("use"): KeywordHandler(self, SourceParser.handleUse),
            Term.Name("return"): KeywordHandler(self, SourceParser.handleReturn),
            Term.Name("raise"): KeywordHandler(self, SourceParser.handleRaise),
            Term.Name("that"): KeywordHandler(self, SourceParser.handleThat),
            Term.Name("it"): KeywordHandler(self, SourceParser.handleIt),
            Term.Name("missing"): KeywordHandler(self, SourceParser.handleMissing),
            Term.Name("unspecified"): KeywordHandler(self, SourceParser.handleUnspecified),
            Term.Name("ref"): KeywordHandler(self, SourceParser.handleRef),
            Term.Name("get"): KeywordHandler(self, SourceParser.handleGet),
            Term.Name("debug_inspect_term"): KeywordHandler(self, SourceParser.handleDebugInspectTerm),
            Term.Name("debug_inspect_lexicon"): KeywordHandler(self, SourceParser.handleDebugInspectLexicon),
            
            Term.Name("set"): KeywordHandler(self, EnglishParser.handleSet),
            Term.Name("on"): KeywordHandler(self, EnglishParser.handleFunctionStart),
            Term.Name("to"): KeywordHandler(self, EnglishParser.handleFunctionStart),
            Term.Name("take"): KeywordHandler(self, EnglishParser.handleBlockArgumentNamesStart),
            Term.Name("do"): KeywordHandler(self, EnglishParser.handleBlockBodyStart),
            Term.Name("try"): KeywordHandler(self, EnglishParser.handleTry),
            Term.Name("if"): KeywordHandler(self, EnglishParser.handleIf),
            Term.Name("repeat"): KeywordHandler(self, EnglishParser.handleRepeat),
            Term.Name("repeating"): KeywordHandler(self, EnglishParser.handleRepeat),
            Term.Name("tell"): KeywordHandler(self, EnglishParser.handleTell),
            Term.Name("let"): KeywordHandler(self, EnglishParser.handleLet),
            Term.Name("define"): KeywordHandler(self, EnglishParser.handleDefine),
            Term.Name("defining"): KeywordHandler(self, EnglishParser.handleDefining),
            Term.Name("subtype"): KeywordHandler(self, EnglishParser.handleSubtype),
            
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
        ],
        resourceTypes: [
            Term.Name("system"): (false, [], .system),
            Term.Name("app"): (true, [], .applicationByName),
            Term.Name("app id"): (true, [], .applicationByID),
            Term.Name("library"): (true, [], .libraryByName),
            Term.Name("AppleScript"): (true, ["at"], .applescriptAtPath),
        ],
        operators: SourceParserConfig.Operators(
            prefix: [
                Term.Name("not"): .not,
                Term.Name("-"): .negate
            ],
            postfix: [:],
            infix: [
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
                Term.Name("div"): .divide,
                Term.Name("÷"): .divide,
                Term.Name("as"): .coerce,
            ]
        ),
        delimiters: SourceParserConfig.Delimiters(
            suffixSpecifier: [
                Term.Name("->"),
                Term.Name("→")
            ],
            string: [
                (begin: Term.Name("\""), end: Term.Name("\"")),
                (begin: Term.Name("“"), end: Term.Name("”"))
            ],
            expressionGrouping: [
                (begin: Term.Name("("), end: Term.Name(")"))
            ],
            list: [],
            record: [],
            listAndRecord: [
                (begin: Term.Name("{"), end: Term.Name("}"), itemSeparators: [Term.Name(",")], keyValueSeparators: [Term.Name(":")])
            ],
            lineComment: [
                Term.Name("--")
            ],
            blockComment: [
                (begin: Term.Name("--("), end: Term.Name(")--"))
            ]
        )
    )
    
    public init() {
    }
    
    private func handleFunctionStart() throws -> Expression.Kind? {
        guard let functionName = try parseTermNameEagerly(styling: .command) else {
            throw ParseError(.missing([.functionName]), at: SourceLocation(state.source.range, source: state.entireSource))
        }
        
        try eatLineBreakOrThrow()
        
        var commandTerm: Term?
        var parameters: [Term] = []
        var types: [Expression?] = []
        var arguments: [Term] = []
        let body = try withScope {
            while
                ({ eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true); return true }()),
                !isNext("do"),
                let parameterTermName = try parseTermNameEagerly(stoppingAt: ["[", "(", ":"], styling: .parameter)
            {
                let parameterTermURI = try eatTermURI(.parameter) ?? .id(Term.SemanticURI.Pathname([parameterTermName.normalized]))
                parameters.append(Term(.parameter, parameterTermURI, name: parameterTermName))
                
                let argumentName: Term.Name = try {
                    if tryEating(prefix: "(", spacing: .left) {
                        let name = try parseTermNameEagerly(stoppingAt: [")"], styling: .variable) ?? parameterTermName
                        try eatOrThrow(prefix: ")", spacing: .right)
                        return name
                    } else {
                        return parameterTermName
                    }
                }()
                arguments.append(Term(.variable, state.lexicon.makeIDURI(forName: argumentName), name: argumentName))
                
                if
                    tryEating(prefix: ":", spacing: .right),
                    let type = try parsePrimary()
                {
                    types.append(type)
                } else {
                    types.append(nil)
                }
                
                if !(tryEatingLineBreak() || tryEating(prefix: ",", spacing: .right)) {
                    break
                }
            }
            eatCommentsAndWhitespace(eatingNewlines: true)
            try eatOrThrow(prefix: "do")
            
            // Define command term (and parameter terms) outside
            // the function scope before parsing body:
            let functionScope = state.lexicon.top
            state.lexicon.pop()
            commandTerm = state.lexicon.lookUpOrDefine(.command, name: functionName, dictionary: TermDictionary(contents: parameters))
            state.lexicon.push(functionScope)
            
            try eatLineBreakOrThrow(.toBeginBlock("function body"))
            state.lexicon.add(Set(arguments))
            return try parseSequence()
        }
        
        return .function(name: commandTerm!, parameters: parameters, types: types, arguments: arguments, body: body)
    }
    
    private func handleBlockArgumentNamesStart() throws -> Expression.Kind? {
        var arguments: [Term] = []
        let body = try withScope {
            while let argumentName = try parseTermNameEagerly(stoppingAt: [",", "do"], styling: .variable) {
                arguments.append(Term(.variable, state.lexicon.makeIDURI(forName: argumentName), name: argumentName))
                
                if !tryEating(prefix: ",", spacing: .right) {
                    break
                }
            }
            
            state.lexicon.add(Set(arguments))
            
            guard tryEating(prefix: "do") else {
                throw ParseError(.missing([.blockBody]), at: expressionLocation)
            }
            
            return try parseBlockBody(arguments: [])
        }
        return .block(arguments: arguments, body: body)
    }
    
    private func handleBlockBodyStart() throws -> Expression.Kind? {
        let body = try withScope {
            try parseBlockBody(arguments: [])
        }
        return Expression.Kind.block(arguments: [], body: body)
    }
    
    private func parseBlockBody(arguments: [Term]) throws -> Expression {
        if tryEatingLineBreak() {
            return try parseSequence()
        } else {
            guard let expression = try parsePrimary() else {
                throw ParseError(.missing([.blockBody]), at: expressionLocation)
            }
            return expression
        }
    }
    
    private func handleTry() throws -> Expression.Kind? {
        func parseBody() throws -> Expression {
            let foundNewline = tryEatingLineBreak()
            if foundNewline {
                let body = try parseSequence(stoppingAt: [Term.Name(["handle"])])
                guard state.lastEndKeyword == Term.Name(["handle"]) else {
                    throw ParseError(.missing([.keyword(Term.Name(["handle"]))]), at: currentLocation)
                }
                return body
            } else {
                guard let bodyExpression = try parsePrimary() else {
                    throw ParseError(.missing([.expression, .lineBreak], .afterKeyword(Term.Name(["try"]))), at: currentLocation)
                }
                return bodyExpression
            }
        }
        
        func parseHandle() throws -> Expression {
            if tryEatingLineBreak() {
                return try parseSequence()
            } else {
                guard let handleExpression = try parsePrimary() else {
                    throw ParseError(.missing([.expression, .lineBreak], .afterKeyword(Term.Name(["handle"]))), at: currentLocation)
                }
                eatCommentsAndWhitespace()
                return handleExpression
            }
        }
        
        return .try_(body: try parseBody(), handle: try parseHandle())
    }
    
    private func handleIf() throws -> Expression.Kind? {
        let condition = try parsePrimaryOrThrow(.afterKeyword(Term.Name(["if"])))
        if tryEatingLineBreak() {
            let then = try parseSequence(stoppingAt: [Term.Name(["else"])])
            let rollbackSource = state.source
            let rollbackElements = state.elements
            if state.lastEndKeyword == Term.Name(["else"]) {
                if tryEatingLineBreak() {
                    return .if_(condition: condition, then: then, else: try parseSequence())
                } else {
                    guard let `else` = try parsePrimary() else {
                        throw ParseError(.missing([.expression, .lineBreak], .afterKeyword(Term.Name(["else"]))), at: currentLocation)
                    }
                    eatCommentsAndWhitespace()
                    return .if_(condition: condition, then: then, else: `else`)
                }
            } else {
                state.source = rollbackSource
                state.elements = rollbackElements
                return .if_(condition: condition, then: then, else: nil)
            }
        } else if tryEating(prefix: "then") {
            let then = try parsePrimaryOrThrow()
            if tryEating(prefix: "else") {
                eatCommentsAndWhitespace(eatingNewlines: true, isSignificant: true)
                return .if_(condition: condition, then: then, else: try parsePrimaryOrThrow())
            } else {
                return .if_(condition: condition, then: then, else: nil)
            }
        } else {
            throw ParseError(.missing([.keyword(Term.Name(["then"])), .lineBreak]), at: currentLocation)
        }
    }
    
    private func handleRepeat() throws -> Expression.Kind? {
        func parseRepeatBlock() throws -> Expression {
            try eatLineBreakOrThrow(.toBeginBlock("repeat"))
            return try parseSequence()
        }
        
        if tryEating(prefix: "while") {
            let condition = try parsePrimaryOrThrow()
            return .repeatWhile(condition: condition, repeating: try parseRepeatBlock())
        } else if tryEating(prefix: "for") {
            let variableTerm = try parseVariableTermOrThrow(stoppingAt: ["in"])
            try eatOrThrow(prefix: "in")
            let expression = try parsePrimaryOrThrow(.afterKeyword(Term.Name(["in"])))
            state.lexicon.add(variableTerm)
            return .repeatFor(variable: variableTerm, container: expression, repeating: try parseRepeatBlock())
        } else {
            let times = try parsePrimaryOrThrow()
            try eatOrThrow(prefix: "times")
            return .repeatTimes(times: times, repeating: try parseRepeatBlock())
        }
    }
    
    private func handleTell() throws -> Expression.Kind? {
        let target = try parsePrimaryOrThrow(.afterKeyword(Term.Name(["tell"])))
        
        let foundTo = tryEating(prefix: "to")
        let foundNewline = tryEatingLineBreak()
        guard foundTo && !foundNewline || !foundTo && foundNewline else {
            throw ParseError(.missing([.expression, .lineBreak], .adHoc("after target expression")), at: currentLocation, fixes: [SuggestingFix(suggesting: "{FIX} to evaluate a single targeted expression", by: AppendingFix(appending: " to", at: currentLocation)), SuggestingFix(suggesting: "{FIX} to evaluate a targeted sequence of expressions", by: AppendingFix(appending: "\n", at: currentLocation))])
        }
        
        return try withTerminology(of: target) {
            let body = try foundNewline ? parseSequence() : parsePrimaryOrThrow(.afterKeyword(Term.Name(["to"])))
            return .tell(target: target, to: body)
        }
    }
    
    private func handleLet() throws -> Expression.Kind? {
        let term = try parseVariableTermOrThrow(stoppingAt: ["be"], .afterKeyword(Term.Name(["let"])))
        let initialValue: Expression? = tryEating(prefix: "be") ? try parsePrimaryOrThrow(.afterKeyword(Term.Name(["be"]))) : nil
        state.lexicon.add(term)
        return .let_(term, initialValue: initialValue)
    }
    
    private func parseDefineLine() throws -> (term: Term, uri: TermSemanticURIProvider?) {
        guard let role = eatTermRoleName() else {
            throw ParseError(.missing([.termRole]), at: currentLocation)
        }
        let name = try parseTermNameEagerlyOrThrow(stoppingAt: ["as"], styling: Styling(for: role))
        let uriProvider: TermSemanticURIProvider = try { () -> TermSemanticURIProvider? in
            guard tryEating(prefix: "as") else {
                return nil
            }
            return try eatTermURI(Styling(for: role)) ?? eatTermOrThrow()
        }() ?? state.lexicon.makeIDURI(forName: name)
        
        let term = Term(role, uriProvider.uri, name: name)
        state.lexicon.add(term)
        
        return (term: term, uri: uriProvider)
    }
    
    private func handleDefine() throws -> Expression.Kind? {
        let (term: term, uri: uri) = try parseDefineLine()
        return .define(term, as: uri)
    }
    
    private func handleDefining() throws -> Expression.Kind? {
        let (term: term, uri: uri) = try parseDefineLine()
        let body = try withTerminology(of: term) {
            try parseSequence()
        }
        return .defining(term, as: uri, body: body)
    }
    
    private func handleSubtype() throws -> Expression.Kind? {
        func eatURIProvider() throws -> TermSemanticURIProvider {
            try eatTermURI(Styling(for: .type)) ??
                eatTermOrThrow()
        }
        let subtype = try eatURIProvider()
        try eatOrThrow(prefix: "from")
        let supertype = try eatURIProvider()
        return .subtype(subtype, of: supertype)
    }
    
    private func handleSet() throws -> Expression.Kind? {
        let destinationExpression = try parsePrimaryOrThrow(.afterKeyword(Term.Name(["set"])))
        try eatOrThrow(prefix: "to")
        let newValueExpression = try parsePrimaryOrThrow(.afterKeyword(Term.Name(["to"])))
        return .set(destinationExpression, to: newValueExpression)
    }
    
    private func handleQuantifier(_ kind: Specifier.Kind) -> KeywordHandler {
        KeywordHandler(self) { self_ in
            {
                try self_.parseSpecifierAfterQuantifier(kind: kind)
            }
        }
    }
    
    private func handleInsertionLocation(_ kind: InsertionSpecifier.Kind) -> KeywordHandler {
        KeywordHandler(self) { self_ in
            {
                try self_.parseInsertionSpecifierAfterInsertionLocation(kind: kind)
            }
        }
    }
    
    public func handle(term: Term) throws -> Expression.Kind? {
        switch term.role {
        case .constant: // MARK: .constant
            return .enumerator(term)
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
                guard let parameterTerm = try eatTerm(from: term.dictionary, role: .parameter) else {
                    return false
                }
                let parameterValue = try parsePrimaryOrThrow(.adHoc("parameter name"))
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
                if !(state.source.first?.isNewline ?? true) {
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
            throw ParseError(.wrongTermRoleForContext, at: expressionLocation)
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
        guard let firstWord = Term.Name.nextWord(in: state.source) else {
            return nil
        }
        
        switch firstWord {
        case "index":
            addingElement {
                state.source.removeFirst(firstWord.count)
            }
            return try parsePrimary(allowSuffixSpecifier: false).map { dataExpression in
                return .index(dataExpression)
            }
        case "named":
            addingElement {
                state.source.removeFirst(firstWord.count)
            }
            return try parsePrimary(allowSuffixSpecifier: false).map { dataExpression in
                return .name(dataExpression)
            }
        case "id":
            addingElement {
                state.source.removeFirst(firstWord.count)
            }
            return try parsePrimary(allowSuffixSpecifier: false).map { dataExpression in
                return .id(dataExpression)
            }
        case "whose", "where":
            addingElement {
                state.source.removeFirst(firstWord.count)
            }
            return try parsePrimary(allowSuffixSpecifier: false).map { expression in
                return .test(expression, expression.asTestPredicate())
            }
        default:
            guard
                !(state.source.first?.isNewline ?? false),
                let firstExpression = try? parsePrimary(allowSuffixSpecifier: false)
            else {
                return nil
            }
            
            eatCommentsAndWhitespace()
            let midWord = Term.Name.nextWord(in: state.source)
            
            switch midWord {
            case "thru", "through":
                addingElement {
                    state.source.removeFirst(midWord!.count)
                }
                return try parsePrimary(allowSuffixSpecifier: false).map { secondExpression in
                    return .range(from: firstExpression, to: secondExpression)
                }
            default:
                return .simple(firstExpression)
            }
        }
    }
    
    public func parseRelativeSpecifierAfterTypeName(_ typeTerm: Term) throws -> Specifier? {
        if tryEating(prefix: "before") {
            let parentExpression = try parsePrimaryOrThrow(.afterKeyword(Term.Name(["before"])), allowSuffixSpecifier: false)
            return Specifier(term: typeTerm, kind: .previous, parent: parentExpression)
        } else if tryEating(prefix: "after") {
            let parentExpression = try parsePrimaryOrThrow(.afterKeyword(Term.Name(["after"])), allowSuffixSpecifier: false)
            return Specifier(term: typeTerm, kind: .next, parent: parentExpression)
        } else {
            return nil
        }
    }
    
    public func parseSpecifierAfterQuantifier(kind: Specifier.Kind) throws -> Expression.Kind? {
        .specifier(Specifier(term: try parseTypeTermOrThrow(), kind: kind))
    }
    
    public func parseInsertionSpecifierAfterInsertionLocation(kind: InsertionSpecifier.Kind) throws -> Expression.Kind? {
        .insertionSpecifier(InsertionSpecifier(kind: kind, parent: try parsePrimary(allowSuffixSpecifier: false)))
    }
    
    public func tryParseSpecifierPhrase(chainingTo chainTo: Expression) throws -> Expression.Kind? {
        guard
            let childSpecifier = chainTo.asSpecifier(),
            tryEating(prefix: "of")
        else {
            return try tryParseSuffixSpecifier(chainingTo: chainTo)
        }
        
        // Add new parent to top of specifier chain
        // e.g., character 1 of "hello"
        // First expression (chainTo) must be a specifier since it is the child
        
        let parentExpression = try parsePrimaryOrThrow(.afterKeyword(Term.Name(["of"])), allowSuffixSpecifier: false)
        childSpecifier.setRootAncestor(parentExpression)
        return .specifier(childSpecifier)
    }
    
    public func tryParseSuffixSpecifier(chainingTo chainTo: Expression) throws -> Expression.Kind? {
        guard state.allowSuffixSpecifierStack.last! else {
            return nil
        }
        guard let keyword = eatSuffixSpecifierMarker() else {
            return nil
        }
        
        // Add new child to bottom of specifier chain
        // e.g., "hello" -> first character
        // Second expression (the one about to be parsed) must be a specifier since
        // it is the child
         
        let newChildExpression = try parsePrimaryOrThrow(.adHoc("after possessive"), allowSuffixSpecifier: false)
        guard let newChildSpecifier = newChildExpression.asSpecifier() else {
            // e.g., "hello" -> 123
            throw ParseError(.missing([.specifier], .afterKeyword(keyword)), at: newChildExpression.location)
        }
        newChildSpecifier.parent = chainTo
        return .specifier(newChildSpecifier)
    }
    
}

import BushelLanguage
import Bushel
import SDEFinitely

public final class EnglishParser: BushelLanguage.SourceParser {
    
    public var entireSource: String
    public var source: Substring
    public var expressionStartIndex: String.Index
    public var lexicon: Lexicon = Lexicon()
    public var currentElements: [[PrettyPrintable]] = []
    
    public init(source: String) {
        self.entireSource = source
        self.source = Substring(source)
        self.expressionStartIndex = source.startIndex
        
        lexicon.push(name: TermName("BushelScript"))
    }
    
    private lazy var mathDictionary: [TermDescriptor] = [
        PropertyDescriptor(.math_pi, name: TermName("pi")),
        PropertyDescriptor(.math_e, name: TermName("e")),
        
        CommandDescriptor(.math_abs, name: TermName("absolute value"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_abs, name: TermName("abs"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_sqrt, name: TermName("square root"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_sqrt, name: TermName("sqrt"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_cbrt, name: TermName("cube root"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_cbrt, name: TermName("cubed root"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_cbrt, name: TermName("cbrt"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_square, name: TermName("square"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_square, name: TermName("squared"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_cube, name: TermName("cube"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_cube, name: TermName("cubed"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of"))
        ]),
        CommandDescriptor(.math_pow, name: TermName("power"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of")),
            ParameterDescriptor(.math_pow_exponent, name: TermName("to the"))
        ]),
        CommandDescriptor(.math_pow, name: TermName("pow"), parameters: [
            ParameterDescriptor(.direct, name: TermName("of")),
            ParameterDescriptor(.math_pow_exponent, name: TermName("to the"))
        ]),
    ]
    
    private lazy var sequenceDictionary: [TermDescriptor] = [
    ]
    
    private lazy var guiDictionary: [TermDescriptor] = [
        CommandDescriptor(.gui_notification, name: TermName("notification"), parameters: [
            ParameterDescriptor(.direct, name: TermName("message")),
            ParameterDescriptor(.gui_notification_title, name: TermName("title")),
            ParameterDescriptor(.gui_notification_subtitle, name: TermName("subtitle")),
            ParameterDescriptor(.gui_notification_sound, name: TermName("sound"))
        ]),
        CommandDescriptor(.gui_alert, name: TermName("alert"), parameters: [
            ParameterDescriptor(.direct, name: TermName("heading")),
            ParameterDescriptor(.gui_alert_message, name: TermName("message")),
            ParameterDescriptor(.gui_alert_kind, name: TermName("kind")),
            ParameterDescriptor(.gui_alert_buttons, name: TermName("buttons")),
            ParameterDescriptor(.gui_alert_default, name: TermName("default")),
            ParameterDescriptor(.gui_alert_cancel, name: TermName("cancel")),
            ParameterDescriptor(.gui_alert_timeout, name: TermName("timeout")),
        ]),
    ]
    
    private lazy var cliDictionary: [TermDescriptor] = [
        CommandDescriptor(.cli_log, name: TermName("log"), parameters: [
            ParameterDescriptor(.direct, name: TermName("message"))
        ]),
    ]
    
    public lazy var defaultTerms: [TermDescriptor] = [
        PropertyDescriptor(.properties, name: TermName("properties")),
        PropertyDescriptor(.index, name: TermName("index")),
        PropertyDescriptor(.name, name: TermName("name")),
        PropertyDescriptor(.id, name: TermName("id")),
        
        ConstantDescriptor(.true, name: TermName("true")),
        ConstantDescriptor(.false, name: TermName("false")),
        
        TypeDescriptor(TypeUID.list, name: TermName("list")),
        PropertyDescriptor(.sequence_length, name: TermName("length")),
        PropertyDescriptor(.sequence_reverse, name: TermName("reverse")),
        PropertyDescriptor(.sequence_tail, name: TermName("tail")),
        
        TypeDescriptor(.item, name: TermName("item")),
        TypeDescriptor(.record, name: TermName("record")),
        TypeDescriptor(.string, name: TermName("string")),
        TypeDescriptor(.character, name: TermName("character")),
        TypeDescriptor(.integer, name: TermName("integer")),
        TypeDescriptor(.real, name: TermName("real")),
        TypeDescriptor(.window, name: TermName("window")),
        TypeDescriptor(.document, name: TermName("document")),
        TypeDescriptor(.file, name: TermName("file")),
        TypeDescriptor(.alias, name: TermName("alias")),
        TypeDescriptor(.application, name: TermName("application")),
        
        CommandDescriptor(.run, name: TermName("run"), parameters: [
        ]),
        CommandDescriptor(.reopen, name: TermName("reopen"), parameters: [
        ]),
        CommandDescriptor(CommandUID.open, name: TermName("open"), parameters: [
            ParameterDescriptor(.open_searchText, name: TermName("search text"))
        ]),
        CommandDescriptor(.print, name: TermName("print"), parameters: [
        ]),
        CommandDescriptor(.quit, name: TermName("quit"), parameters: [
        ]),
        
        DictionaryDescriptor("bushel.dictionary.math", name: TermName("Math"), contents: mathDictionary),
        DictionaryDescriptor("bushel.dictionary.sequence", name: TermName("Sequence"), contents: sequenceDictionary),
        DictionaryDescriptor("bushel.dictionary.gui", name: TermName("GUI"), contents: guiDictionary),
        DictionaryDescriptor("bushel.dictionary.cli", name: TermName("CLI"), contents: cliDictionary),
    ]
    
    public let binaryOperators: [TermName : BinaryOperation] = [
        TermName("+"): .add,
        TermName("-"): .subtract,
        TermName("*"): .multiply,
        TermName("/"): .divide,
        TermName("&"): .concatenate
    ]
    
    public lazy var keywords: [TermName : KeywordHandler] = [
        TermName("("): handleOpenParenthesis,
        TermName("{"): handleOpenBrace,
        TermName("on"): handleFunctionStart,
        TermName("to"): handleFunctionStart,
        TermName("if"): handleIf,
        TermName("repeat"): handleRepeat,
        TermName("repeating"): handleRepeat,
        TermName("tell"): handleTell,
        TermName("end"): {
            .end
        },
        TermName("end if"): {
            // TODO: Check we're ending an ‘if’-block
            .end
        },
        TermName("end tell"): {
            // TODO: Check we're ending a ‘tell’-block
            .end
        },
        TermName("let"): handleLet,
        TermName("return"): {
            .return_(try self.parsePrimary())
        },
        TermName("use application"): handleUseApplication,
        TermName("use app"): handleUseApplication,
        TermName("that"): {
            .that
        },
        TermName("it"): {
            .it
        },
        TermName("every"): {
            try self.parseSpecifierAfterQuantifier(kind: .all, startIndex: self.expressionStartIndex)
        },
        TermName("all"): {
            try self.parseSpecifierAfterQuantifier(kind: .all, startIndex: self.expressionStartIndex)
        },
        TermName("first"): {
            try self.parseSpecifierAfterQuantifier(kind: .first, startIndex: self.expressionStartIndex)
        },
        TermName("front"): {
            try self.parseSpecifierAfterQuantifier(kind: .first, startIndex: self.expressionStartIndex)
        },
        TermName("middle"): {
            try self.parseSpecifierAfterQuantifier(kind: .middle, startIndex: self.expressionStartIndex)
        },
        TermName("last"): {
            try self.parseSpecifierAfterQuantifier(kind: .last, startIndex: self.expressionStartIndex)
        },
        TermName("back"): {
            try self.parseSpecifierAfterQuantifier(kind: .last, startIndex: self.expressionStartIndex)
        },
        TermName("some"): {
            try self.parseSpecifierAfterQuantifier(kind: .random, startIndex: self.expressionStartIndex)
        },
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
        TermName("null"): {
            .null
        }
    ]
    
    private func handleOpenParenthesis() throws -> Expression.Kind? {
        guard let enclosed = try parsePrimary() else {
            throw ParseError(description: "expected expression after ‘(’", location: SourceLocation(source.range, source: entireSource))
        }
        guard tryEating(prefix: ")") else {
            throw ParseError(description: "expected ‘)’ after bracketed-expression", location: SourceLocation(source.range, source: entireSource))
        }
        
        return .parentheses(enclosed)
    }
    
    private func handleOpenBrace() throws -> Expression.Kind? {
        var items: [Expression] = []
        while let item = try parsePrimary() {
            items.append(item)
            if tryEating(prefix: "}") {
                break
            }
            guard tryEating(prefix: ",") else {
                throw ParseError(description: "expected ‘,’ or ‘}’ after list item", location: currentLocation)
            }
        }
        
        return .list(items)
    }
    
    private func handleFunctionStart() throws -> Expression.Kind? {
        guard let (termName, termLocation) = try parseTermNameEagerly(stoppingAt: [":"]) else {
            throw ParseError(description: "expected function name", location: SourceLocation(source.range, source: entireSource))
        }
        let functionNameTerm = Located(VariableTerm(lexicon.makeUID("variable", termName), name: termName), at: termLocation)
        
        var parameters: [Located<ParameterTerm>] = []
        var arguments: [Located<VariableTerm>] = []
        if tryEating(prefix: ":") {
            while let (parameterTermName, parameterTermLocation) = try parseTermNameLazily() {
                parameters.append(Located(ParameterTerm(lexicon.makeUID("parameter", termName, parameterTermName), name: parameterTermName, code: nil), at: parameterTermLocation))
                
                var (argumentName, argumentLocation) = try parseTermNameEagerly(stoppingAt: [","]) ?? (parameterTermName, parameterTermLocation)
                if argumentName.words.isEmpty {
                    (argumentName, argumentLocation) = (parameterTermName, parameterTermLocation)
                }
                arguments.append(Located(VariableTerm(lexicon.makeUID("variable", termName, argumentName), name: argumentName), at: argumentLocation))
                
                if !tryEating(prefix: ",") {
                    break
                }
            }
        }
        
        let parameterTerms = Set(parameters.map { $0.term })
        
        let commandTerm = CommandTerm(lexicon.makeUID("command", termName), name: termName, codes: nil, parameters: ParameterTermDictionary(contents: parameterTerms))
        lexicon.add(commandTerm)
        
        guard tryEating(prefix: "\n") else {
            throw ParseError(description: "expected line break to begin function body", location: currentLocation)
        }
        let body = try withScope {
            lexicon.add(Set(arguments.map { $0.term }))
            return try parseSequence() ?? Sequence.empty(at: currentIndex)
        }
        
        return .function(name: functionNameTerm, parameters: parameters, arguments: arguments, body: body)
    }
    
    private func handleIf() throws -> Expression.Kind? {
        guard let condition = try parsePrimary() else {
            throw ParseError(description: "expected condition-expression after ‘if’", location: currentLocation)
        }
        
        let thenStartIndex = currentIndex
        let foundThen = tryEating(prefix: "then")
        let foundNewline = tryEating(prefix: "\n")
        guard foundThen || foundNewline else {
            throw ParseError(description: "expected ‘then’ or line break after condition-expression to begin ‘if’-block", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation), AppendingFix(appending: " then", at: currentLocation)])
        }
        
        let thenExpr: Expression
        if foundNewline {
            thenExpr = try withScope {
                return try parseSequence(stoppingAt: ["else"]) ?? Sequence.empty(at: currentIndex)
            }
        } else {
            guard let thenExpression = try parsePrimary() else {
                let thenLocation = SourceLocation(thenStartIndex..<currentIndex, source: entireSource)
                throw ParseError(description: "expected expression or line break following ‘then’ to begin ‘if’-block", location: thenLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it when the condition is true", at: [currentLocation]), SuggestingFix(suggesting: "{FIX} to evaluate a sequence of expressions when the condition is true", by: AppendingFix(appending: "\n", at: thenLocation))])
            }
            self.source.removeLeadingWhitespace(removingNewlines: true)
            thenExpr = thenExpression
        }
        
        let elseExpr = try self.parseElse()
        
        return .if_(condition: condition, then: thenExpr, else: elseExpr)
    }
    
    private func handleRepeat() throws -> Expression.Kind? {
        guard let times = try parsePrimary() else {
            throw ParseError(description: "expected times-expression after ‘\(expressionLocation.snippet(in: entireSource))’", location: currentLocation)
        }
        
        guard tryEating(prefix: "times") else {
            throw ParseError(description: "expected ‘times’ after times-expression", location: currentLocation, fixes: [AppendingFix(appending: " times", at: currentLocation)])
        }
        guard tryEating(prefix: "\n") else {
            throw ParseError(description: "expected line break after ‘times’ to begin ‘repeat’-block", location: currentLocation, fixes: [AppendingFix(appending: "\n", at: currentLocation)])
        }
        
        let repeatingBlock = try withScope {
            return try parseSequence() ?? Sequence.empty(at: currentIndex)
        }
        
        return .repeatTimes(times: times, repeating: repeatingBlock)
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
        
        noTerminology: do {
            let appBundle: Bundle
            switch target.kind {
            case .specifier(let specifier):
                guard
                    let code = (specifier.idTerm.term as? Bushel.ClassTerm)?.code,
                    code == cApplication
                else {
                    break noTerminology
                }
                
                switch specifier.kind {
                case .simple(let dataExpression), .name(let dataExpression):
                    guard case .string(let name) = dataExpression.kind else {
                        break noTerminology
                    }
                    guard let bundle = Bundle(applicationName: name) else {
                        throw ParseError(description: "no application found with name ‘\(name)’", location: target.location)
                    }
                    appBundle = bundle
                case .id(let dataExpression):
                    guard case .string(let bundleID) = dataExpression.kind else {
                        break noTerminology
                    }
                    guard let bundle = Bundle(applicationBundleIdentifier: bundleID) else {
                        throw ParseError(description: "no application found for bundle identifier ‘\(bundleID)’", location: target.location)
                    }
                    appBundle = bundle
                default:
                    break noTerminology
                }
                
                let sdef: Data
                do {
                    sdef = try SDEFinitely.readSDEF(from: appBundle.bundleURL)
                } catch is SDEFError {
                    // No terminology available
                    break
                }
                
                let dictionary = lexicon.push()
                dictionary.add(try Bushel.parse(sdef: sdef, under: lexicon))
            case .use(let resource),
                 .resource(let resource):
                switch resource {
                case .applicationByName(let term as LocatedTerm),
                     .applicationByID(let term as LocatedTerm):
                    lexicon.push(name: term.name)
                }
            default:
                break noTerminology
            }
        } catch let error as ParseError {
            throw error
        } catch {
            throw ParseError(description: "an error occurred while retrieving terminology: \(error)", location: target.location)
        }
        
        let toExpr: Expression
        if foundNewline {
            toExpr = try withScope {
                return try parseSequence() ?? Sequence.empty(at: currentIndex)
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
    
    private func handleLet() throws -> Expression.Kind? {
        guard let (termName, termLocation) = try parseTermNameEagerly(stoppingAt: ["be"]) else {
            throw ParseError(description: "expected variable name following ‘let’", location: SourceLocation(source.range, source: entireSource))
        }
        let term = Located(VariableTerm(lexicon.makeUID("variable", termName), name: termName), at: termLocation)
        
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
        source.removeLeadingWhitespace()
        guard !source.hasPrefix("\"") else {
            throw ParseError(description: "‘use application’ takes a raw application name, not a string, since it binds a constant; remove the quotation marks", location: currentLocation)
        }
        
        let byBundleID = tryEating(prefix: "id")
        
        let nameStartIndex = currentIndex
        guard let (name, nameLocation) = try parseTermNameEagerly() else {
            throw ParseError(description: "expected application name", location: SourceLocation(source.range, source: entireSource))
        }
        guard let bundle = byBundleID ? Bundle(applicationBundleIdentifier: name.normalized) : Bundle(applicationName: name.normalized) else {
            throw ParseError(description: "this script requires \(byBundleID ? "an application with identifier" : "the application") “\(name)”, which was not found on your system", location: SourceLocation(nameStartIndex..<currentIndex, source: entireSource))
        }
        
        let term: Term & TermDictionaryDelayedInitContainer
        let locatedTerm: LocatedTerm
        let resource: Resource
        if byBundleID {
            let idTerm = Located(ApplicationIDTerm(name.normalized, name: name, bundle: bundle), at: nameLocation)
            term = idTerm.term
            locatedTerm = idTerm
            resource = .applicationByID(idTerm)
        } else {
            let nameTerm = Located(ApplicationNameTerm(name.normalized, name: name, bundle: bundle), at: nameLocation)
            term = nameTerm.term
            locatedTerm = nameTerm
            resource = .applicationByName(nameTerm)
        }
        
        lexicon.add(locatedTerm)
        
        let sdef: Data
        do {
            sdef = try SDEFinitely.readSDEF(from: bundle.bundleURL)
        } catch is SDEFError {
            // No terminology available
            return .use(resource: resource)
        }
        
        let dictionary = term.makeDictionary(under: lexicon.pool)
        dictionary.add(try Bushel.parse(sdef: sdef, under: lexicon))
        
        return .use(resource: resource)
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
    
    public func handle(term: LocatedTerm) throws -> Expression.Kind? {
        let termLocation = term.location
        switch term.wrappedTerm.enumerated {
        case .enumerator(let term):
            return .enumerator(term)
        case .dictionary(let term):
            // FIXME: unimplemented
            return .null
        case .class_(let term):
            if let specifierKind = try parseSpecifierAfterClassName() {
                return .specifier(Specifier(class: Located(term, at: termLocation), kind: specifierKind))
            } else {
                // Just the class name
                return .class_(term)
            }
        case .property(let term):
            let specifier = Specifier(class: Located(term, at: expressionLocation), kind: .property)
            return .specifier(specifier)
        case .command(let term):
            let termLocation = expressionLocation
            
            var parameters: [(Located<ParameterTerm>, Expression)] = []
            func parseParameter() throws -> Bool {
                guard case let (parameterTermString, parameterTerm?) = try term.parameters.findTerm(in: source) else {
                    return false
                }
                source.removeFirst(parameterTermString.count)
                let locatedParamterTerm = Located(parameterTerm, at: SourceLocation(parameterTermString.range, source: entireSource))
                
                guard let parameterValue = try parsePrimary() else {
                    throw ParseError(description: "expected expression after parameter name, but found end of script", location: currentLocation)
                }
                parameters.append((locatedParamterTerm, parameterValue))
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
                source.removeLeadingWhitespace()
                if !(source.first?.isNewline ?? true) {
                    // Direct parameter
                    let directParameterLocation = currentLocation
                    guard let directParameterValue = try parsePrimary() else {
                        throw ParseError(description: "expected parameter name or direct parameter expression", location: currentLocation)
                    }
                    parameters.append((Located(lexicon.pool.term(forID: ParameterUID.direct.rawValue) as! ParameterTerm, at: directParameterLocation), directParameterValue))
                }
            }
            
            // Parse remaining named parameters
            while try parseParameter() {
            }
            
            return result()
        case .parameter:
            throw ParseError(description: "parameter term outside of a command invocation", location: expressionLocation)
        case .variable(let term):
            return .variable(term)
        case .applicationName(let term):
            return .resource(.applicationByName(Located(term, at: expressionLocation)))
        case .applicationID(let term):
            return .resource(.applicationByID(Located(term, at: expressionLocation)))
        }
    }
    
    public func postprocess(primary: Expression) throws -> Expression.Kind? {
        // There might be a possessive ('s) after
        return try tryParseSpecifierPhrase(chainingTo: primary)
    }
    
    public func parseElse() throws -> Expression? {
        let elseStartIndex = currentIndex
        guard tryEating(prefix: "else") else {
            return nil
        }
        if tryEating(prefix: "\n") {
            return try withScope {
                return try parseSequence() ?? Sequence.empty(at: currentIndex)
            }
        } else {
            guard let elseExpr = try parsePrimary() else {
                let elseLocation = SourceLocation(elseStartIndex..<currentIndex, source: entireSource)
                throw ParseError(description: "expected expression or line break following ‘else’ to begin ‘else’-block", location: elseLocation, fixes: [SuggestingFix(suggesting: "add an expression to evaluate it when the condition is true", by: AppendingFix(appending: " <#expression#>", at: currentLocation)), SuggestingFix(suggesting: "{FIX} to evaluate a sequence of expressions when the condition is true", by: AppendingFix(appending: "\n", at: elseLocation))])
            }
            source.removeLeadingWhitespace()
            return elseExpr
        }
    }
    
    public func parseSpecifierAfterClassName() throws -> Specifier.Kind? {
        source.removeLeadingWhitespace()
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
            return try parsePrimary().map { predicate in
                return .test(predicate: predicate)
            }
        default:
            source.removeLeadingWhitespace()
            guard
                !source.hasPrefix("\n"),
                let firstExpression = try? parsePrimary()
            else {
                return nil
            }
            
            source.removeLeadingWhitespace()
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
    
    public func parseSpecifierAfterQuantifier(kind: Specifier.Kind, startIndex: Substring.Index) throws -> Expression.Kind? {
        guard
            let classExpression = try parsePrimary(),
            case .class_(let term) = classExpression.kind
        else {
            throw ParseError(description: "expected class name", location: currentLocation)
        }
        
        let specifier = Specifier(class: Located(term, at: classExpression.location), kind: kind)
        return .specifier(specifier)
    }
    
    public func tryParseSpecifierPhrase(chainingTo chainTo: Expression) throws -> Expression.Kind? {
        if
            case .specifier(let childSpecifier) = chainTo.kind,
            tryEating(prefix: "of") || tryEating(prefix: "in")
        {
            // Add new parent to top of specifier chain
            // e.g., character 1 of "hello"
            // First expression (chainTo) must be a specifier since it is the child
            
            guard let parentExpression = try parsePrimary() else {
                // e.g., character 1 of
                throw ParseError(description: "expected expression after ‘of’, but found end of script", location: currentLocation)
            }
            
            let prevTopExpression = childSpecifier.topParent() ?? chainTo
            guard case .specifier(let prevTopSpecifier) = prevTopExpression.kind else {
                // e.g., "hello" of application "Safari"
                throw ParseError(description: "a non-specifier expression may only come last in an ‘of’-specifier-phrase", location: prevTopExpression.location)
            }
            
            prevTopSpecifier.parent = parentExpression
            return .specifier(childSpecifier)
        } else {
            return try tryParseSuffixSpecifier(chainingTo: chainTo)
        }
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
        
        guard case .specifier(let newChildSpecifier) = newChildExpression.kind else {
            // e.g., "hello"'s 123
            throw ParseError(description: "a non-specifier expression may only come first in a possessive-specifier-phrase", location: newChildExpression.location)
        }
        
        newChildSpecifier.parent = chainTo
        return .specifier(newChildSpecifier)
    }
    
}

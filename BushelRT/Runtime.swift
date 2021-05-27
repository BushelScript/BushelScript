import Bushel
import os

private let log = OSLog(subsystem: logSubsystem, category: "Runtime")

public struct RuntimeError: CodableLocalizedError, Located {
    
    /// The error message as formatted during init.
    public let description: String
    
    /// The source location to which the error applies.
    public let location: SourceLocation
    
    public var errorDescription: String? {
        description
    }
    
}

/// The error thrown by `raise` in user code.
public struct RaisedObjectError: CodableLocalizedError, Located {
    
    /// The object given to `raise`.
    public let error: RT_Object
    
    /// The source location of the `raise` expression.
    public let location: SourceLocation
    
    public var errorDescription: String? {
        "\(error)"
    }
    
}

public struct InFlightRuntimeError: Error {
    
    /// The error message as formatted during init.
    public let description: String
    
}

public class Runtime {
    
    var builtin: Builtin!
    
    /// The result of the last expression executed in sequence.
    public lazy var lastResult: RT_Object = null
    
    /// The singleton `null` instance.
    public lazy var null = RT_Null(self)
    /// The singleton `true` boolean instance.
    public lazy var `true` = RT_Boolean(self, value: true)
    /// The singleton `false` boolean instance.
    public lazy var `false` = RT_Boolean(self, value: false)
    
    private var locations: [SourceLocation] = []
    private func pushLocation(_ location: SourceLocation) {
        locations.append(location)
    }
    private func popLocation() {
        _ = locations.popLast()
    }
    var currentLocation: SourceLocation? {
        locations.last
    }
    
    public var scriptName: String?
    public var currentApplicationBundleID: String?
    
    public init(scriptName: String? = nil, currentApplicationBundleID: String? = nil) {
        self.scriptName = scriptName
        self.currentApplicationBundleID = currentApplicationBundleID
    }
    
    public lazy var topScript = RT_Script(self, name: scriptName)
    public lazy var core = RT_Core(self)
    
    public func injectTerms(from rootTerm: Term) {
        func add(typeTerm term: Term) {
            func typeInfo(for typeTerm: Term) -> TypeInfo {
                var tags: Set<TypeInfo.Tag> = []
                if let name = typeTerm.name {
                    tags.insert(.name(name))
                }
                return TypeInfo(typeTerm.uri, tags)
            }
            
            let type = typeInfo(for: term)
            typesByUID[type.id] = type
            if let supertype = type.supertype {
                if typesBySupertype[supertype] == nil {
                    typesBySupertype[supertype] = []
                }
                typesBySupertype[supertype]!.append(type)
            }
            if let name = term.name {
                typesByName[name] = type
            }
        }
        
        guard !terms.contains(rootTerm) else {
            return
        }
        terms.insert(rootTerm)
        
        for term in rootTerm.dictionary.contents {
            switch term.role {
            case .dictionary:
                break
            case .type:
                add(typeTerm: term)
            case .property:
                let tags: [PropertyInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let property = PropertyInfo(term.uri, Set(tags))
                propertiesByUID[property.id] = property
            case .constant:
                let tags: [ConstantInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let constant = ConstantInfo(term.uri, Set(tags))
                constantsByUID[constant.id] = constant
            case .command:
                let tags: [CommandInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let command = CommandInfo(term.uri, Set(tags))
                commandsByUID[command.id] = command
            case .parameter:
                break
            case .variable:
                break
            case .resource:
                break
            }
            
            injectTerms(from: term)
        }
    }
    
    private var terms: Set<Term> = []
    
    private var typesByUID: [Term.ID : TypeInfo] = [:]
    private var typesBySupertype: [TypeInfo : [TypeInfo]] = [:]
    private var typesByName: [Term.Name : TypeInfo] = [:]
    
    private func add(forTypeUID uid: Term.SemanticURI) -> TypeInfo {
        let info = TypeInfo(uid)
        typesByUID[Term.ID(.type, uid)] = info
        return info
    }
    
    public func type(forUID uid: Term.ID) -> TypeInfo {
        typesByUID[uid] ?? TypeInfo(uid.uri)
    }
    public func subtypes(of type: TypeInfo) -> [TypeInfo] {
        typesBySupertype[type] ?? []
    }
    public func type(for name: Term.Name) -> TypeInfo? {
        typesByName[name]
    }
    public func type(for code: OSType) -> TypeInfo {
        type(forUID: Term.ID(.type, .ae4(code: code)))
    }
    
    private var propertiesByUID: [Term.ID : PropertyInfo] = [:]
    
    private func add(forPropertyUID uid: Term.SemanticURI) -> PropertyInfo {
        let info = PropertyInfo(uid)
        propertiesByUID[Term.ID(.property, uid)] = info
        return info
    }
    
    public func property(forUID uid: Term.ID) -> PropertyInfo {
        propertiesByUID[uid] ?? add(forPropertyUID: uid.uri)
    }
    public func property(for code: OSType) -> PropertyInfo {
        property(forUID: Term.ID(.property, .ae4(code: code)))
    }
    
    private var constantsByUID: [Term.ID : ConstantInfo] = [:]
    
    private func add(forConstantUID uid: Term.SemanticURI) -> ConstantInfo {
        let info = ConstantInfo(uid)
        constantsByUID[Term.ID(.constant, uid)] = info
        return info
    }
    
    public func constant(forUID uid: Term.ID) -> ConstantInfo {
        constantsByUID[uid] ??
            propertiesByUID[Term.ID(.property, uid.uri)].map { ConstantInfo(property: $0) } ??
            typesByUID[Term.ID(.type, uid.uri)].map { ConstantInfo(type: $0) } ??
            add(forConstantUID: uid.uri)
    }
    public func constant(for code: OSType) -> ConstantInfo {
        constant(forUID: Term.ID(.constant, .ae4(code: code)))
    }
    
    private var commandsByUID: [Term.ID : CommandInfo] = [:]
    
    private func add(forCommandUID uid: Term.SemanticURI) -> CommandInfo {
        let info = CommandInfo(uid)
        commandsByUID[Term.ID(.command, uid)] = info
        return info
    }
    
    public func command(forUID uid: Term.ID) -> CommandInfo {
        commandsByUID[uid] ?? add(forCommandUID: uid.uri)
    }
    
}

public extension Runtime {
    
    func run(_ program: Program) throws -> RT_Object {
        injectTerms(from: program.rootTerm)
        builtin = Builtin(
            self,
            frameStack: RT_FrameStack(bottom: [
                Term.SemanticURI(Variables.Core): core,
                Term.SemanticURI(Variables.Script): topScript
            ]),
            moduleStack: RT_ModuleStack(bottom: core, rest: [topScript]),
            targetStack: RT_TargetStack(bottom: core, rest: [topScript])
        )
        return try run(program.ast)
    }
    
    func run(_ expression: Expression) throws -> RT_Object {
        let result: RT_Object
        do {
            result = try runPrimary(expression)
        } catch let earlyReturn as EarlyReturn {
            result = earlyReturn.value
        } catch let inFlightRuntimeError as InFlightRuntimeError {
            throw RuntimeError(description: inFlightRuntimeError.description, location: currentLocation ?? expression.location)
        }
        
        os_log("Execution result: %@", log: log, type: .debug, String(describing: result))
        return result
    }
    
    struct EarlyReturn: Error {
        
        var value: RT_Object
        
    }
    
    func runPrimary(_ expression: Expression, evaluateSpecifiers: Bool = true) throws -> RT_Object {
        pushLocation(expression.location)
        defer {
            popLocation()
        }
        
        switch expression.kind {
        case .empty: // MARK: .empty
            return lastResult
        case .that: // MARK: .that
            return try evaluateSpecifiers ? evaluatingSpecifier(lastResult) : lastResult
        case .it: // MARK: .it
            return try evaluateSpecifiers ? evaluatingSpecifier(builtin.target) : builtin.target
        case .null: // MARK: .null
            return null
        case .sequence(let expressions): // MARK: .sequence
            for expression in expressions {
                lastResult = try runPrimary(expression)
            }
            return lastResult
        case .scoped(let expression): // MARK: .scoped
            return try runPrimary(expression)
        case .parentheses(let expression): // MARK: .parentheses
            return try runPrimary(expression)
        case let .try_(body, handle): // MARK: .try_
            do {
                return try runPrimary(body)
            } catch {
                builtin.targetStack.push(RT_Error(self, error))
                defer { builtin.targetStack.pop() }
                return try runPrimary(handle)
            }
        case let .if_(condition, then, else_): // MARK: .if_
            let conditionValue = try runPrimary(condition)
            
            if conditionValue.truthy {
                return try runPrimary(then)
            } else if let else_ = else_ {
                return try runPrimary(else_)
            } else {
                return lastResult
            }
        case .repeatWhile(let condition, let repeating): // MARK: .repeatWhile
            var repeatResult: RT_Object?
            while try runPrimary(condition).truthy {
                repeatResult = try runPrimary(repeating)
            }
            return repeatResult ?? lastResult
        case .repeatTimes(let times, let repeating): // MARK: .repeatTimes
            let timesValue = try runPrimary(times)
            
            var repeatResult: RT_Object?
            var count = 0
            while try builtin.binaryOp(.less, RT_Integer(self, value: count), timesValue).truthy {
                repeatResult = try runPrimary(repeating)
                count += 1
            }
            return repeatResult ?? lastResult
        case .repeatFor(let variable, let container, let repeating): // MARK: .repeatFor
            let containerValue = try runPrimary(container)
            let timesValue = try builtin.getSequenceLength(containerValue)
            
            var repeatResult: RT_Object?
            // 1-based indices wheeeeee
            for count in 1...timesValue {
                let elementValue = try builtin.getFromSequenceAtIndex(containerValue, Int64(count))
                builtin[variable: variable] = elementValue
                repeatResult = try runPrimary(repeating)
            }
            return repeatResult ?? lastResult
        case .tell(let newTarget, let to): // MARK: .tell
            let newTargetValue = try runPrimary(newTarget, evaluateSpecifiers: false)
            builtin.targetStack.push(newTargetValue)
            defer { builtin.targetStack.pop() }
            if let newModuleValue = newTargetValue as? RT_Module {
                builtin.moduleStack.push(newModuleValue)
                defer { builtin.moduleStack.pop() }
                return try runPrimary(to)
            }
            return try runPrimary(to)
        case .let_(let term, let initialValue): // MARK: .let_
            let initialExprValue = try initialValue.map { try runPrimary($0) } ?? null
            builtin[variable: term] = initialExprValue
            return initialExprValue
        case .define(_, as: _): // MARK: .define
            return lastResult
        case .defining(_, as: _, body: let body): // MARK: .defining
            return try runPrimary(body)
        case .return_(let returnValue): // MARK: .return_
            let returnExprValue = try returnValue.map { try runPrimary($0) } ??
                lastResult
            throw EarlyReturn(value: returnExprValue)
        case .raise(let error): // MARK: .raise
            let errorValue = try runPrimary(error)
            if let errorValue = errorValue as? RT_Error {
                throw errorValue.error
            } else {
                throw RaisedObjectError(error: errorValue, location: expression.location)
            }
        case .integer(let value): // MARK: .integer
            return RT_Integer(self, value: value)
        case .double(let value): // MARK: .double
            return RT_Real(self, value: value)
        case .string(let value): // MARK: .string
            return RT_String(self, value: value)
        case .list(let expressions): // MARK: .list
            return try RT_List(self, contents:
                expressions.map { try runPrimary($0) }
            )
        case .record(let keyValues): // MARK: .record
            return try RT_Record(self, contents:
                [RT_Object : RT_Object](
                    try keyValues.map {
                        try (
                            runPrimary($0.key, evaluateSpecifiers: false),
                            runPrimary($0.value)
                        )
                    },
                    uniquingKeysWith: {
                        try builtin.binaryOp(.greater, $1, $0).truthy ? $1 : $0
                    }
                )
            )
        case .prefixOperator(let operation, let operand), .postfixOperator(let operation, let operand): // MARK: .prefixOperator, .postfixOperator
            let operandValue = try runPrimary(operand)
            return builtin.unaryOp(operation, operandValue)
        case .infixOperator(let operation, let lhs, let rhs): // MARK: .infixOperator
            let lhsValue = try runPrimary(lhs)
            let rhsValue = try runPrimary(rhs)
            return try builtin.binaryOp(operation, lhsValue, rhsValue)
        case .variable(let term): // MARK: .variable
            return builtin[variable: term]
        case .use(let term), // MARK: .use
             .resource(let term): // MARK: .resource
            return try builtin.getResource(term)
        case .enumerator(let term): // MARK: .constant
            return builtin.newConstant(term.id)
        case .type(let term): // MARK: .class_
            return RT_Type(self, value: type(forUID: term.id))
        case .set(let expression, to: let newValueExpression): // MARK: .set
            if case .variable(let variableTerm) = expression.kind {
                let newValueExprValue = try runPrimary(newValueExpression)
                builtin[variable: variableTerm] = newValueExprValue
                return newValueExprValue
            } else {
                let expressionExprValue = try runPrimary(expression, evaluateSpecifiers: false)
                let newValueExprValue = try runPrimary(newValueExpression)
                
                let arguments: [ParameterInfo : RT_Object] = [
                    ParameterInfo(.direct): expressionExprValue,
                    ParameterInfo(.set_to): newValueExprValue
                ]
                let command = self.command(forUID: Term.ID(Commands.set))
                return try builtin.run(command: command, arguments: arguments)
            }
        case .command(let term, let parameters): // MARK: .command
            let parameterExprValues: [(key: ParameterInfo, value: RT_Object)] = try parameters.map { kv in
                let (parameterTerm, parameterValue) = kv
                let parameterInfo = ParameterInfo(parameterTerm.uri)
                let value = try runPrimary(parameterValue)
                return (parameterInfo, value)
            }
            let arguments = [ParameterInfo : RT_Object](uniqueKeysWithValues:
                parameterExprValues
            )
            let command = self.command(forUID: term.id)
            return try builtin.run(command: command, arguments: arguments)
        case .reference(let expression): // MARK: .reference
            return try runPrimary(expression, evaluateSpecifiers: false)
        case .get(let expression): // MARK: .get
            return try evaluatingSpecifier(runPrimary(expression))
        case .specifier(let specifier): // MARK: .specifier
            let specifierValue = try buildSpecifier(specifier)
            return evaluateSpecifiers ? try evaluatingSpecifier(specifierValue) : specifierValue
        case .insertionSpecifier(let insertionSpecifier): // MARK: .insertionSpecifier
            let parentValue: RT_Object = try {
                if let parent = insertionSpecifier.parent {
                    return try runPrimary(parent)
                } else {
                    return builtin.target
                }
            }()
            return RT_InsertionSpecifier(self, parent: parentValue, kind: insertionSpecifier.kind)
        case .function(let name, let parameters, let types, let arguments, let body): // MARK: .function
            let evaluatedTypes = try types.map { try $0.map { try runPrimary($0) } }
            let typeInfos = evaluatedTypes.map { $0.map { ($0 as? RT_Type)?.value ?? TypeInfo(.item) } ?? TypeInfo(.item) }
            
            var parameterSignature = RT_Function.ParameterSignature(
                parameters.enumerated().map { (ParameterInfo($0.element.uri), typeInfos[$0.offset]) },
                uniquingKeysWith: { l, r in l }
            )
            if !typeInfos.isEmpty {
                parameterSignature[ParameterInfo(.direct)] = typeInfos[0]
            }
            let signature = RT_Function.Signature(command: command(forUID: Term.ID(.command, name.uri)), parameters: parameterSignature)
            
            let implementation = RT_ExpressionImplementation(self, formalParameters: parameters, formalArguments: arguments, body: body)
            
            let function = RT_Function(self, signature: signature, implementation: implementation)
            builtin.moduleStack.add(function: function)
                
            return lastResult
        case .block(let arguments, let body): // MARK: .block
            let blockSignature = RT_Function.Signature(
                command: CommandInfo(.run),
                parameters: [ParameterInfo(.direct): TypeInfo(.list)]
            )
            let implementation = RT_BlockImplementation(
                self,
                formalArguments: arguments,
                body: body
            )
            return RT_Function(self, signature: blockSignature, implementation: implementation)
        case .multilineString(_, let body): // MARK: .multilineString
            return RT_String(self, value: body)
        case .weave(let hashbang, let body): // MARK: .weave
            if hashbang.isEmpty {
                return lastResult
            } else {
                return builtin.runWeave(hashbang.invocation, body, lastResult)
            }
        case .debugInspectTerm(_, let message):
            return RT_String(self, value: message)
        case .debugInspectLexicon(let message):
            return RT_String(self, value: message)
        }
    }
    
    private func buildSpecifier(_ specifier: Specifier) throws -> RT_Object {
        let id = specifier.term.id
        
        let parent = try specifier.parent.map { try runPrimary($0, evaluateSpecifiers: false) }
        
        let data: [RT_Object]
        if case .test(_, let testComponent) = specifier.kind {
            data = [try runTestComponent(testComponent)]
        } else {
            data = try specifier.allDataExpressions().map { dataExpression in
                try runPrimary(dataExpression)
            }
        }
        
        func generate() -> RT_Specifier {
            if case .property = specifier.kind {
                return RT_Specifier(self, parent: parent, type: nil, property: property(forUID: id), data: [], kind: .property)
            }
            
            let kind: RT_Specifier.Kind = {
                switch specifier.kind {
                case .simple:
                    return .simple
                case .index:
                    return .index
                case .name:
                    return .name
                case .id:
                    return .id
                case .all:
                    return .all
                case .first:
                    return .first
                case .middle:
                    return .middle
                case .last:
                    return .last
                case .random:
                    return .random
                case .previous:
                    return .previous
                case .next:
                    return .next
                case .range:
                    return .range
                case .test:
                    return .test
                case .property:
                    fatalError("unreachable")
                }
            }()
            return RT_Specifier(self, parent: parent, type: type(forUID: id), data: data, kind: kind)
        }
        
        let resultValue = generate()
        return (specifier.parent == nil) ?
            builtin.qualifySpecifier(resultValue) :
            resultValue
    }
    
    private func runTestComponent(_ testComponent: TestComponent) throws -> RT_Object {
        switch testComponent {
        case let .expression(expression):
            return try runPrimary(expression, evaluateSpecifiers: false)
        case let .predicate(predicate):
            let lhsValue = try runTestComponent(predicate.lhs)
            let rhsValue = try runTestComponent(predicate.rhs)
            return builtin.newTestSpecifier(predicate.operation, lhsValue, rhsValue)
        }
    }
    
    private func evaluatingSpecifier(_ object: RT_Object) throws -> RT_Object {
        try builtin.evaluateSpecifier(object)
    }
    
}

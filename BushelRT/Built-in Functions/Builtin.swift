import Bushel
import SwiftAutomation

final class Builtin {
    
    var rt = Runtime()
    public var frameStack: RT_FrameStack
    public var moduleStack: RT_ModuleStack
    public var targetStack: RT_TargetStack
    
    public init(_ rt: Runtime, frameStack: RT_FrameStack, moduleStack: RT_ModuleStack, targetStack: RT_TargetStack) {
        self.rt = rt
        self.frameStack = frameStack
        self.moduleStack = moduleStack
        self.targetStack = targetStack
    }
    
    func throwError(message: String) throws -> Never {
        let location = rt.currentLocation ?? SourceLocation(at: "".startIndex, source: "")
        throw RuntimeError(description: message, location: location)
    }
    
    public subscript(variable term: Term) -> RT_Object {
        get {
            frameStack.top[term.uri] ?? rt.null
        }
        set {
            frameStack.top[term.uri] = newValue
        }
    }
    
    public var target: RT_Object {
        targetStack.top
    }
    
    func newConstant(_ typedUID: Term.ID) -> RT_Object {
        switch Constants(typedUID) {
        case .true:
            return rt.true
        case .false:
            return rt.false
        default:
            return RT_Constant(rt, value: rt.constant(forUID: typedUID))
        }
    }
    
    func getSequenceLength(_ sequence: RT_Object) throws -> Int64 {
        do {
            guard let length = try sequence.property(rt.property(forUID: Term.ID(Properties.Sequence_length))) as? RT_Numeric else {
                throw NoNumericPropertyExists(type: sequence.dynamicTypeInfo, property: PropertyInfo(Properties.Sequence_length))
            }
            return Int64(length.numericValue.rounded(.up))
        } catch {
            try throwError(message: error.localizedDescription)
        }
    }
    
    func getFromSequenceAtIndex(_ sequence: RT_Object, _ index: Int64) throws -> RT_Object {
        do {
            return try sequence.element(rt.type(forUID: Term.ID(Types.item)), at: index) ?? rt.null
        } catch {
            try throwError(message: error.localizedDescription)
        }
    }
    
    func unaryOp(_ operation: UnaryOperation, _ operand: RT_Object) -> RT_Object {
        return { () -> RT_Object? in
            switch operation {
            case .not:
                return operand.not()
            }
        }() ?? rt.null
    }
    
    func binaryOp(_ operation: BinaryOperation, _ lhs: RT_Object, _ rhs: RT_Object) throws -> RT_Object {
        return try { () -> RT_Object? in
            switch operation {
            case .or:
                return lhs.or(rhs)
            case .xor:
                return lhs.xor(rhs)
            case .and:
                return lhs.and(rhs)
            case .isA:
                return rhs.coerce(to: RT_Type.self).map { RT_Boolean.withValue(rt, lhs.dynamicTypeInfo.isA($0.value)) }
            case .isNotA:
                return rhs.coerce(to: RT_Type.self).map { RT_Boolean.withValue(rt, !lhs.dynamicTypeInfo.isA($0.value)) }
            case .equal:
                return lhs.equal(to: rhs)
            case .notEqual:
                return lhs.notEqual(to: rhs)
            case .less:
                return lhs.less(than: rhs)
            case .lessEqual:
                return lhs.lessEqual(to: rhs)
            case .greater:
                return lhs.greater(than: rhs)
            case .greaterEqual:
                return lhs.greaterEqual(to: rhs)
            case .startsWith:
                return lhs.startsWith(rhs)
            case .endsWith:
                return lhs.endsWith(rhs)
            case .contains:
                return lhs.contains(rhs)
            case .notContains:
                return lhs.notContains(rhs)
            case .containedBy:
                return lhs.contained(by: rhs)
            case .notContainedBy:
                return lhs.notContained(by: rhs)
            case .add:
                return lhs.adding(rhs)
            case .subtract:
                return lhs.subtracting(rhs)
            case .multiply:
                return lhs.multiplying(by: rhs)
            case .divide:
                return lhs.dividing(by: rhs)
            case .concatenate:
                return lhs.concatenating(rhs) ?? rhs.concatenated(to: lhs)
            case .coerce:
                return try lhs.coercing(to: rhs)
            }
        }() ?? rt.null
    }
    
    private var nativeLibraryRTs: [URL : Runtime] = [:]
    
    func getResource(_ term: Term) throws -> RT_Object {
        return try {
            switch term.resource {
            case .bushelscript:
                return rt.core
            case .system(_):
                return RT_System(rt)
            case let .applicationByName(bundle),
                 let .applicationByID(bundle):
                return RT_Application(rt, bundle: bundle)
            case .scriptingAdditionByName(_):
                return rt.core
            case let .libraryByName(_, url, library):
                switch library {
                case let .native(program):
                    if let libraryRT = nativeLibraryRTs[url] {
                        return libraryRT.topScript
                    } else {
                        let libraryRT = Runtime(scriptName: term.name!.normalized, currentApplicationBundleID: self.rt.currentApplicationBundleID)
                        
                        _ = try libraryRT.run(program)
                        
                        nativeLibraryRTs[url] = libraryRT
                        return libraryRT.topScript
                    }
                case let .applescript(applescript):
                    return RT_AppleScript(rt, name: term.name!.normalized, value: applescript)
                }
            case let .applescriptAtPath(_, script):
                return RT_AppleScript(rt, name: term.name!.normalized, value: script)
            case nil:
                return rt.null
            }
        }() as RT_Object
    }
    
    func newTestSpecifier(_ operation: BinaryOperation, _ lhs: RT_Object, _ rhs: RT_Object) -> RT_Object {
        return RT_TestSpecifier(rt, operation: operation, lhs: lhs, rhs: rhs)
    }
    
    func qualifySpecifier(_ specifier: RT_Specifier) -> RT_Specifier {
        let clone = specifier.clone()
        clone.setRootAncestor(target)
        return clone
    }
    
    func evaluateSpecifier(_ specifier: RT_Object) throws -> RT_Object {
        do {
            return try specifier.evaluate()
        } catch let error as InFlightRuntimeError {
            try throwError(message: "error evaluating specifier ‘\(specifier)’: \(error.description)")
        } catch {
            try throwError(message: "error evaluating specifier ‘\(specifier)’: \(error.localizedDescription)")
        }
    }
    
    func run(command: CommandInfo, arguments: [ParameterInfo : RT_Object]) throws -> RT_Object {
        var arguments = RT_Arguments(command, arguments)
        if arguments[.target] == nil {
            arguments.contents[ParameterInfo(.target)] = target
        }
        
        return try propagate(up: moduleStack) { (module) -> RT_Object? in
            do {
                return try module.handle(arguments)
            } catch let error as Unencodable where error.object is CommandInfo || error.object is ParameterInfo {
                // Tried to send an inapplicable command to a remote object
                // Ignore it and fall through to the next target
                return nil
            } catch let error as RaisedObjectError where error.error.rt !== rt {
                // This error originates from another file (with a different
                // source mapping). Its location info is meaningless to us.
                throw RaisedObjectError(error: error.error, location: rt.currentLocation!)
            }
        } ?? { throw CommandNotHandled(command: command) }()
    }
    
    func runWeave(_ hashbang: String, _ body: String, _ inputObject: RT_Object) -> RT_Object {
        var invocation = hashbang
        invocation.removeLeadingWhitespace()
        if !invocation.hasPrefix("/") {
            // Simplified hashbangs like "#!python" are really just shorthand for /usr/bin/env
            invocation = "/usr/bin/env \(invocation)"
        }
        
        // TODO: Handle errors
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let scriptFile = tempDir.appendingPathComponent("weavescript_\(UUID().uuidString)")
        FileManager.default.createFile(atPath: scriptFile.path, contents: "#!\(invocation)\n\n\(body)".data(using: .utf8), attributes: [.posixPermissions: 0o0700 as AnyObject])
        
        let process = Process()
        process.executableURL = scriptFile
        
        let input = Pipe(),
            output = Pipe(),
            error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error
        
        let inputWriteFileHandle = input.fileHandleForWriting
        inputWriteFileHandle.write(((inputObject.coerce(to: rt.type(forUID: Term.ID(Types.string))) as? RT_String)?.value ?? String(describing: inputObject)).data(using: .utf8)!)
        inputWriteFileHandle.closeFile()
        
        try! process.run()
        process.waitUntilExit()
        
        // TODO: readDataToEndOfFile caused problems in defaults-edit, apply the solution used there instead
        return RT_String(rt, value: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)
    }
    
}

public extension RT_Object {
    
    static func fromAEDescriptor(_ rt: Runtime, _ appData: AppData, _ descriptor: NSAppleEventDescriptor) throws -> RT_Object {
        return fromSADecoded(rt, try appData.unpackAsAny(descriptor)) ??
            RT_AEObject(rt, descriptor: descriptor)
    }
    
    static func fromSADecoded(_ rt: Runtime, _ object: Any) -> RT_Object? {
        switch object {
        case let bool as Bool:
            return RT_Boolean.withValue(rt, bool)
        case let int32 as Int32:
            return RT_Integer(rt, value: Int64(int32))
        case let int64 as Int64:
            return RT_Integer(rt, value: int64)
        case let int as Int:
            return RT_Integer(rt, value: Int64(int))
        case let uint32 as UInt32:
            return RT_Integer(rt, value: Int64(uint32))
        case let uint64 as UInt64:
            return RT_Integer(rt, value: Int64(uint64))
        case let uint as UInt:
            return RT_Integer(rt, value: Int64(uint))
        case let double as Double:
            return RT_Real(rt, value: double)
        case let string as String:
            return RT_String(rt, value: string)
        case let character as Character:
            return RT_Character(rt, value: character)
        case let date as Date:
            return RT_Date(rt, value: date)
        case let array as [Any]:
            guard let contents = array.map({ fromSADecoded(rt, $0) }) as? [RT_Object] else {
                return nil
            }
            return RT_List(rt, contents: contents.map { $0 })
        case let dictionary as [SwiftAutomation.Symbol : Any]:
            guard let values = dictionary.values.map({ fromSADecoded(rt, $0) }) as? [RT_Object] else {
                return nil
            }
            let keysAndValues = zip(dictionary.keys, values).map { ($0.0.asRTObject(rt), $0.1) }
            let convertedDictionary = [RT_Object : RT_Object](uniqueKeysWithValues: keysAndValues)
            return RT_Record(rt, contents: convertedDictionary)
        case let url as URL:
            return RT_File(rt, value: url)
        case is MissingValueType:
            return rt.null // Intentional
        case let symbol as Symbol:
            return symbol.asRTObject(rt)
        case let specifier as SwiftAutomation.Specifier:
            if let root = specifier as? SwiftAutomation.RootSpecifier {
                guard
                    let bundleID = root.appData.target.bundleIdentifier,
                    let bundle = Bundle(identifier: bundleID)
                else {
                    return nil
                }
                return RT_Application(rt, bundle: bundle)
            } else if let objectSpecifier = specifier as? SwiftAutomation.ObjectSpecifier {
                return RT_Specifier(rt, saSpecifier: objectSpecifier)
            } else {
                // TODO: insertion specifiers
                return RT_String(rt, value: "\(specifier)")
            }
        // TODO: There are more types
        default:
            return nil
        }
    }
    
}

extension SwiftAutomation.Symbol {
    
    func asRTObject(_ rt: Runtime) -> RT_Object {
        switch type {
        case typeType:
            return RT_Type(rt, value: TypeInfo(.ae4(code: code)))
        case typeEnumerated, typeKeyword, typeProperty:
            return RT_Constant(rt, value: ConstantInfo(.ae4(code: code)))
        default:
            fatalError("invalid descriptor type for Symbol")
        }
    }
    
}

extension RT_HierarchicalSpecifier {
    
    public func evaluate_() throws -> RT_Object {
        switch rootAncestor() {
        case let root as RT_AERootSpecifier:
            return try self.handleByAppleEvent(
                RT_Arguments(CommandInfo(.get), [ParameterInfo(.direct): self]),
                appData: root.saRootSpecifier.appData
            )
        default:
            // Eval as a local specifier.
            func evaluateLocalSpecifier(_ specifier: RT_HierarchicalSpecifier, from root: RT_Object) throws -> RT_Object {
                // Start from the top and work down
                let evaluatedParent: RT_Object = try {
                    if
                        let parent = specifier.parent as? RT_HierarchicalSpecifier,
                        parent !== root
                    {
                        // Eval the parent specifier before working with this one.
                        return try evaluateLocalSpecifier(parent, from: root)
                    } else {
                        // We are the specifier directly under the root.
                        return root
                    }
                }()
                return try specifier.evaluateLocally(on: evaluatedParent)
            }
            var root = rootAncestor()
            if root is RT_RootSpecifier {
                root = rt.builtin.target
            }
            return try evaluateLocalSpecifier(self, from: root)
        }
    }
    
}

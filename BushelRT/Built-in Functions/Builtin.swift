import Bushel
import SwiftAutomation

final class Builtin {
    
    var rt = Runtime()
    lazy var stack = ProgramStack(rt)
    
    func throwError(message: String) throws -> Never {
        let location = rt.currentLocation ?? SourceLocation(at: "".startIndex, source: "")
        throw RuntimeError(description: message, location: location)
    }
    
    func pushFrame() {
        stack.pushFrame()
    }
    
    func popFrame() {
        stack.popFrame()
    }
    
    func getVariableValue(_ term: Term) -> RT_Object {
        stack.variables[term.uri] ?? RT_Null.null
    }
    
    @discardableResult
    func setVariableValue(_ term: Term, _ newValue: RT_Object) -> RT_Object {
        stack.variables[term.uri] = newValue
        return newValue
    }
    
    func newConstant(_ typedUID: Term.ID) -> RT_Object {
        switch Constants(typedUID) {
        case .true:
            return RT_Boolean.withValue(true)
        case .false:
            return RT_Boolean.withValue(false)
        default:
            return RT_Constant(value: rt.constant(forUID: typedUID))
        }
    }
    
    func getSequenceLength(_ sequence: RT_Object) throws -> Int64 {
        do {
            let length = try sequence.property(rt.property(forUID: Term.ID(Properties.Sequence_length))) as? RT_Numeric
            // TODO: Throw error for non-numeric length
            return Int64(length?.numericValue ?? 0)
        } catch {
            try throwError(message: error.localizedDescription)
        }
    }
    
    func getFromSequenceAtIndex(_ sequence: RT_Object, _ index: Int64) throws -> RT_Object {
        do {
            let item = try sequence.element(rt.type(forUID: Term.ID(Types.item)), at: index)
            return item
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
        }() ?? RT_Null.null
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
                return rhs.coerce(to: RT_Type.self).map { RT_Boolean.withValue(lhs.dynamicTypeInfo.isA($0.value)) }
            case .isNotA:
                return rhs.coerce(to: RT_Type.self).map { RT_Boolean.withValue(!lhs.dynamicTypeInfo.isA($0.value)) }
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
        }() ?? RT_Null.null
    }
    
    func getResource(_ term: Term) -> RT_Object {
        return {
            switch term.resource {
            case .bushelscript:
                return RT_Core()
            case .system(_):
                return RT_System()
            case .applicationByName(let bundle),
                 .applicationByID(let bundle):
                return RT_Application(bundle: bundle)
            case .scriptingAdditionByName(_):
                return RT_Core()
            case .applescriptLibraryByName(_, _, let script),
                 .applescriptAtPath(_, let script):
                return RT_AppleScript(name: term.name!.normalized, value: script)
            case nil:
                return RT_Null.null
            }
        }() as RT_Object
    }
    
    func newTestSpecifier(_ operation: BinaryOperation, _ lhs: RT_Object, _ rhs: RT_Object) -> RT_Object {
        return RT_TestSpecifier(operation: operation, lhs: lhs, rhs: rhs)
    }
    
    func qualifySpecifier(_ specifier: RT_Specifier, _ target: RT_Object) -> RT_Specifier {
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
    
    func run(command: CommandInfo, arguments: [ParameterInfo : RT_Object], target: RT_Object) throws -> RT_Object {
        var argumentsWithoutDirect = arguments
        argumentsWithoutDirect.removeValue(forKey: ParameterInfo(.direct))
        
        var implicitDirect: RT_Object?
        if arguments[ParameterInfo(.direct)] == nil {
            implicitDirect = target
        }
        let directParameter = arguments[ParameterInfo(.direct)] ?? implicitDirect
        
        func catchingErrors(do action: () throws -> RT_Object?) throws -> RT_Object? {
            do {
                return try action()
            } catch let error as Unencodable where error.object is CommandInfo || error.object is ParameterInfo {
                // Tried to send an inapplicable command to a remote object
                // Ignore it and fall through to the next target
            }
            return nil
        }
        
        // TODO: Revise with Target Stack
        return try
            catchingErrors {
                try directParameter?.perform(command: command, arguments: argumentsWithoutDirect, implicitDirect: implicitDirect)
            } ??
            catchingErrors {
                directParameter == target ?
                    nil :
                    try target.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
            } ??
            catchingErrors {
                try rt.topScript.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
            } ??
            catchingErrors {
                try RT_Core().perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
            } ?? RT_Null.null
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
        return RT_String(value: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)
    }
    
}

extension SwiftAutomation.Specifier {
    
    func perform(command: CommandInfo, arguments: [OSType : NSAppleEventDescriptor]) throws -> RT_Object {
        do {
            let wrappedResultDescriptor = try sendEvent(for: command, arguments: arguments)
            guard let resultDescriptor = wrappedResultDescriptor.result else {
                let errorNumber = wrappedResultDescriptor.errorNumber
                guard errorNumber == 0 else {
                    throw AutomationError(code: errorNumber)
                }
                // No result returned
                return RT_Null.null
            }
            
            return try RT_Object.fromAEDescriptor(appData, resultDescriptor)
        } catch let error as CommandError {
            throw RemoteCommandError(remoteObject: appData.target, command: command, error: error)
        } catch let error as AutomationError {
            if error._code == errAEEventNotPermitted {
                throw RemoteCommandsDisallowed(remoteObject: appData.target)
            } else {
                throw RemoteCommandError(remoteObject: appData.target, command: command, error: error)
            }
        } catch let error as UnpackError {
            throw Undecodable(error: error)
        }
    }
    
    func sendEvent(for command: CommandInfo, arguments: [OSType : NSAppleEventDescriptor]) throws -> ReplyEventDescriptor {
        guard let codes = command.id.ae8Code else {
            throw Unencodable(object: command)
        }
        return try self.sendAppleEvent(codes.class, codes.id, arguments)
    }
    
}

public extension RT_Object {
    
    static func fromAEDescriptor(_ appData: AppData, _ descriptor: NSAppleEventDescriptor) throws -> RT_Object {
        return fromSADecoded( try appData.unpackAsAny(descriptor)) ??
            RT_AEObject(descriptor: descriptor)
    }
    
    static func fromSADecoded(_ object: Any) -> RT_Object? {
        switch object {
        case let bool as Bool:
            return RT_Boolean.withValue(bool)
        case let int32 as Int32:
            return RT_Integer(value: Int64(int32))
        case let int64 as Int64:
            return RT_Integer(value: int64)
        case let int as Int:
            return RT_Integer(value: Int64(int))
        case let uint32 as UInt32:
            return RT_Integer(value: Int64(uint32))
        case let uint64 as UInt64:
            return RT_Integer(value: Int64(uint64))
        case let uint as UInt:
            return RT_Integer(value: Int64(uint))
        case let double as Double:
            return RT_Real(value: double)
        case let string as String:
            return RT_String(value: string)
        case let character as Character:
            return RT_Character(value: character)
        case let date as Date:
            return RT_Date(value: date)
        case let array as [Any]:
            guard let contents = array.map({ fromSADecoded($0) }) as? [RT_Object] else {
                return nil
            }
            return RT_List(contents: contents.map { $0 })
        case let dictionary as [SwiftAutomation.Symbol : Any]:
            guard let values = dictionary.values.map({ fromSADecoded($0) }) as? [RT_Object] else {
                return nil
            }
            let keysAndValues = zip(dictionary.keys, values).map { ($0.0.asRTObject(), $0.1) }
            let convertedDictionary = [RT_Object : RT_Object](uniqueKeysWithValues: keysAndValues)
            return RT_Record(contents: convertedDictionary)
        case let url as URL:
            return RT_File(value: url)
        case is MissingValueType:
            return RT_Null.null // Intentional
        case let symbol as Symbol:
            return symbol.asRTObject()
        case let specifier as SwiftAutomation.Specifier:
            if let root = specifier as? SwiftAutomation.RootSpecifier {
                guard
                    let bundleID = root.appData.target.bundleIdentifier,
                    let bundle = Bundle(identifier: bundleID)
                else {
                    return nil
                }
                return RT_Application(bundle: bundle)
            } else if let objectSpecifier = specifier as? SwiftAutomation.ObjectSpecifier {
                return RT_Specifier(saSpecifier: objectSpecifier)
            } else {
                // TODO: insertion specifiers
                return RT_String(value: "\(specifier)")
            }
        // TODO: There are more types
        default:
            return nil
        }
    }
    
}

extension SwiftAutomation.Symbol {
    
    func asRTObject() -> RT_Object {
        switch type {
        case typeType:
            return RT_Type(value: TypeInfo(.ae4(code: code)))
        case typeEnumerated, typeKeyword, typeProperty:
            return RT_Constant(value: ConstantInfo(.ae4(code: code)))
        default:
            fatalError("invalid descriptor type for Symbol")
        }
    }
    
}

extension RT_HierarchicalSpecifier {
    
    public func evaluate_() throws -> RT_Object {
        switch rootAncestor() {
        case let root as RT_SpecifierRemoteRoot:
            // Let remote root handle evaluation.
            return try root.evaluate(specifier: self)
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
                root = RT_Core()
            }
            return try evaluateLocalSpecifier(self, from: root)
        }
    }
    
}

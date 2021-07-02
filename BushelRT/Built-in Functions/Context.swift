import Bushel

extension Runtime {
    
    /// Manages program context for a Runtime.
    final class Context {
        
        var rt: Runtime
        public var frameStack: RT_FrameStack
        public var moduleStack: RT_ModuleStack
        public var targetStack: RT_TargetStack
        
        public init(_ rt: Runtime, frameStack: RT_FrameStack, moduleStack: RT_ModuleStack, targetStack: RT_TargetStack) {
            self.rt = rt
            self.frameStack = frameStack
            self.moduleStack = moduleStack
            self.targetStack = targetStack
        }
        
        public subscript(variable term: Term) -> RT_Object {
            get {
                frameStack.top[term.uri]?.value ?? rt.null
            }
            set {
                if let objectRef = frameStack.top[term.uri] {
                    objectRef.value = newValue
                } else {
                    frameStack.top[term.uri] = Ref(newValue)
                }
            }
        }
        
        public var target: RT_Object {
            targetStack.top
        }
        
        func newConstant(_ id: Term.ID) -> RT_Object {
            switch Constants(id) {
            case .true:
                return rt.true
            case .false:
                return rt.false
            default:
                return RT_Constant(rt, value: rt.reflection.constants[id.uri])
            }
        }
        
        func getSequenceLength(_ sequence: RT_Object) throws -> Int64 {
            guard let length = try sequence.property(rt.reflection.properties[.Sequence_length])?.coerce(to: RT_Integer.self)?.value else {
                throw NoNumericPropertyExists(type: sequence.type, property: rt.reflection.properties[.Sequence_length])
            }
            return length
        }
        
        func getFromSequenceAtIndex(_ sequence: RT_Object, _ index: Int64) throws -> RT_Object {
            try sequence.element(rt.reflection.types[.item], at: index) ?? rt.null
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
                    return rhs.coerce(to: RT_Type.self).map { RT_Boolean.withValue(rt, lhs.type.isA($0.value)) }
                case .isNotA:
                    return rhs.coerce(to: RT_Type.self).map { RT_Boolean.withValue(rt, !lhs.type.isA($0.value)) }
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
                            let libraryRT = Runtime(scriptName: term.name!.normalized)
                            
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
        
        func qualify(specifier: RT_Specifier) -> RT_Specifier {
            let clone = specifier.clone()
            clone.setRootAncestor(target)
            return clone
        }
        
        func evaluate(specifier: RT_Object) throws -> RT_Object {
            do {
                return try specifier.evaluate()
            } catch let error as RemoteCommandError {
                throw RemoteSpecifierEvaluationFailed(specifier: specifier, reason: error.error)
            } catch {
                throw LocalSpecifierEvaluationFailed(specifier: specifier, reason: error)
            }
        }
        
        func run(command: Reflection.Command, arguments: [Reflection.Parameter : RT_Object]) throws -> RT_Object {
            var arguments = RT_Arguments(command, arguments)
            if arguments[.target] == nil {
                arguments.contents[command.parameters[.target]] = target
            }
            
            return try propagate(from: target as? RT_Module, up: moduleStack) { (module) -> RT_Object? in
                do {
                    return try module.handle(arguments)
                } catch let error as Unencodable where error.object is Reflection.Command || error.object is Reflection.Parameter {
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
            inputWriteFileHandle.write((inputObject.coerce(to: RT_String.self)?.value ?? String(describing: inputObject)).data(using: .utf8)!)
            inputWriteFileHandle.closeFile()
            
            try! process.run()
            process.waitUntilExit()
            
            // TODO: readDataToEndOfFile caused problems in defaults-edit, apply the solution used there instead
            return RT_String(rt, value: String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!)
        }
        
    }
    
}

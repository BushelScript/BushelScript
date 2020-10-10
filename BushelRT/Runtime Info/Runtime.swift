import Bushel
import LLVM
import os

private let log = OSLog(subsystem: logSubsystem, category: "Runtime")

public class Runtime {
    
    public struct RuntimeError: LocalizedError {
        public var errorDescription: String?
    }
    
    public let termPool = TermPool()
    public let topScript: RT_Script
    public var global: RT_Global!
    
    private let objectPool = NSMapTable<RT_Object, NSNumber>(keyOptions: [.strongMemory, .objectPointerPersonality], valueOptions: .copyIn)
    
    public var currentApplicationBundleID: String?
    
    public init(scriptName: String? = nil, currentApplicationBundleID: String? = nil) {
        self.topScript = RT_Script(name: scriptName)
        self.currentApplicationBundleID = currentApplicationBundleID
        self.global = nil
        self.global = RT_Global(self)
    }
    
    public func inject(terms: TermPool) {
        func add(classTerm term: Bushel.ClassTerm) {
            func typeInfo(for classTerm: Bushel.ClassTerm) -> TypeInfo {
                var tags: Set<TypeInfo.Tag> = []
                if let name = classTerm.name {
                    tags.insert(.name(name))
                }
                if let supertype = classTerm.parentClass.map({ typeInfo(for: $0) }) {
                    tags.insert(.supertype(supertype))
                }
                return TypeInfo(classTerm.uid, tags)
            }
            
            let type = typeInfo(for: term)
            typesByUID[type.typedUID] = type
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
        
        termPool.add(terms)
        
        for term in terms.byTypedUID.values {
            switch term.enumerated {
            case .dictionary(_):
                break
            case .class_(let term):
                add(classTerm: term)
            case .pluralClass(let term):
                add(classTerm: term)
            case .property(let term):
                let tags: [PropertyInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let property = PropertyInfo(term.uid, Set(tags))
                propertiesByUID[property.typedUID] = property
            case .enumerator(let term):
                let tags: [ConstantInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let constant = ConstantInfo(term.uid, Set(tags))
                constantsByUID[constant.typedUID] = constant
            case .command(let term):
                let tags: [CommandInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let command = CommandInfo(term.uid, Set(tags))
                commandsByUID[command.typedUID] = command
            case .parameter(_):
                break
            case .variable(_):
                break
            case .resource(_):
                break
            }
        }
    }
    
    private var typesByUID: [TypedTermUID : TypeInfo] = [:]
    private var typesBySupertype: [TypeInfo : [TypeInfo]] = [:]
    private var typesByName: [TermName : TypeInfo] = [:]
    
    private func add(forTypeUID uid: TermUID) -> TypeInfo {
        let info = TypeInfo(uid)
        typesByUID[TypedTermUID(.type, uid)] = info
        return info
    }
    
    public func type(forUID uid: TypedTermUID) -> TypeInfo {
        typesByUID[uid] ?? TypeInfo(uid.uid)
    }
    public func subtypes(of type: TypeInfo) -> [TypeInfo] {
        typesBySupertype[type] ?? []
    }
    public func type(for name: TermName) -> TypeInfo? {
        typesByName[name]
    }
    public func type(for code: OSType) -> TypeInfo {
        type(forUID: TypedTermUID(.type, .ae4(code: code)))
    }
    
    private var propertiesByUID: [TypedTermUID : PropertyInfo] = [:]
    
    private func add(forPropertyUID uid: TermUID) -> PropertyInfo {
        let info = PropertyInfo(uid)
        propertiesByUID[TypedTermUID(.property, uid)] = info
        return info
    }
    
    public func property(forUID uid: TypedTermUID) -> PropertyInfo {
        propertiesByUID[uid] ?? add(forPropertyUID: uid.uid)
    }
    public func property(for code: OSType) -> PropertyInfo {
        property(forUID: TypedTermUID(.property, .ae4(code: code)))
    }
    
    private var constantsByUID: [TypedTermUID : ConstantInfo] = [:]
    
    private func add(forConstantUID uid: TermUID) -> ConstantInfo {
        let info = ConstantInfo(uid)
        constantsByUID[TypedTermUID(.constant, uid)] = info
        return info
    }
    
    public func constant(forUID uid: TypedTermUID) -> ConstantInfo {
        constantsByUID[uid] ??
            propertiesByUID[TypedTermUID(.property, uid.uid)].map { ConstantInfo(property: $0) } ??
            typesByUID[TypedTermUID(.type, uid.uid)].map { ConstantInfo(type: $0) } ??
            add(forConstantUID: uid.uid)
    }
    public func constant(for code: OSType) -> ConstantInfo {
        constant(forUID: TypedTermUID(.constant, .ae4(code: code)))
    }
    
    private var commandsByUID: [TypedTermUID : CommandInfo] = [:]
    
    private func add(forCommandUID uid: TermUID) -> CommandInfo {
        let info = CommandInfo(uid)
        commandsByUID[TypedTermUID(.command, uid)] = info
        return info
    }
    
    public func command(forUID uid: TypedTermUID) -> CommandInfo {
        commandsByUID[uid] ?? add(forCommandUID: uid.uid)
    }
    
    public func retain(_ object: RT_Object) {
        var retainCount = objectPool.object(forKey: object)?.intValue ?? 0
        retainCount += 1
        objectPool.setObject(retainCount as NSNumber, forKey: object)
    }
    
    public func release(_ object: RT_Object) {
        guard var retainCount = objectPool.object(forKey: object)?.intValue else {
            os_log("Warning: runtime object overreleased", log: log)
            return
        }
        retainCount -= 1
        if retainCount > 0 {
            objectPool.setObject(retainCount as NSNumber, forKey: object)
        } else {
            objectPool.removeObject(forKey: object)
        }
    }
    
}

public extension Runtime {
    
    func run(_ program: Program) throws -> RT_Object {
        inject(terms: program.terms)
        return try run(program.ast)
    }
    
    func run(_ expression: Expression) throws -> RT_Object {
        let builtin = Builtin()
        builtin.rt = self

        builtin.stack.pushErrorHandler { message, rt in
            _ = try? RT_Global(rt).perform(command: CommandInfo(.GUI_alert), arguments: [
                ParameterInfo(.GUI_alert_kind): RT_Integer(value: 2),
                ParameterInfo(.direct): RT_String(value: "An error occurred:"),
                ParameterInfo(.GUI_alert_message): RT_String(value: message + "\n\nThe script will be terminated."),
                ParameterInfo(.GUI_alert_buttons): RT_List(contents: [
                    RT_String(value: "OK")
                ])
            ], implicitDirect: nil)
            throw RuntimeError(errorDescription: message)
        }
        
//        let module = generateLLVMModule(from: expression, builtin: builtin)
        
        // Let LLVM verify that the module's IR code is well-formed
//        do {
//            try module.verify()
//        } catch {
//            os_log("Module verification error: %@", log: log, type: .error, String(describing: error))
//        }
        
//        let pipeliner = PassPipeliner(module: module)
//        pipeliner.addStandardModulePipeline("std_module")
//        pipeliner.addStandardFunctionPipeline("std_fn")
//        pipeliner.execute()
        
        // JIT-compile the module's IR for the current machine
//        let jit = try! JIT(machine: TargetMachine())
//        _ = try! jit.addEagerlyCompiledIR(module, { (name) -> JIT.TargetAddress in
//            return JIT.TargetAddress()
//        })
        
        // Call the main function in the module and return the result
//        typealias MainPtr = @convention(c) () -> UnsafeMutableRawPointer
//        let address = try! jit.address(of: "main")
//        let main = unsafeBitCast(address, to: MainPtr.self)
//        let resultObject = Unmanaged<RT_Object>.fromOpaque(main()).takeUnretainedValue()
//        os_log("Execution result: %@", log: log, type: .debug, String(describing: resultObject))
//        return resultObject
        return RT_Null.null
        
    }
    
}

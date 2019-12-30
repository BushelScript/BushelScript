import Bushel
import LLVM
import os

private let log = OSLog(subsystem: logSubsystem, category: "RT info")

public class RTInfo {
    
    public let termPool: TermPool
    public let topScript: RT_Script
    
    private let objectPool = NSMapTable<RT_Object, NSNumber>(keyOptions: [.strongMemory, .objectPointerPersonality], valueOptions: .copyIn)
    
    public var currentApplicationBundleID: String?
    
    public init(termPool: TermPool) {
        self.termPool = termPool
        self.topScript = RT_Script()
        
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
        
        for term in termPool.byUID.values {
            switch term.enumerated {
            case .enumerator(_):
                break
            case .dictionary(_):
                break
            case .class_(let term):
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
                if let code = term.ae4Code {
                    typesByCode[code] = type
                }
            case .property(let term):
                let property = PropertyInfo(term.uid)
                propertiesByUID[property.typedUID] = property
                if let code = term.ae4Code {
                    propertiesByCode[code] = property
                }
            case .command(let term):
                let command = CommandInfo(term.uid)
                commandsByUID[command.typedUID] = command
            case .parameter(_):
                break
            case .variable(_):
                break
            case .applicationName(_):
                break
            case .applicationID(_):
                break
            }
        }
    }
    
    private var typesByUID: [TypedTermUID : TypeInfo] = [:]
    private var typesBySupertype: [TypeInfo : [TypeInfo]] = [:]
    private var typesByName: [TermName : TypeInfo] = [:]
    private var typesByCode: [OSType : TypeInfo] = [:]
    
    public func type(forUID uid: TypedTermUID) -> TypeInfo? {
        typesByUID[uid]
    }
    public func subtypes(of type: TypeInfo) -> [TypeInfo] {
        typesBySupertype[type] ?? []
    }
    public func type(for name: TermName) -> TypeInfo? {
        typesByName[name]
    }
    public func type(for code: OSType) -> TypeInfo? {
        typesByCode[code]
    }
    
    private var propertiesByUID: [TypedTermUID : PropertyInfo] = [:]
    private var propertiesByCode: [OSType : PropertyInfo] = [:]
    
    public func property(forUID uid: TypedTermUID) -> PropertyInfo? {
        propertiesByUID[uid]
    }
    public func property(for code: OSType) -> PropertyInfo? {
        propertiesByCode[code]
    }
    
    private var commandsByUID: [TypedTermUID : CommandInfo] = [:]
    
    public func command(forUID uid: TypedTermUID) -> CommandInfo? {
        commandsByUID[uid]
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

public extension RTInfo {
    
    func run(_ expression: Expression) -> RT_Object {
        Builtin.termPool = termPool
        Builtin.rt = self
        
        let module = generateLLVMModule(from: expression, rt: self)
        
        // Let LLVM verify that the module's IR code is well-formed
        do {
            try module.verify()
        } catch {
            os_log("Module verification error: %@", log: log, type: .error, String(describing: error))
        }
        
        // Load StandardAdditions.osax
        do {
            try NSAppleEventDescriptor(eventClass: FourCharCode(fourByteString: "ascr"), eventID: FourCharCode(fourByteString: "gdut"), targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: RT_Application(Builtin.rt, currentApplication: ()).bundleIdentifier), returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)).sendEvent(options: .defaultOptions, timeout: TimeInterval(kNoTimeOut))
        } catch {
            os_log("Failed to load StandardAdditions.osax: %@", log: log, type: .error, String(describing: error))
        }
        
        // JIT-compile the module's IR for the current machine
        let jit = try! JIT(machine: TargetMachine())
        typealias FnPtr = @convention(c) () -> UnsafeMutableRawPointer
        _ = try! jit.addEagerlyCompiledIR(module, { (name) -> JIT.TargetAddress in
            return JIT.TargetAddress()
        })
        
        // Call the main function in the module and return the result
        let address = try! jit.address(of: "main")
        let fn = unsafeBitCast(address, to: FnPtr.self)
        let resultObject = Unmanaged<RT_Object>.fromOpaque(fn()).takeUnretainedValue()
        #if DEBUG
        print(resultObject)
        #endif
        return resultObject
    }
    
}

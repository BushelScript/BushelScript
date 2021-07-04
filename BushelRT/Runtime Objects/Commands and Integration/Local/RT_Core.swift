import Bushel
import AEthereal

public final class RT_Core: RT_Object, RT_LocalModule {
    
    public override class var staticType: Types {
        .coreObject
    }
    
    public override var description: String {
        "Core"
    }
    
    public var functions = FunctionSet()
    
    public override init(_ rt: Runtime) {
        super.init(rt)
        
        functions.add(rt, .not, parameters: [.direct: .item]) { arguments in
            let operand = try arguments.for(.direct)
            return RT_Boolean.withValue(rt, !operand.truthy)
        }
        
        functions.add(rt, .negate, parameters: [.direct: .integer]) { arguments in
            let operand = try arguments.for(.direct, RT_Integer.self)
            return RT_Integer(rt, value: -operand.value)
        }
        functions.add(rt, .negate, parameters: [.direct: .real]) { arguments in
            let operand = try arguments.for(.direct, RT_Real.self)
            return RT_Real(rt, value: -operand.value)
        }
        
        func binary(_ operation: @escaping (RT_Object, RT_Object) throws -> RT_Object?) -> (_ arguments: RT_Arguments) throws -> RT_Object {
            { arguments in
                let lhs = try arguments.for(.lhs)
                let rhs = try arguments.for(.rhs)
                return try operation(lhs, rhs) ?? { throw CommandNotHandled(command: arguments.command) }()
            }
        }
        functions.add(rt, .or, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            RT_Boolean.withValue(rt, $0.truthy || $1.truthy)
        })
        functions.add(rt, .xor, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            let lhsTruthy = $0.truthy
            let rhsTruthy = $1.truthy
            return RT_Boolean.withValue(rt, lhsTruthy && !rhsTruthy || !lhsTruthy && rhsTruthy)
        })
        functions.add(rt, .and, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            RT_Boolean.withValue(rt, $0.truthy && $1.truthy)
        })
        functions.add(rt, .coerce, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            guard let type = ($1 as? RT_Type)?.value else {
                throw TypeObjectRequired(object: $1)
            }
            guard let coerced = $0.coerce(to: type) else {
                throw Uncoercible(expectedType: type, object: self)
            }
            return coerced
        })
        functions.add(rt, .isA, parameters: [.lhs: .item, .rhs: .type], implementation: binary {
            RT_Boolean.withValue(rt, try $0.type.isA($1.coerceOrThrow(to: RT_Type.self).value))
        })
        functions.add(rt, .isNotA, parameters: [.lhs: .item, .rhs: .type], implementation: binary {
            RT_Boolean.withValue(rt, try !$0.type.isA($1.coerceOrThrow(to: RT_Type.self).value))
        })
        functions.add(rt, .equal, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            RT_Boolean.withValue(rt, $0.compareEqual(with: $1))
        })
        functions.add(rt, .notEqual, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            RT_Boolean.withValue(rt, !$0.compareEqual(with: $1))
        })
        functions.add(rt, .less, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            $0.compare(with: $1).map { RT_Boolean.withValue(rt, $0 == .orderedAscending) }
        })
        functions.add(rt, .lessEqual, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            $0.compare(with: $1).map { RT_Boolean.withValue(rt, $0 != .orderedDescending) }
        })
        functions.add(rt, .greater, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            $0.compare(with: $1).map { RT_Boolean.withValue(rt, $0 == .orderedAscending) }
        })
        functions.add(rt, .greaterEqual, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            $0.compare(with: $1).map { RT_Boolean.withValue(rt, $0 != .orderedAscending) }
        })
        
        functions.add(rt, .notContains, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            let contains = rt.reflection.commands[.contains]
            return try RT_Boolean.withValue(rt, !rt.context.run(command: contains, arguments: [contains.parameters[.lhs]: $0, contains.parameters[.rhs]: $1]).truthy)
        })
        functions.add(rt, .containedBy, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            let contains = rt.reflection.commands[.contains]
            return try RT_Boolean.withValue(rt, rt.context.run(command: contains, arguments: [contains.parameters[.lhs]: $1, contains.parameters[.rhs]: $0]).truthy)
        })
        functions.add(rt, .notContainedBy, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            let contains = rt.reflection.commands[.contains]
            return try RT_Boolean.withValue(rt, !rt.context.run(command: contains, arguments: [contains.parameters[.lhs]: $1, contains.parameters[.rhs]: $0]).truthy)
        })
        
        functions.add(rt, .startsWith, parameters: [.lhs: .string, .rhs: .string], implementation: binary {
            RT_Boolean.withValue(rt, try $0.coerceOrThrow(to: RT_String.self).value.hasPrefix($1.coerceOrThrow(to: RT_String.self).value))
        })
        functions.add(rt, .endsWith, parameters: [.lhs: .string, .rhs: .string], implementation: binary {
            RT_Boolean.withValue(rt, try $0.coerceOrThrow(to: RT_String.self).value.hasSuffix($1.coerceOrThrow(to: RT_String.self).value))
        })
        functions.add(rt, .contains, parameters: [.lhs: .string, .rhs: .string], implementation: binary {
            RT_Boolean.withValue(rt, try $0.coerceOrThrow(to: RT_String.self).value.contains($1.coerceOrThrow(to: RT_String.self).value))
        })
        
        functions.add(rt, .contains, parameters: [.lhs: .list, .rhs: .item], implementation: binary {
            RT_Boolean.withValue(rt, try $0.coerceOrThrow(to: RT_List.self).contents.contains($1))
        })
        
        // (integer, integer)
        functions.add(rt, .add, parameters: [.lhs: .integer, .rhs: .integer], implementation: binary {
            RT_Integer(rt, value: try $0.coerceOrThrow(to: RT_Integer.self).value + $1.coerceOrThrow(to: RT_Integer.self).value)
        })
        functions.add(rt, .subtract, parameters: [.lhs: .integer, .rhs: .integer], implementation: binary {
            RT_Integer(rt, value: try $0.coerceOrThrow(to: RT_Integer.self).value - $1.coerceOrThrow(to: RT_Integer.self).value)
        })
        functions.add(rt, .multiply, parameters: [.lhs: .integer, .rhs: .integer], implementation: binary {
            RT_Integer(rt, value: try $0.coerceOrThrow(to: RT_Integer.self).value * $1.coerceOrThrow(to: RT_Integer.self).value)
        })
        functions.add(rt, .divide, parameters: [.lhs: .integer, .rhs: .integer], implementation: binary {
            RT_Real(rt, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) / Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        
        // (real, real)
        functions.add(rt, .add, parameters: [.lhs: .real, .rhs: .real], implementation: binary {
            RT_Real(rt, value: try $0.coerceOrThrow(to: RT_Real.self).value + $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .subtract, parameters: [.lhs: .real, .rhs: .real], implementation: binary {
            RT_Real(rt, value: try $0.coerceOrThrow(to: RT_Real.self).value - $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .multiply, parameters: [.lhs: .real, .rhs: .real], implementation: binary {
            RT_Real(rt, value: try $0.coerceOrThrow(to: RT_Real.self).value * $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .divide, parameters: [.lhs: .real, .rhs: .real], implementation: binary {
            RT_Real(rt, value: try $0.coerceOrThrow(to: RT_Real.self).value / $1.coerceOrThrow(to: RT_Real.self).value)
        })
        
        // (integer, real)
        functions.add(rt, .add, parameters: [.lhs: .integer, .rhs: .real], implementation: binary {
            RT_Real(rt, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) + $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .subtract, parameters: [.lhs: .integer, .rhs: .real], implementation: binary {
            RT_Real(rt, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) - $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .multiply, parameters: [.lhs: .integer, .rhs: .real], implementation: binary {
            RT_Real(rt, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) * $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .divide, parameters: [.lhs: .integer, .rhs: .real], implementation: binary {
            RT_Real(rt, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) / $1.coerceOrThrow(to: RT_Real.self).value)
        })
        
        // (real, integer)
        functions.add(rt, .add, parameters: [.lhs: .real, .rhs: .integer], implementation: binary {
            RT_Real(rt, value: try $0.coerceOrThrow(to: RT_Real.self).value + Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        functions.add(rt, .subtract, parameters: [.lhs: .real, .rhs: .integer], implementation: binary {
            RT_Real(rt, value: try $0.coerceOrThrow(to: RT_Real.self).value - Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        functions.add(rt, .multiply, parameters: [.lhs: .real, .rhs: .integer], implementation: binary {
            RT_Real(rt, value: try $0.coerceOrThrow(to: RT_Real.self).value * Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        functions.add(rt, .divide, parameters: [.lhs: .real, .rhs: .integer], implementation: binary {
            RT_Real(rt, value: try $0.coerceOrThrow(to: RT_Real.self).value / Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        
        functions.add(rt, .concatenate, parameters: [.lhs: .string, .rhs: .string], implementation: binary {
            RT_String(rt, value: try $0.coerceOrThrow(to: RT_String.self).value + $1.coerceOrThrow(to: RT_String.self).value)
        })
        functions.add(rt, .concatenate, parameters: [.lhs: .string, .rhs: .item], implementation: binary {
            RT_String(rt, value: try $0.coerceOrThrow(to: RT_String.self).value + ($1.coerce(to: RT_String.self)?.value ?? "\($1)"))
        })
        functions.add(rt, .concatenate, parameters: [.lhs: .item, .rhs: .string], implementation: binary {
            RT_String(rt, value: try ($0.coerce(to: RT_String.self)?.value ?? "\($0)") + $1.coerceOrThrow(to: RT_String.self).value)
        })
        
        functions.add(rt, .concatenate, parameters: [.lhs: .list, .rhs: .list], implementation: binary {
            RT_List(rt, contents: try $0.coerceOrThrow(to: RT_List.self).contents + $1.coerceOrThrow(to: RT_List.self).contents)
        })
        functions.add(rt, .concatenate, parameters: [.lhs: .list, .rhs: .item], implementation: binary {
            RT_List(rt, contents: try $0.coerceOrThrow(to: RT_List.self).contents + [$1])
        })
        functions.add(rt, .concatenate, parameters: [.lhs: .item, .rhs: .list], implementation: binary {
            RT_List(rt, contents: try [$0] + $1.coerceOrThrow(to: RT_List.self).contents)
        })
        
        functions.add(rt, .run, parameters: [.target: .function, .direct: .item]) { arguments in
            let function = try arguments.for(.target, RT_Function.self)
            return try function.implementation.run(arguments: arguments)
        }
        
        functions.add(rt, .set, parameters: [.direct: .specifier, .set_to: .item]) { arguments in
            let specifier = try arguments.for(.direct, RT_Specifier.self)
            let newValue = try arguments.for(.set_to)
            guard case let .property(property) = specifier.kind else {
                throw NonPropertyIsNotWritable()
            }
            try specifier.parent.evaluate().setProperty(property, to: newValue)
            return newValue
        }
        
        functions.add(rt, .delay, parameters: [.direct: .integer]) { arguments in
            var delaySeconds = arguments[.direct, RT_Real.self]?.value ?? 1.0
            while delaySeconds > 0 {
                try rt.terminateIfNeeded()
                Thread.sleep(forTimeInterval: min(2.0, delaySeconds))
                delaySeconds -= 2.0
            }
            return rt.lastResult
        }
        functions.add(rt, .delay, parameters: [.direct: .real]) { arguments in
            var delaySeconds = arguments[.direct, RT_Real.self]?.value ?? 1.0
            while delaySeconds > 0 {
                try rt.terminateIfNeeded()
                Thread.sleep(forTimeInterval: min(2.0, delaySeconds))
                delaySeconds -= 2.0
            }
            return rt.lastResult
        }
        
        functions.add(rt, .list_add, parameters: [.target: .list, .direct: .item]) { arguments in
            let list = try arguments.for(.target, RT_List.self)
            let toAdd = try arguments.for(.direct)
            list.contents.append(toAdd)
            return list
        }
        functions.add(rt, .list_remove, parameters: [.target: .list, .direct: .item]) { arguments in
            let list = try arguments.for(.target, RT_List.self)
            let toRemove = try arguments.for(.direct)
            if let index = list.contents.firstIndex(where: { toRemove.compareEqual(with: $0) }) {
                list.contents.remove(at: index)
            }
            return list
        }
        functions.add(rt, .list_pluck, parameters: [.target: .list, .direct: .item]) { arguments in
            let list = try arguments.for(.target, RT_List.self)
            let toTake = try arguments.for(.direct)
            if let index = list.contents.firstIndex(where: { toTake.compareEqual(with: $0) }) {
                let item = list.contents[index]
                list.contents.remove(at: index)
                return item
            } else {
                return rt.missing
            }
        }
        
        functions.add(rt, .real_abs, parameters: [.direct: .integer]) { arguments in
            RT_Integer(rt, value: abs(try arguments.for(.direct, RT_Integer.self).value))
        }
        functions.add(rt, .real_abs, parameters: [.direct: .real]) { arguments in
            RT_Real(rt, value: abs(try arguments.for(.direct, RT_Real.self).value))
        }
        functions.add(rt, .real_sqrt, parameters: [.direct: .integer]) { arguments in
            RT_Real(rt, value: sqrt(Double(try arguments.for(.direct, RT_Integer.self).value)))
        }
        functions.add(rt, .real_sqrt, parameters: [.direct: .real]) { arguments in
            RT_Real(rt, value: sqrt(try arguments.for(.direct, RT_Real.self).value))
        }
        functions.add(rt, .real_cbrt, parameters: [.direct: .integer]) { arguments in
            RT_Real(rt, value: cbrt(Double(try arguments.for(.direct, RT_Integer.self).value)))
        }
        functions.add(rt, .real_cbrt, parameters: [.direct: .real]) { arguments in
            RT_Real(rt, value: cbrt(try arguments.for(.direct, RT_Real.self).value))
        }
        functions.add(rt, .real_pow, parameters: [.direct: .integer, .real_pow_exponent: .integer]) { arguments in
            let integer = try arguments.for(.direct, RT_Integer.self)
            let exponent = try arguments.for(.real_pow_exponent, RT_Integer.self)
            return RT_Integer(rt, value: Int64(pow(Double(integer.value), Double(exponent.value))))
        }
        functions.add(rt, .real_pow, parameters: [.direct: .integer, .real_pow_exponent: .real]) { arguments in
            let integer = try arguments.for(.direct, RT_Integer.self)
            let exponent = try arguments.for(.real_pow_exponent, RT_Real.self)
            return RT_Real(rt, value: pow(Double(integer.value), exponent.value))
        }
        functions.add(rt, .real_pow, parameters: [.direct: .real, .real_pow_exponent: .integer]) { arguments in
            let real = try arguments.for(.direct, RT_Real.self)
            let exponent = try arguments.for(.real_pow_exponent, RT_Integer.self)
            return RT_Real(rt, value: pow(real.value, Double(exponent.value)))
        }
        functions.add(rt, .real_pow, parameters: [.direct: .real, .real_pow_exponent: .real]) { arguments in
            let real = try arguments.for(.direct, RT_Real.self)
            let exponent = try arguments.for(.real_pow_exponent, RT_Real.self)
            return RT_Real(rt, value: pow(real.value, exponent.value))
        }
        func elementaryFunction(_ function: @escaping (Double) -> Double) -> (_ arguments: RT_Arguments) throws -> RT_Real {
            { arguments in
                let real = try arguments.for(.direct, RT_Real.self)
                return RT_Real(rt, value: function(real.value))
            }
        }
        functions.add(rt, .real_ln, parameters: [.direct: .real], implementation: elementaryFunction(log))
        functions.add(rt, .real_log10, parameters: [.direct: .real], implementation: elementaryFunction(log10))
        functions.add(rt, .real_log2, parameters: [.direct: .real], implementation: elementaryFunction(log2))
        functions.add(rt, .real_sin, parameters: [.direct: .real], implementation: elementaryFunction(sin))
        functions.add(rt, .real_cos, parameters: [.direct: .real], implementation: elementaryFunction(cos))
        functions.add(rt, .real_tan, parameters: [.direct: .real], implementation: elementaryFunction(tan))
        functions.add(rt, .real_asin, parameters: [.direct: .real], implementation: elementaryFunction(asin))
        functions.add(rt, .real_acos, parameters: [.direct: .real], implementation: elementaryFunction(acos))
        functions.add(rt, .real_atan, parameters: [.direct: .real], implementation: elementaryFunction(atan))
        functions.add(rt, .real_atan2, parameters: [.direct: .real, .real_atan2_x: .real]) { arguments in
            let y = try arguments.for(.direct, RT_Real.self)
            let x = try arguments.for(.real_atan2_x, RT_Real.self)
            return RT_Real(rt, value: atan2(y.value, x.value))
        }
        functions.add(rt, .real_round, parameters: [.direct: .real], implementation: elementaryFunction(round))
        functions.add(rt, .real_ceil, parameters: [.direct: .real], implementation: elementaryFunction(ceil))
        functions.add(rt, .real_floor, parameters: [.direct: .real], implementation: elementaryFunction(floor))

        functions.add(rt, .log, parameters: [.direct: .item]) { arguments in
            let message = try arguments.for(.direct)
            print(message.coerce(to: RT_String.self)?.value ?? String(describing: message))
            return rt.lastResult
        }
    }
    
    public func handle(_ arguments: RT_Arguments) throws -> RT_Object? {
        if
            let commandClass = arguments.command.id.ae8Code?.class,
            commandClass == (try! FourCharCode(fourByteString: "bShG"))
        {
            // Run GUIHost command
            guard let guiHostBundle = Bundle(applicationBundleIdentifier: "com.justcheesy.BushelGUIHost") else {
                throw MissingResource(resourceDescription: "BushelGUIHost application")
            }
            
            var arguments = arguments
            if
                arguments.contents.first(where: { $0.key.uri.ae4Code == Parameters.ask_title.ae12Code!.code }) == nil,
                let scriptName = Optional("")//rt.topScript.name
            // FIXME: fix
            {
                arguments.contents[Reflection.Parameter(.ask_title)] = RT_String(rt, value: scriptName)
            }
            
            return try RT_Application(rt, bundle: guiHostBundle).handle(arguments)
        }
        
        return try self.handleByLocalFunction(arguments)
    }
    
    public override func property(_ property: Reflection.Property) throws -> RT_Object? {
        switch Properties(property.id) {
        case .arguments:
            return RT_List(rt, contents: rt.arguments.map { RT_String.init(rt, value: $0) })
        case .currentDate:
            return RT_Date(rt, value: Date())
        case .real_NaN:
            return RT_Real(rt, value: Double.nan)
        case .real_inf:
            return RT_Real(rt, value: Double.infinity)
        case .real_pi:
            return RT_Real(rt, value: Double.pi)
        case .real_e:
            return RT_Real(rt, value: exp(1))
        default:
            return nil
        }
    }
    
    public override func element(_ type: Reflection.`Type`, named name: String) throws -> RT_Object? {
        func element() -> RT_Object? {
            switch Types(type.uri) {
            case .app:
                return RT_Application(rt, named: name)
            case .file:
                return RT_File(rt, value: URL(fileURLWithPath: (name as NSString).expandingTildeInPath))
            case .environmentVariable:
                return RT_EnvVar(rt, name: name)
            default:
                return nil
            }
        }
        guard let elem = element() else {
            return try super.element(type, named: name)
        }
        return elem
    }
    
    public override func element(_ type: Reflection.`Type`, id: RT_Object) throws -> RT_Object? {
        func element() -> RT_Object? {
            switch Types(type.uri) {
            case .app:
                guard
                    let appBundleID = id.coerce(to: RT_String.self)?.value,
                    let appBundle = Bundle(applicationBundleIdentifier: appBundleID)
                else {
                    return nil
                }
                return RT_Application(rt, bundle: appBundle)
            default:
                return nil
            }
        }
        guard let elem = element() else {
            return try super.element(type, id: id)
        }
        return elem
    }
    
    public override func elements(_ type: Reflection.`Type`) throws -> RT_Object {
        switch Types(type.uri) {
        case .environmentVariable:
            return RT_List(rt, contents: ProcessInfo.processInfo.environment.keys.map { RT_EnvVar(rt, name: $0) })
        default:
            return try super.elements(type)
        }
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        other.type.isA(type)
    }
    
    public override var hash: Int {
        type.hashValue
    }
    
}

extension RT_Core {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}

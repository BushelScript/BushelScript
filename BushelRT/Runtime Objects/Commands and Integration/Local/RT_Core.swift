import Bushel
import AEthereal
import UserNotifications
import os.log

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

public final class RT_Core: RT_Object, RT_LocalModule {
    
    public override class var staticType: Types {
        .coreObject
    }
    
    public override var description: String {
        "Core"
    }
    
    public var functions = FunctionSet()
    
    public override init(_ rtStrongReferenceDoNotCaptureInClosure: Runtime) {
        super.init(rtStrongReferenceDoNotCaptureInClosure)
        
        functions.add(rt, .not, parameters: [.direct: .item]) { arguments in
            let operand = try arguments.for(.direct)
            return RT_Boolean.withValue(arguments.rt, !operand.truthy)
        }
        
        functions.add(rt, .negate, parameters: [.direct: .integer]) { arguments in
            let operand = try arguments.for(.direct, RT_Integer.self)
            return RT_Integer(arguments.rt, value: -operand.value)
        }
        functions.add(rt, .negate, parameters: [.direct: .real]) { arguments in
            let operand = try arguments.for(.direct, RT_Real.self)
            return RT_Real(arguments.rt, value: -operand.value)
        }
        
        func binary(_ operation: @escaping (RT_Object, RT_Object, Runtime) throws -> RT_Object?) -> (_ arguments: RT_Arguments) throws -> RT_Object {
            { arguments in
                let lhs = try arguments.for(.lhs)
                let rhs = try arguments.for(.rhs)
                return try operation(lhs, rhs, arguments.rt) ?? { throw CommandNotHandled(command: arguments.command) }()
            }
        }
        functions.add(rt, .or, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            RT_Boolean.withValue($2, $0.truthy || $1.truthy)
        })
        functions.add(rt, .xor, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            let lhsTruthy = $0.truthy
            let rhsTruthy = $1.truthy
            return RT_Boolean.withValue($2, lhsTruthy && !rhsTruthy || !lhsTruthy && rhsTruthy)
        })
        functions.add(rt, .and, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            RT_Boolean.withValue($2, $0.truthy && $1.truthy)
        })
        functions.add(rt, .coerce, parameters: [.lhs: .item, .rhs: .item], implementation: binary { lhs, rhs, rt in
            guard let type = (rhs as? RT_Type)?.value else {
                throw TypeObjectRequired(object: rhs)
            }
            guard let coerced = lhs.coerce(to: type) else {
                throw Uncoercible(expectedType: type, object: self)
            }
            return coerced
        })
        functions.add(rt, .isA, parameters: [.lhs: .item, .rhs: .type], implementation: binary {
            RT_Boolean.withValue($2, try $0.type.isA($1.coerceOrThrow(to: RT_Type.self).value))
        })
        functions.add(rt, .isNotA, parameters: [.lhs: .item, .rhs: .type], implementation: binary {
            RT_Boolean.withValue($2, try !$0.type.isA($1.coerceOrThrow(to: RT_Type.self).value))
        })
        functions.add(rt, .equal, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            RT_Boolean.withValue($2, $0.compareEqual(with: $1))
        })
        functions.add(rt, .notEqual, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            RT_Boolean.withValue($2, !$0.compareEqual(with: $1))
        })
        functions.add(rt, .less, parameters: [.lhs: .item, .rhs: .item], implementation: binary { lhs, rhs, rt in
            lhs.compare(with: rhs).map { RT_Boolean.withValue(rt, $0 == .orderedAscending) }
        })
        functions.add(rt, .lessEqual, parameters: [.lhs: .item, .rhs: .item], implementation: binary { lhs, rhs, rt in
            lhs.compare(with: rhs).map { RT_Boolean.withValue(rt, $0 != .orderedDescending) }
        })
        functions.add(rt, .greater, parameters: [.lhs: .item, .rhs: .item], implementation: binary { lhs, rhs, rt in
            lhs.compare(with: rhs).map { RT_Boolean.withValue(rt, $0 == .orderedAscending) }
        })
        functions.add(rt, .greaterEqual, parameters: [.lhs: .item, .rhs: .item], implementation: binary { lhs, rhs, rt in
            lhs.compare(with: rhs).map { RT_Boolean.withValue(rt, $0 != .orderedAscending) }
        })
        
        functions.add(rt, .notContains, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            let contains = $2.reflection.commands[.contains]
            return try RT_Boolean.withValue($2, !$2.context.run(command: contains, arguments: [contains.parameters[.lhs]: $0, contains.parameters[.rhs]: $1]).truthy)
        })
        functions.add(rt, .containedBy, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            let contains = $2.reflection.commands[.contains]
            return try RT_Boolean.withValue($2, $2.context.run(command: contains, arguments: [contains.parameters[.lhs]: $1, contains.parameters[.rhs]: $0]).truthy)
        })
        functions.add(rt, .notContainedBy, parameters: [.lhs: .item, .rhs: .item], implementation: binary {
            let contains = $2.reflection.commands[.contains]
            return try RT_Boolean.withValue($2, !$2.context.run(command: contains, arguments: [contains.parameters[.lhs]: $1, contains.parameters[.rhs]: $0]).truthy)
        })
        
        functions.add(rt, .startsWith, parameters: [.lhs: .string, .rhs: .string], implementation: binary {
            RT_Boolean.withValue($2, try $0.coerceOrThrow(to: RT_String.self).value.hasPrefix($1.coerceOrThrow(to: RT_String.self).value))
        })
        functions.add(rt, .endsWith, parameters: [.lhs: .string, .rhs: .string], implementation: binary {
            RT_Boolean.withValue($2, try $0.coerceOrThrow(to: RT_String.self).value.hasSuffix($1.coerceOrThrow(to: RT_String.self).value))
        })
        functions.add(rt, .contains, parameters: [.lhs: .string, .rhs: .string], implementation: binary {
            RT_Boolean.withValue($2, try $0.coerceOrThrow(to: RT_String.self).value.contains($1.coerceOrThrow(to: RT_String.self).value))
        })
        
        functions.add(rt, .contains, parameters: [.lhs: .list, .rhs: .item], implementation: binary {
            RT_Boolean.withValue($2, try $0.coerceOrThrow(to: RT_List.self).contents.contains($1))
        })
        
        // (integer, integer)
        functions.add(rt, .add, parameters: [.lhs: .integer, .rhs: .integer], implementation: binary {
            RT_Integer($2, value: try $0.coerceOrThrow(to: RT_Integer.self).value + $1.coerceOrThrow(to: RT_Integer.self).value)
        })
        functions.add(rt, .subtract, parameters: [.lhs: .integer, .rhs: .integer], implementation: binary {
            RT_Integer($2, value: try $0.coerceOrThrow(to: RT_Integer.self).value - $1.coerceOrThrow(to: RT_Integer.self).value)
        })
        functions.add(rt, .multiply, parameters: [.lhs: .integer, .rhs: .integer], implementation: binary {
            RT_Integer($2, value: try $0.coerceOrThrow(to: RT_Integer.self).value * $1.coerceOrThrow(to: RT_Integer.self).value)
        })
        functions.add(rt, .divide, parameters: [.lhs: .integer, .rhs: .integer], implementation: binary {
            RT_Real($2, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) / Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        
        // (real, real)
        functions.add(rt, .add, parameters: [.lhs: .real, .rhs: .real], implementation: binary {
            RT_Real($2, value: try $0.coerceOrThrow(to: RT_Real.self).value + $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .subtract, parameters: [.lhs: .real, .rhs: .real], implementation: binary {
            RT_Real($2, value: try $0.coerceOrThrow(to: RT_Real.self).value - $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .multiply, parameters: [.lhs: .real, .rhs: .real], implementation: binary {
            RT_Real($2, value: try $0.coerceOrThrow(to: RT_Real.self).value * $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .divide, parameters: [.lhs: .real, .rhs: .real], implementation: binary {
            RT_Real($2, value: try $0.coerceOrThrow(to: RT_Real.self).value / $1.coerceOrThrow(to: RT_Real.self).value)
        })
        
        // (integer, real)
        functions.add(rt, .add, parameters: [.lhs: .integer, .rhs: .real], implementation: binary {
            RT_Real($2, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) + $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .subtract, parameters: [.lhs: .integer, .rhs: .real], implementation: binary {
            RT_Real($2, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) - $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .multiply, parameters: [.lhs: .integer, .rhs: .real], implementation: binary {
            RT_Real($2, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) * $1.coerceOrThrow(to: RT_Real.self).value)
        })
        functions.add(rt, .divide, parameters: [.lhs: .integer, .rhs: .real], implementation: binary {
            RT_Real($2, value: try Double($0.coerceOrThrow(to: RT_Integer.self).value) / $1.coerceOrThrow(to: RT_Real.self).value)
        })
        
        // (real, integer)
        functions.add(rt, .add, parameters: [.lhs: .real, .rhs: .integer], implementation: binary {
            RT_Real($2, value: try $0.coerceOrThrow(to: RT_Real.self).value + Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        functions.add(rt, .subtract, parameters: [.lhs: .real, .rhs: .integer], implementation: binary {
            RT_Real($2, value: try $0.coerceOrThrow(to: RT_Real.self).value - Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        functions.add(rt, .multiply, parameters: [.lhs: .real, .rhs: .integer], implementation: binary {
            RT_Real($2, value: try $0.coerceOrThrow(to: RT_Real.self).value * Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        functions.add(rt, .divide, parameters: [.lhs: .real, .rhs: .integer], implementation: binary {
            RT_Real($2, value: try $0.coerceOrThrow(to: RT_Real.self).value / Double($1.coerceOrThrow(to: RT_Integer.self).value))
        })
        
        functions.add(rt, .concatenate, parameters: [.lhs: .string, .rhs: .string], implementation: binary {
            RT_String($2, value: try $0.coerceOrThrow(to: RT_String.self).value + $1.coerceOrThrow(to: RT_String.self).value)
        })
        functions.add(rt, .concatenate, parameters: [.lhs: .string, .rhs: .item], implementation: binary {
            RT_String($2, value: try $0.coerceOrThrow(to: RT_String.self).value + ($1.coerce(to: RT_String.self)?.value ?? "\($1)"))
        })
        functions.add(rt, .concatenate, parameters: [.lhs: .item, .rhs: .string], implementation: binary {
            RT_String($2, value: try ($0.coerce(to: RT_String.self)?.value ?? "\($0)") + $1.coerceOrThrow(to: RT_String.self).value)
        })
        
        functions.add(rt, .concatenate, parameters: [.lhs: .list, .rhs: .list], implementation: binary {
            RT_List($2, contents: try $0.coerceOrThrow(to: RT_List.self).contents + $1.coerceOrThrow(to: RT_List.self).contents)
        })
        functions.add(rt, .concatenate, parameters: [.lhs: .list, .rhs: .item], implementation: binary {
            RT_List($2, contents: try $0.coerceOrThrow(to: RT_List.self).contents + [$1])
        })
        functions.add(rt, .concatenate, parameters: [.lhs: .item, .rhs: .list], implementation: binary {
            RT_List($2, contents: try [$0] + $1.coerceOrThrow(to: RT_List.self).contents)
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
                try arguments.rt.terminateIfNeeded()
                Thread.sleep(forTimeInterval: min(2.0, delaySeconds))
                delaySeconds -= 2.0
            }
            return arguments.rt.lastResult
        }
        functions.add(rt, .delay, parameters: [.direct: .real]) { arguments in
            var delaySeconds = arguments[.direct, RT_Real.self]?.value ?? 1.0
            while delaySeconds > 0 {
                try arguments.rt.terminateIfNeeded()
                Thread.sleep(forTimeInterval: min(2.0, delaySeconds))
                delaySeconds -= 2.0
            }
            return arguments.rt.lastResult
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
                return arguments.rt.missing
            }
        }
        
        functions.add(rt, .real_abs, parameters: [.direct: .integer]) { arguments in
            RT_Integer(arguments.rt, value: abs(try arguments.for(.direct, RT_Integer.self).value))
        }
        functions.add(rt, .real_abs, parameters: [.direct: .real]) { arguments in
            RT_Real(arguments.rt, value: abs(try arguments.for(.direct, RT_Real.self).value))
        }
        functions.add(rt, .real_sqrt, parameters: [.direct: .integer]) { arguments in
            RT_Real(arguments.rt, value: sqrt(Double(try arguments.for(.direct, RT_Integer.self).value)))
        }
        functions.add(rt, .real_sqrt, parameters: [.direct: .real]) { arguments in
            RT_Real(arguments.rt, value: sqrt(try arguments.for(.direct, RT_Real.self).value))
        }
        functions.add(rt, .real_cbrt, parameters: [.direct: .integer]) { arguments in
            RT_Real(arguments.rt, value: cbrt(Double(try arguments.for(.direct, RT_Integer.self).value)))
        }
        functions.add(rt, .real_cbrt, parameters: [.direct: .real]) { arguments in
            RT_Real(arguments.rt, value: cbrt(try arguments.for(.direct, RT_Real.self).value))
        }
        functions.add(rt, .real_pow, parameters: [.direct: .integer, .real_pow_exponent: .integer]) { arguments in
            let integer = try arguments.for(.direct, RT_Integer.self)
            let exponent = try arguments.for(.real_pow_exponent, RT_Integer.self)
            return RT_Integer(arguments.rt, value: Int64(pow(Double(integer.value), Double(exponent.value))))
        }
        functions.add(rt, .real_pow, parameters: [.direct: .integer, .real_pow_exponent: .real]) { arguments in
            let integer = try arguments.for(.direct, RT_Integer.self)
            let exponent = try arguments.for(.real_pow_exponent, RT_Real.self)
            return RT_Real(arguments.rt, value: pow(Double(integer.value), exponent.value))
        }
        functions.add(rt, .real_pow, parameters: [.direct: .real, .real_pow_exponent: .integer]) { arguments in
            let real = try arguments.for(.direct, RT_Real.self)
            let exponent = try arguments.for(.real_pow_exponent, RT_Integer.self)
            return RT_Real(arguments.rt, value: pow(real.value, Double(exponent.value)))
        }
        functions.add(rt, .real_pow, parameters: [.direct: .real, .real_pow_exponent: .real]) { arguments in
            let real = try arguments.for(.direct, RT_Real.self)
            let exponent = try arguments.for(.real_pow_exponent, RT_Real.self)
            return RT_Real(arguments.rt, value: pow(real.value, exponent.value))
        }
        func elementaryFunction(_ function: @escaping (Double) -> Double) -> (_ arguments: RT_Arguments) throws -> RT_Real {
            { arguments in
                let real = try arguments.for(.direct, RT_Real.self)
                return RT_Real(arguments.rt, value: function(real.value))
            }
        }
        functions.add(rt, .real_ln, parameters: [.direct: .real], implementation: elementaryFunction(Darwin.log))
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
            return RT_Real(arguments.rt, value: atan2(y.value, x.value))
        }
        functions.add(rt, .real_round, parameters: [.direct: .real], implementation: elementaryFunction(round))
        functions.add(rt, .real_ceil, parameters: [.direct: .real], implementation: elementaryFunction(ceil))
        functions.add(rt, .real_floor, parameters: [.direct: .real], implementation: elementaryFunction(floor))

        functions.add(rt, .log, parameters: [.direct: .item]) { arguments in
            let message = try arguments.for(.direct)
            print(message.coerce(to: RT_String.self)?.value ?? String(describing: message))
            return arguments.rt.lastResult
        }
        
        functions.add(rt, .notification, parameters: [
            .direct: .item,
            .notification_title: .item,
            .notification_subtitle: .item,
            .notification_sound: .item
        ]) { arguments in
            let message = arguments[.direct, RT_String.self]
            let title = arguments[.notification_title, RT_String.self]
            let subtitle = arguments[.notification_subtitle, RT_String.self]
            let soundName = arguments[.notification_sound, RT_String.self]
            
            let content = UNMutableNotificationContent()
            if let title = title {
                content.title = title.value
                content.body = message?.value ?? ""
            } else {
                content.title = message?.value ?? ""
            }
            content.subtitle = subtitle?.value ?? ""
            content.sound = soundName.map { soundName in
                UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName.value))
            }
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.requestAuthorization(options: [.sound, .alert]) { (isAuthorized, error) in
                if let error = error {
                    os_log("Error requesting user notification authorization: %@", log: log, "\(error)")
                    DispatchQueue.main.async {
                        NSApplication.shared.presentError(error)
                    }
                }
                guard isAuthorized else {
                    os_log("Not authorized to send user notifications", log: log)
                    return
                }
                
                notificationCenter.add(request, withCompletionHandler: { error in
                    if let error = error {
                        os_log("Error delivering user notification: %@", log: log, "\(error)")
                        DispatchQueue.main.async {
                            NSApp.presentError(error)
                        }
                    }
                })
            }
            
            return arguments.rt.lastResult
        }
        functions.add(rt, .alert, parameters: [
            .direct: .item,
            .alert_message: .item,
            .alert_title: .item
        ]) { arguments in
            let heading = arguments[.direct, RT_String.self]
            let message = arguments[.alert_message, RT_String.self]
            let title = arguments[.alert_title, RT_String.self]
            
            return DispatchQueue.main.sync {
                let wc = AlertWC(windowNibName: "AlertWC")
                wc.loadWindow()
                wc.heading = heading?.value
                wc.message = message?.value
                
                let window = wc.window!
                window.title = title?.value ?? ""
                
                displayModally(window: window)
                return wc.response.map { RT_String(arguments.rt, value: $0) } ?? arguments.rt.missing
            }
        }
        functions.add(rt, .chooseFrom, parameters: [
            .direct: .list,
            .chooseFrom_prompt: .item,
            .chooseFrom_confirm: .item,
            .chooseFrom_cancel: .item,
            .chooseFrom_title: .item
        ]) { arguments in
            let items = try arguments.for(.direct, RT_List.self).contents
            let prompt = arguments[.chooseFrom_prompt, RT_String.self]
            let okButtonName = arguments[.chooseFrom_confirm, RT_String.self]
            let cancelButtonName = arguments[.chooseFrom_cancel, RT_String.self]
            let title = arguments[.chooseFrom_title, RT_String.self]
            
            return DispatchQueue.main.sync {
                let wc = ChooseFromWC(windowNibName: "ChooseFromWC")
                wc.loadWindow()
                wc.items = items.map { item in
                    (item.coerce(to: RT_String.self)?.value ?? "\(item)")
                }
                wc.prompt = prompt?.value ?? "Please select an option."
                wc.okButtonName = okButtonName?.value ?? "OK"
                wc.cancelButtonName = cancelButtonName?.value ?? "Cancel"
                
                let window = wc.window!
                window.title = title?.value ?? arguments.rt.topScript.name ?? ""
                
                displayModally(window: window)
                return wc.response.map { RT_String(arguments.rt, value: $0) } ?? arguments.rt.missing
            }
        }
        functions.add(rt, .ask, parameters: [
            .ask_dataType: .type,
            .direct: .item,
            .ask_title: .item
        ]) { arguments in
            typealias Constructor = () -> RT_Object
            
            func makeViewController(for type: Reflection.`Type`) -> (NSViewController, Constructor) {
                func uneditableVC() -> (UneditableVC, Constructor) {
                    (UneditableVC(), { arguments.rt.missing })
                }
                func fileChooserVC(defaultLocation: URL? = nil, constructor: @escaping (FileChooserVC) -> RT_Object) -> (FileChooserVC, Constructor) {
                    let vc = FileChooserVC(defaultLocation: defaultLocation)
                    return (vc, { constructor(vc) })
                }
                func radioChoicesVC(choices: [String], constructor: @escaping (RadioChoicesVC) -> RT_Object) -> (RadioChoicesVC, Constructor) {
                    let vc = RadioChoicesVC()
                    for choice in choices {
                        vc.addChoice(named: choice)
                    }
                    return (vc, { constructor(vc) })
                }
                func checkboxVC(constructor: @escaping (CheckboxVC) -> RT_Object) -> (CheckboxVC, Constructor) {
                    let vc = CheckboxVC()
                    return (vc, { constructor(vc) })
                }
                func textFieldVC(characterLimit: Int? = nil, constructor: @escaping (TextFieldVC) -> RT_Object) -> (TextFieldVC, Constructor) {
                    let vc = TextFieldVC()
                    vc.characterLimit = characterLimit
                    return (vc, { constructor(vc) })
                }
                func numberFieldVC(integersOnly: Bool = false, constructor: @escaping (NumberFieldVC) -> RT_Object) -> (NumberFieldVC, Constructor) {
                    let vc = NumberFieldVC()
                    vc.integersOnly = integersOnly
                    return (vc, { constructor(vc) })
                }
                
                switch Types(type.uri) {
                case .boolean:
                    return checkboxVC { RT_Boolean.withValue(arguments.rt, $0.value) }
                case .string:
                    return textFieldVC { RT_String(arguments.rt, value: $0.value) }
                case .character:
                    return textFieldVC(characterLimit: 1) { $0.value.first.map { RT_Character(arguments.rt, value: $0) } ?? arguments.rt.missing }
                case .number:
                    return numberFieldVC() { RT_Real(arguments.rt, value: $0.value.doubleValue) }
                case .integer:
                    return numberFieldVC(integersOnly: true) { RT_Integer(arguments.rt, value: $0.value.int64Value) }
                case .real:
                    return numberFieldVC() { RT_Real(arguments.rt, value: $0.value.doubleValue) }
                case .file, .alias:
                    return fileChooserVC() { RT_File(arguments.rt, value: $0.location) }
                default:
                    // TODO: Implement for custom types
                    return uneditableVC()
                }
            }
            
            let type = arguments[.ask_dataType, RT_Type.self]
            let prompt = arguments[.direct, RT_String.self]
            let title = arguments[.ask_title, RT_String.self]
            
            return DispatchQueue.main.sync {
                let (vc, constructor) = makeViewController(for: type?.value ?? arguments.rt.reflection.types[.string])
                let wc = AskWC(windowNibName: "AskWC")
                wc.loadWindow()
                wc.embed(viewController: vc)
                wc.prompt = prompt?.value ?? "Please enter a value."
                
                let window = wc.window!
                window.title = title?.value ?? arguments.rt.topScript.name ?? ""
                
                displayModally(window: window)
                return constructor()
            }
        }
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

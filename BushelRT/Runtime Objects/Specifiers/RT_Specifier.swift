import Bushel
import SwiftAutomation

/// An unevaluated object specifier.
public final class RT_Specifier: RT_Object, RT_AESpecifierProtocol {
    
    public enum Kind: UInt32 {
        case simple, index, name, id
        case all, first, middle, last, random
        case before, after
        case range
        case test
        case property
    }
    
    public let rt: RTInfo
    public var parent: RT_Object
    public var type: TypeInfo?
    public var property: PropertyInfo?
    public var data: [RT_Object]
    public var kind: Kind
    
    // If parent is nil, a root of kind .application is implicitly added
    public init(_ rt: RTInfo, parent: RT_Object?, type: TypeInfo?, property: PropertyInfo? = nil, data: [RT_Object], kind: Kind) {
        self.rt = rt
        self.parent = parent ?? RT_RootSpecifier(rt, kind: .application)
        self.type = type
        self.property = property
        self.data = data
        self.kind = kind
    }
    
    public func clone() -> RT_Specifier {
        var parent = self.parent
        if let specifier = parent as? RT_Specifier {
            parent = specifier.clone()
        }
        return RT_Specifier(rt, parent: parent, type: type, property: property, data: data, kind: kind)
    }
    
    func addTopParent(_ newTopParent: RT_Object) {
        rootSpecifier().parent = newTopParent
    }
    
    public func rootAncestor() -> RT_Object {
        if let parent = parent as? RT_Specifier {
            return parent.rootAncestor()
        } else {
            return parent
        }
    }

    public func rootSpecifier() -> RT_Specifier {
        if let parent = parent as? RT_Specifier {
            return parent.rootSpecifier()
        } else {
            return self
        }
    }
    
    public func rootApplication() -> (application: RT_Application?, isSelf: Bool) {
        if let bundle = rootApplicationBundle() {
            return (Builtin.retain(RT_Application(rt, bundle: bundle)), isSelf: true)
        } else {
            return (application: (parent as? RT_AESpecifierProtocol)?.rootApplication().application, isSelf: false)
        }
    }
    
    private func rootApplicationBundle() -> Bundle? {
        guard type?.isA(RT_Application.typeInfo) ?? false else {
            return nil
        }
        
        let targetApp: TargetApplication
        switch kind {
        case .index,
             .simple where data[0] is RT_Numeric:
            return nil
        case .name:
            guard data[0] is RT_String else {
                return nil
            }
            fallthrough
        case .simple where data[0] is RT_String:
            targetApp = TargetApplication.name((data[0] as! RT_String).value)
        case .id:
            targetApp = TargetApplication.bundleIdentifier((data[0] as! RT_String).value, false)
        case .simple,
             .all, .first, .middle, .last, .random,
             .before, .after,
             .range,
             .test,
             .property:
            return nil
        }
        
        guard
            let bundleID = targetApp.bundleIdentifier,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
            let bundle = Bundle(url: url)
        else {
            return nil
        }
        
        return bundle
    }
    
    public func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier? {
        if type?.isA(RT_Application.typeInfo) ?? false {
            return saRootSpecifier()
        }
        
        guard let parent = self.parent as? RT_AESpecifierProtocol else {
            return nil
        }
        guard let parentSpecifier = parent.saSpecifier(appData: appData) as? SwiftAutomation.ObjectSpecifierProtocol else {
            // TODO: handle these errors more gracefully (should make this a throwing method)
            fatalError("cannot extend a non-object specifier")
        }
        
        if case .property = kind {
            return parentSpecifier.property(property!.code!)
        }
        
        guard let code = type?.code else {
            // TODO: handle these errors more gracefully (should make this a throwing method)
            fatalError("must have code to evaluate by Apple Event")
        }
        
        let elements = parentSpecifier.elements(code)
        
        switch kind {
        case .index:
            guard data[0] is RT_Numeric else {
                return nil
            }
            fallthrough
        case .simple where data[0] is RT_Numeric:
            return elements[(data[0] as! RT_Numeric).numericValue.rounded()]
        case .name:
            guard data[0] is RT_String else {
                return nil
            }
            fallthrough
        case .simple where data[0] is RT_String:
            return elements.named((data[0] as! RT_String).value)
        case .simple:
            fatalError("wrong type for simple specifier")
        case .id:
            return elements.id(data[0])
        case .all:
            return elements.all
        case .first:
            return elements.first
        case .middle:
            return elements.middle
        case .last:
            return elements.last
        case .random:
            return elements.any
        case .before:
            return elements.before
        case .after:
            return elements.after
        case .range:
            return elements[data[0], data[1]]
        case .test:
            fatalError("unimplemented")
        case .property:
            fatalError("unreachable")
        }
    }
    
    private func saRootSpecifier() -> SwiftAutomation.RootSpecifier {
        switch kind {
        case .simple:
            guard let name = (data[0] as? RT_String)?.value else {
                fatalError("invalid type for application name")
            }
            return RootSpecifier(name: name)
        case .name:
            guard let name = (data[0] as? RT_String)?.value else {
                fatalError("invalid type for application name")
            }
            return RootSpecifier(name: name)
        case .id:
            guard let bundleID = (data[0] as? RT_String)?.value else {
                fatalError("invalid type for application ID")
            }
            return RootSpecifier(bundleIdentifier: bundleID)
        default:
            fatalError("invalid application specifier; must be by-name or by-id")
        }
    }
    
    public convenience init?(_ rt: RTInfo, saSpecifier: SwiftAutomation.ObjectSpecifier) {
        let parent: RT_Object?
        if let objectSpecifier = saSpecifier.parentQuery as? SwiftAutomation.ObjectSpecifier {
            parent = RT_Specifier(rt, saSpecifier: objectSpecifier)
        } else if let rootSpecifier = saSpecifier.parentQuery as? SwiftAutomation.RootSpecifier {
            if rootSpecifier === AEApp {
                parent = RT_Application(rt, bundle: Bundle(identifier: saSpecifier.appData.target.bundleIdentifier!)!)
            } else {
                parent = RT_RootSpecifier(rt, saSpecifier: rootSpecifier)
            }
        } else {
            fatalError("unknown Query type for SwiftAutomation.Specifier.parentQuery")
        }
        guard parent != nil else {
            return nil
        }
        
        guard let type = rt.type(for: saSpecifier.wantType.typeCodeValue) else {
            return nil
        }
        
        let kind: Kind
        // See AppData.unpackAsObjectSpecifier(_:)
        switch saSpecifier.selectorForm.enumCodeValue {
        case OSType(formPropertyID):
            kind = .property
        case 0x75737270: // _formUserPropertyID:
            fatalError()
        case OSType(formRelativePosition):
            guard
                let descriptor = saSpecifier.selectorData as? NSAppleEventDescriptor,
                descriptor.descriptorType == typeEnumerated
            else {
                return nil
            }
            switch descriptor.enumCodeValue {
            case OSType(kAEPrevious):
                kind = .before
            case OSType(kAENext):
                kind = .after
            default:
                return nil
            }
        case OSType(formAbsolutePosition):
            if
                let descriptor = saSpecifier.selectorData as? NSAppleEventDescriptor,
                descriptor.descriptorType == typeEnumerated
            {
                
                switch descriptor.enumCodeValue {
                case OSType(kAEAll):
                    kind = .all
                case OSType(kAEFirst):
                    kind = .first
                case OSType(kAEMiddle):
                    kind = .middle
                case OSType(kAELast):
                    kind = .last
                case OSType(kAEAny):
                    kind = .random
                default:
                    return nil
                }
            } else {
                kind = .index
            }
        case OSType(formRange):
            kind = .range
        case OSType(formTest):
            kind = .test
        case OSType(formName):
            kind = .name
        case OSType(formUniqueID):
            kind = .id
        default:
            return nil
        }
        
        let data: [RT_Object?]
        switch kind {
        case .simple: // not currently generated by the converter above
            fatalError()
        case .all, .first, .middle, .last, .random:
            data = []
        case .index, .name, .id, .before, .after:
            data = [RT_Object.fromEventResult(rt, saSpecifier.selectorData)]
        case .range:
            let rangeSelector = saSpecifier.selectorData as! SwiftAutomation.RangeSelector
            data = [RT_Object.fromEventResult(rt, rangeSelector.start), RT_Object.fromEventResult(rt, rangeSelector.stop)]
        case .test:
            fatalError("unimplemented")
        case .property:
            data = []
        }
        if data.contains(where: { $0 == nil }) {
            return nil
        }
        
        self.init(rt, parent: parent!, type: type, data: data.compactMap { $0 }, kind: kind)
    }
    
    public override var description: String {
        return "\(descriptionForSelf) of \(parent.description)"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.specifier.rawValue, TypeUID.specifier.aeCode, [.supertype(RT_Object.typeInfo), .name(TermName("specifier"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    private var descriptionForSelf: String {
        let termString = type.map { $0.displayName } ?? property.map { $0.displayName } ?? "(invalid specifier!)"
        
        switch kind {
        case .simple:
            return "\(termString) \(data[0])"
        case .index:
            return "\(termString) index \(data[0])"
        case .name:
            return "\(termString) named \(data[0])"
        case .id:
            return "\(termString) id \(data[0])"
        case .all:
            return "every \(termString)"
        case .first:
            return "first \(termString)"
        case .middle:
            return "middle \(termString)"
        case .last:
            return "last \(termString)"
        case .random:
            return "random \(termString)"
        case .before:
            return "\(termString) before \(data[0])"
        case .after:
            return "\(termString) after \(data[0])"
        case .range:
            return "\(termString) from \(data[0]) to \(data[1])"
        case .test:
            fatalError("unimplemented")
        case .property:
            return "\(termString)"
        }
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object]) -> RT_Object? {
        if case (let targetApplication?, _) = rootApplication() {
            return performByAppleEvent(command: command, arguments: arguments, targetBundleID: targetApplication.bundleIdentifier)
        } else {
            return nil
        }
    }
    
}

extension RT_Specifier {
    
    public override var debugDescription: String {
        super.debugDescription + "[parent: \(String(describing: parent)), type: \(String(describing: type)), data: \(data), kind: \(kind)]"
    }
    
}

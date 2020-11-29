import Bushel
import SwiftAutomation

public protocol RT_HierarchicalSpecifier: RT_SASpecifierConvertible {
    
    var parent: RT_Object { get set }
    
    func evaluateLocally(on evaluatedParent: RT_Object) throws -> RT_Object
    
    func clone() -> Self
    
}

public protocol RT_SpecifierRemoteRoot: RT_Object {
    
    func evaluate(specifier: RT_HierarchicalSpecifier) throws -> RT_Object
    func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?, for specifier: RT_HierarchicalSpecifier) throws -> RT_Object
    
}

extension RT_HierarchicalSpecifier {
    
    func setRootAncestor(_ newTopParent: RT_Object) {
        topHierarchicalAncestor().parent = newTopParent
    }
    
    public func topHierarchicalAncestor() -> RT_HierarchicalSpecifier {
        if let parent = parent as? RT_HierarchicalSpecifier {
            return parent.topHierarchicalAncestor()
        } else {
            return self
        }
    }
    
    public func rootAncestor() -> RT_Object {
        if let parent = parent as? RT_HierarchicalSpecifier {
            return parent.rootAncestor()
        } else {
            return parent
        }
    }
    
}

/// An unevaluated object specifier.
public final class RT_Specifier: RT_Object, RT_HierarchicalSpecifier, RT_SASpecifierConvertible {
    
    public enum Kind: UInt32 {
        case simple, index, name, id
        case all, first, middle, last, random
        case previous, next
        case range
        case test
        case property
    }
    
    public var parent: RT_Object
    public var type: TypeInfo?
    public var property: PropertyInfo?
    public var data: [RT_Object]
    public var kind: Kind
    
    // If parent is nil, a root of kind .application is implicitly added
    public init(parent: RT_Object?, type: TypeInfo?, property: PropertyInfo? = nil, data: [RT_Object], kind: Kind) {
        self.parent = parent ?? RT_RootSpecifier(kind: .application)
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
        return RT_Specifier(parent: parent, type: type, property: property, data: data, kind: kind)
    }
    
    public func evaluateLocally(on evaluatedParent: RT_Object) throws -> RT_Object {
        func evaluate(on parent: RT_Object) throws -> RT_Object {
            if case .property = kind {
                return try parent.property(property!)
            }
            
            let type = self.type!
            
            switch kind {
            case .index:
                guard data[0] is RT_Numeric else {
                    throw InvalidSpecifierDataType(specifierType: .byIndex, specifierData: data[0])
                }
                fallthrough
            case .simple where data[0] is RT_Numeric:
                return try parent.element(type, at: Int64((data[0] as! RT_Numeric).numericValue.rounded(.down)))
            case .name:
                guard data[0] is RT_String else {
                    throw InvalidSpecifierDataType(specifierType: .byName, specifierData: data[0])
                }
                fallthrough
            case .simple where data[0] is RT_String:
                return try parent.element(type, named: (data[0] as! RT_String).value)
            case .simple:
                throw InvalidSpecifierDataType(specifierType: .simple, specifierData: data[0])
            case .id:
                return try parent.element(type, id: data[0])
            case .all:
                return try parent.elements(type)
            case .first:
                return try parent.element(type, at: .first)
            case .middle:
                return try parent.element(type, at: .middle)
            case .last:
                return try parent.element(type, at: .last)
            case .random:
                return try parent.element(type, at: .random)
            case .previous:
                return try parent.element(type, positioned: .before)
            case .next:
                return try parent.element(type, positioned: .after)
            case .range:
                return try parent.elements(type, from: data[0], thru: data[1])
            case .test:
                // Technically reachable if someone sends us a test specifier
                // in an AppleEvent, but I'm not aware of any such cases
                // in the wild.
                fatalError("unreachable")
            case .property:
                fatalError("unreachable")
            }
        }
        
        do {
            return try evaluate(on: evaluatedParent)
        } catch let origError where origError is NoPropertyExists || origError is NoElementExists {
            do {
                return try evaluate(on: RT_Global())
            } catch {
                throw origError
            }
        }
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        switch rootAncestor() {
        case let root as RT_SpecifierRemoteRoot:
            return try root.perform(command: command, arguments: arguments, implicitDirect: implicitDirect, for: self)
        default:
            switch CommandUID(command.uid) {
            case .set:
                guard let property = property else {
                    throw NonPropertyIsNotWritable(specifier: self)
                }
                
                let setTo = ParameterInfo(ParameterUID.set_to)
                guard let newValue = arguments[setTo] else {
                    throw MissingParameter(command: command, parameter: setTo)
                }
                
                try parent.evaluate().setProperty(property, to: newValue)
                return newValue
                
            default:
                return try super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
            }
        }
    }
    
    public func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier? {
        if type?.isA(RT_Application.typeInfo) ?? false {
            return saRootSpecifier()
        }
        
        guard let parent = self.parent as? RT_SASpecifierConvertible else {
            return nil
        }
        guard let parentSpecifier = parent.saSpecifier(appData: appData) as? SwiftAutomation.ObjectSpecifierProtocol else {
            // TODO: handle these errors more gracefully (should make this a throwing method)
            fatalError("cannot extend a non-object specifier")
        }
        
        if case .property = kind {
            return parentSpecifier.property(property!.typedUID.ae4Code!)
        }
        
        guard let code = type?.typedUID.ae4Code else {
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
        case .previous:
            return parentSpecifier.previous()
        case .next:
            return parentSpecifier.next()
        case .range:
            return elements[data[0], data[1]]
        case .test:
            guard let testClause = (data[0] as? RT_TestSpecifier)?.saTestClause(appData: appData) else {
                return nil
            }
            return elements[testClause]
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
    
    public convenience init?(saSpecifier: SwiftAutomation.ObjectSpecifier) {
        let parent: RT_Object?
        if let objectSpecifier = saSpecifier.parentQuery as? SwiftAutomation.ObjectSpecifier {
            parent = RT_Specifier(saSpecifier: objectSpecifier)
        } else if let rootSpecifier = saSpecifier.parentQuery as? SwiftAutomation.RootSpecifier {
            if rootSpecifier === AEApp {
                guard
                    let bundleID = saSpecifier.appData.target.bundleIdentifier,
                    let bundle = Bundle(identifier: bundleID)
                else {
                    return nil
                }
                parent = RT_Application(bundle: bundle)
            } else {
                guard let root = try? RT_RootSpecifier.fromSARootSpecifier(rootSpecifier) else {
                    return nil
                }
                parent = root
            }
        } else {
            fatalError("unknown Query type for SwiftAutomation.Specifier.parentQuery")
        }
        guard parent != nil else {
            return nil
        }
        
        let typeCode = saSpecifier.wantType.typeCodeValue
        let type = TypeInfo(.ae4(code: typeCode))
        
        let kind: Kind
        // See AppData.unpackAsObjectSpecifier(_:)
        switch saSpecifier.selectorForm.enumCodeValue {
        case OSType(formPropertyID):
            guard
                let code = (saSpecifier.selectorData as? NSAppleEventDescriptor)?.enumCodeValue,
                code != 0
            else {
                return nil
            }
            let property = PropertyInfo(.ae4(code: code))
            self.init(parent: parent!, type: nil, property: property, data: [], kind: .property)
            return
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
                kind = .previous
            case OSType(kAENext):
                kind = .next
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
        case .all, .first, .middle, .last, .random, .previous, .next:
            data = []
        case .index, .name, .id:
            data = [RT_Object.fromSADecoded(saSpecifier.selectorData)]
        case .range:
            let rangeSelector = saSpecifier.selectorData as! SwiftAutomation.RangeSelector
            data = [RT_Object.fromSADecoded(rangeSelector.start), RT_Object.fromSADecoded(rangeSelector.stop)]
        case .test:
            fatalError("unimplemented")
        case .property:
            fatalError("unreachable")
        }
        guard let nonNilData = data as? [RT_Object] else {
            return nil
        }
        
        self.init(parent: parent!, type: type, data: nonNilData, kind: kind)
    }
    
    public override var description: String {
        let parentDescription: String? = {
            if let parent = parent as? RT_RootSpecifier {
                return parent.rootDescription
            } else {
                return parent.description
            }
        }()
        
        let selfDescription: String
        
        let termString = (type as TermInfo? ?? property as TermInfo?).map { String(describing: $0) } ?? "(invalid specifier!)"
        switch kind {
        case .simple:
            selfDescription = "\(termString) \(data[0])"
        case .index:
            selfDescription = "\(termString) index \(data[0])"
        case .name:
            selfDescription = "\(termString) named \(data[0])"
        case .id:
            selfDescription = "\(termString) id \(data[0])"
        case .all:
            selfDescription = "every \(termString)"
        case .first:
            selfDescription = "first \(termString)"
        case .middle:
            selfDescription = "middle \(termString)"
        case .last:
            selfDescription = "last \(termString)"
        case .random:
            selfDescription = "random \(termString)"
        case .previous:
            return "\(termString)\(parentDescription.map { " before \($0)" } ?? "")"
        case .next:
            return "\(termString)\(parentDescription.map { " after \($0)" } ?? "")"
        case .range:
            selfDescription = "\(termString) from \(data[0]) to \(data[1])"
        case .test:
            selfDescription = "\(termString) where \(data[0])"
        case .property:
            selfDescription = "\(termString)"
        }
        
        if let parentDescription = parentDescription {
            return "\(selfDescription) of \(parentDescription)"
        } else {
            return selfDescription
        }
    }
    
    private static let typeInfo_ = TypeInfo(.specifier)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
}

extension RT_Specifier {
    
    public override var debugDescription: String {
        super.debugDescription + "[parent: \(String(describing: parent)), type: \(String(describing: type)), data: \(data), kind: \(kind)]"
    }
    
}

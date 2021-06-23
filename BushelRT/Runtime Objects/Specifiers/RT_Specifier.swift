import Bushel
import AEthereal

public protocol RT_HierarchicalSpecifier: RT_AESpecifier {
    
    var parent: RT_Object { get set }
    
    func evaluateLocally(on evaluatedParent: RT_Object) throws -> RT_Object
    
    func clone() -> Self
    
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
public final class RT_Specifier: RT_Object, RT_HierarchicalSpecifier, RT_Module {
    
    public enum Kind {
        
        case element(Element)
        case property(Reflection.Property)
        
        public struct Element {
            
            public var type: Reflection.`Type`
            public var form: Form
            
            public enum Form {
                case simple(RT_Object)
                case index(RT_Object)
                case name(RT_Object)
                case id(RT_Object)
                case all
                case first
                case middle
                case last
                case random
                case previous
                case next
                case range(from: RT_Object, thru: RT_Object)
                case test(RT_Object)
            }
            
        }
        
    }
    
    public var parent: RT_Object
    public var kind: Kind
    
    // If parent is nil, a root of kind .application is implicitly added
    public init(_ rt: Runtime, parent: RT_Object?, kind: Kind) {
        self.parent = parent ?? RT_RootSpecifier(rt, kind: .application)
        self.kind = kind
        super.init(rt)
    }
    
    public func clone() -> RT_Specifier {
        var parent = self.parent
        if let specifier = parent as? RT_Specifier {
            parent = specifier.clone()
        }
        return RT_Specifier(rt, parent: parent, kind: kind)
    }
    
    public func evaluateLocally(on evaluatedParent: RT_Object) throws -> RT_Object {
        func evaluate(on parent: RT_Object) throws -> RT_Object? {
            switch kind {
            case let .property(property):
                return try parent.property(property)
            case let .element(element):
                switch element.form {
                case let .index(index):
                    guard index.coerce(to: RT_Integer.self) != nil else {
                        throw InvalidSpecifierDataType(specifierType: .byIndex, specifierData: index)
                    }
                    fallthrough
                case let .simple(index) where index.coerce(to: RT_Integer.self) != nil:
                    return try parent.element(type, at: index.coerce(to: RT_Integer.self)!.value)
                case let .name(name):
                    guard name.coerce(to: RT_String.self) != nil else {
                        throw InvalidSpecifierDataType(specifierType: .byName, specifierData: name)
                    }
                    fallthrough
                case let .simple(name) where name.coerce(to: RT_String.self) != nil:
                    return try parent.element(type, named: name.coerce(to: RT_String.self)!.value)
                case let .simple(data):
                    throw InvalidSpecifierDataType(specifierType: .simple, specifierData: data)
                case let .id(id):
                    return try parent.element(type, id: id)
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
                case let .range(from, thru):
                    return try parent.elements(type, from: from, thru: thru)
                case .test:
                    // TODO: Implement local test specifiers
                    throw UnsupportedIndexForm(indexForm: .filter, class: parent.type)
                }
            }
        }
        
        guard let value = try propagate(from: evaluatedParent, up: rt.builtin.moduleStack, evaluate(on:)) else {
            switch kind {
            case let .property(property):
                throw NoPropertyExists(type: type, property: property)
            case .element:
                throw NoElementExists(locationDescription: "at: \(self)")
            }
        }
        return value
    }
    
    public func handle(_ arguments: RT_Arguments) throws -> RT_Object? {
        switch rootAncestor() {
        case let root as RT_AERootSpecifier:
            return try self.handleByAppleEvent(arguments, app: root.saRootSpecifier.app)
        default:
            return nil
        }
    }
    
    public func saSpecifier(app: App) throws -> AEthereal.Specifier? {
        if
            case let .element(element) = kind,
            element.type.isA(rt.reflection.types[.app])
        {
            return try saRootSpecifier()
        }
        
        guard let parent = self.parent as? RT_AESpecifier else {
            return nil
        }
        guard let parentSpecifier = try parent.saSpecifier(app: app) as? AEthereal.ObjectSpecifierProtocol else {
            // TODO: handle gracefully
            fatalError("cannot extend a non-object specifier")
        }
        
        switch kind {
        case let .property(property):
            return parentSpecifier.property(property.id.ae4Code!)
        case let .element(element):
            guard let code = element.type.id.ae4Code else {
                // TODO: handle gracefully
                fatalError("must have code to evaluate by Apple Event")
            }
            
            let elements = parentSpecifier.elements(code)
            
            switch element.form {
            case let .index(index):
                guard index.coerce(to: RT_Integer.self) != nil else {
                    throw InvalidSpecifierDataType(specifierType: .byIndex, specifierData: index)
                }
                fallthrough
            case let .simple(index) where index.coerce(to: RT_Integer.self) != nil:
                return elements[index.coerce(to: RT_Integer.self)!.value]
            case let .name(name):
                guard name.coerce(to: RT_String.self) != nil else {
                    throw InvalidSpecifierDataType(specifierType: .byName, specifierData: name)
                }
                fallthrough
            case let .simple(name) where name.coerce(to: RT_String.self) != nil:
                return elements.named(name.coerce(to: RT_String.self)!.value)
            case let .simple(data):
                throw InvalidSpecifierDataType(specifierType: .simple, specifierData: data)
            case let .id(id):
                return elements.id(id)
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
            case let .range(from, thru):
                return elements[from, thru]
            case let .test(predicate):
                guard let testClause = try (predicate as? RT_TestSpecifier)?.saTestClause(app: app) else {
                    throw InvalidSpecifierDataType(specifierType: .byTest, specifierData: predicate)
                }
                return elements[testClause]
            }
        }
    }
    
    private func saRootSpecifier() throws -> AEthereal.RootSpecifier {
        switch kind {
        case let .element(element):
            switch element.form {
            case let .simple(name),
                 let .name(name):
                guard let appName = (name.coerce(to: RT_String.self))?.value else {
                    throw InvalidSpecifierDataType(specifierType: .byName, specifierData: name)
                }
                return RootSpecifier(name: appName)
            case let .id(id):
                guard let bundleID = (id.coerce(to: RT_String.self))?.value else {
                    throw InvalidSpecifierDataType(specifierType: .byID, specifierData: id)
                }
                return RootSpecifier(bundleIdentifier: bundleID)
            default:
                // TODO: How to handle properly?
                fatalError("invalid application specifier; must be by-name or by-id")
            }
        default:
            // TODO: How to handle properly?
            fatalError("invalid application specifier; must be by-name or by-id")
        }
    }
    
    public convenience init?(_ rt: Runtime, saSpecifier: AEthereal.ObjectSpecifier) {
        let parent: RT_Object?
        if let objectSpecifier = saSpecifier.parentQuery as? AEthereal.ObjectSpecifier {
            parent = RT_Specifier(rt, saSpecifier: objectSpecifier)
        } else if let rootSpecifier = saSpecifier.parentQuery as? AEthereal.RootSpecifier {
            if rootSpecifier === AEthereal.applicationRoot {
                guard
                    let bundleID = saSpecifier.app.target.bundleIdentifier,
                    let bundle = Bundle(identifier: bundleID)
                else {
                    return nil
                }
                parent = RT_Application(rt, bundle: bundle)
            } else {
                guard let root = try? RT_RootSpecifier.fromSARootSpecifier(rt, rootSpecifier) else {
                    return nil
                }
                parent = root
            }
        } else {
            fatalError("unknown Query type for AEthereal.Specifier.parentQuery")
        }
        guard parent != nil else {
            return nil
        }
        
        let typeCode = saSpecifier.wantType.typeCodeValue
        let type = rt.reflection.types[.ae4(code: typeCode)]
        let form: Kind.Element.Form
        // See App.decodeAsObjectSpecifier(_:)
        switch saSpecifier.selectorForm.enumCodeValue {
        case OSType(formPropertyID):
            guard
                let code = (saSpecifier.selectorData as? NSAppleEventDescriptor)?.enumCodeValue,
                code != 0
            else {
                return nil
            }
            let property = rt.reflection.properties[.ae4(code: code)]
            self.init(rt, parent: parent!, kind: .property(property))
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
                form = .previous
            case OSType(kAENext):
                form = .next
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
                    form = .all
                case OSType(kAEFirst):
                    form = .first
                case OSType(kAEMiddle):
                    form = .middle
                case OSType(kAELast):
                    form = .last
                case OSType(kAEAny):
                    form = .random
                default:
                    return nil
                }
            } else {
                guard let index = RT_Object.fromSADecoded(rt, saSpecifier.selectorData) else {
                    return nil
                }
                form = .index(index)
            }
        case OSType(formRange):
            let rangeSelector = saSpecifier.selectorData as! AEthereal.RangeSelector
            guard
                let from = RT_Object.fromSADecoded(rt, rangeSelector.start),
                let thru = RT_Object.fromSADecoded(rt, rangeSelector.stop)
            else {
                return nil
            }
            form = .range(from: from, thru: thru)
        case OSType(formTest):
            // TODO: Low prio unimplemented
            fatalError("unimplemented")
        case OSType(formName):
            guard let name = RT_Object.fromSADecoded(rt, saSpecifier.selectorData) else {
                return nil
            }
            form = .name(name)
        case OSType(formUniqueID):
            guard let id = RT_Object.fromSADecoded(rt, saSpecifier.selectorData) else {
                return nil
            }
            form = .id(id)
        default:
            return nil
        }
        self.init(rt, parent: parent!, kind: .element(Kind.Element(type: type, form: form)))
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
        
        switch kind {
        case let .property(property):
            selfDescription = "\(property)"
        case let .element(element):
            let type = element.type
            switch element.form {
            case let .simple(data):
                selfDescription = "\(type) \(data)"
            case let .index(index):
                selfDescription = "\(type) index \(index)"
            case let .name(name):
                selfDescription = "\(type) named \(name)"
            case let .id(id):
                selfDescription = "\(type) id \(id)"
            case .all:
                selfDescription = "every \(type)"
            case .first:
                selfDescription = "first \(type)"
            case .middle:
                selfDescription = "middle \(type)"
            case .last:
                selfDescription = "last \(type)"
            case .random:
                selfDescription = "random \(type)"
            case .previous:
                return "\(type)\(parentDescription.map { " before \($0)" } ?? "")"
            case .next:
                return "\(type)\(parentDescription.map { " after \($0)" } ?? "")"
            case let .range(from, thru):
                selfDescription = "\(type) from \(from) thru \(thru)"
            case let .test(predicate):
                selfDescription = "\(type) where \(predicate)"
            }
        }
        
        if let parentDescription = parentDescription {
            return "\(selfDescription) of \(parentDescription)"
        } else {
            return selfDescription
        }
    }
    
    public override var type: Reflection.`Type` {
        rt.reflection.types[.specifier]
    }
    
}

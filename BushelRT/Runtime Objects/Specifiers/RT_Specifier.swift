import Bushel
import AEthereal
import os.log

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

public protocol RT_HierarchicalSpecifier: RT_AEQuery {
    
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
                let type = element.type
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
        
        guard let value = try propagate(from: evaluatedParent, up: rt.context.moduleStack, evaluate(on:)) else {
            switch kind {
            case .property:
                throw NoPropertyExists()
            case .element:
                throw NoElementExists()
            }
        }
        return value
    }
    
    public func handle(_ arguments: RT_Arguments) throws -> RT_Object? {
        switch rootAncestor() {
        case let app as RT_Application:
            return try self.handleByAppleEvent(arguments, app: app.app)
        case let root as RT_Module:
            return try root.handle(arguments)
        default:
            return nil
        }
    }
    
    public func appleEventQuery() throws -> Query? {
        if
            case let .element(element) = kind,
            element.type.isA(rt.reflection.types[.app])
        {
            return .rootSpecifier(.application)
        }
        
        guard
            let parent = self.parent as? RT_AEQuery,
            let parentQuery = try parent.appleEventQuery()
        else {
            return nil
        }
        
        var parentSpecifier: ChainableSpecifier
        switch parentQuery {
        case let .rootSpecifier(specifier as ChainableSpecifier),
             let .objectSpecifier(specifier as ChainableSpecifier):
            parentSpecifier = specifier
        default:
            return nil
        }
        
        switch kind {
        case let .property(property):
            return .objectSpecifier(parentSpecifier.byProperty(AE4.AEType(rawValue: property.uri.ae4Code!)))
        case let .element(element):
            guard let code = element.type.id.ae4Code else {
                return nil
            }
            let wantType = AE4.AEType(rawValue: code)
            switch element.form {
            case let .index(index):
                guard index.coerce(to: RT_Integer.self) != nil else {
                    throw InvalidSpecifierDataType(specifierType: .byIndex, specifierData: index)
                }
                fallthrough
            case let .simple(index) where index.coerce(to: RT_Integer.self) != nil:
                return .objectSpecifier(parentSpecifier.byIndex(wantType, Int(index.coerce(to: RT_Integer.self)!.value)))
            case let .name(name):
                guard name.coerce(to: RT_String.self) != nil else {
                    throw InvalidSpecifierDataType(specifierType: .byName, specifierData: name)
                }
                fallthrough
            case let .simple(name) where name.coerce(to: RT_String.self) != nil:
                return .objectSpecifier(parentSpecifier.byName(wantType, name.coerce(to: RT_String.self)!.value))
            case let .simple(data):
                throw InvalidSpecifierDataType(specifierType: .simple, specifierData: data)
            case let .id(id):
                guard let id_ = id as? Encodable else {
                    throw Unencodable(object: id)
                }
                return .objectSpecifier(parentSpecifier.byID(wantType, id_))
            case .all:
                return .objectSpecifier(parentSpecifier.byAbsolute(wantType, .all))
            case .first:
                return .objectSpecifier(parentSpecifier.byAbsolute(wantType, .first))
            case .middle:
                return .objectSpecifier(parentSpecifier.byAbsolute(wantType, .middle))
            case .last:
                return .objectSpecifier(parentSpecifier.byAbsolute(wantType, .last))
            case .random:
                return .objectSpecifier(parentSpecifier.byAbsolute(wantType, .random))
            case .previous:
                guard let parentSpecifier = parentSpecifier as? ObjectSpecifier else {
                    return nil
                }
                return .objectSpecifier(parentSpecifier.byRelative(wantType, .previous))
            case .next:
                guard let parentSpecifier = parentSpecifier as? ObjectSpecifier else {
                    return nil
                }
                return .objectSpecifier(parentSpecifier.byRelative(wantType, .next))
            case let .range(from, thru):
                guard let from_ = from as? Encodable else {
                    throw Unencodable(object: from)
                }
                guard let thru_ = thru as? Encodable else {
                    throw Unencodable(object: thru)
                }
                return .objectSpecifier(parentSpecifier.byRange(wantType, from: from_, thru: thru_))
            case let .test(predicate):
                guard let testClause = try (predicate as? RT_TestSpecifier)?.appleEventTestClause() else {
                    throw InvalidSpecifierDataType(specifierType: .byTest, specifierData: predicate)
                }
                return .objectSpecifier(parentSpecifier.byTest(wantType, testClause))
            }
        }
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

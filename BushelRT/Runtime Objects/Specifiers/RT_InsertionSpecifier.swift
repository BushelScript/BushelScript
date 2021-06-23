import Bushel
import AEthereal

/// An insertion location specifier.
/// i.e., at beginning, at end, before, after
public final class RT_InsertionSpecifier: RT_Object, RT_HierarchicalSpecifier {
    
    public typealias Kind = Bushel.InsertionSpecifier.Kind
    
    public var parent: RT_Object
    public var kind: Kind
    
    public init(_ rt: Runtime, parent: RT_Object, kind: Kind) {
        self.parent = parent
        self.kind = kind
        super.init(rt)
    }
    
    public func clone() -> RT_InsertionSpecifier {
        var parent = self.parent
        if let specifier = parent as? RT_Specifier {
            parent = specifier.clone()
        }
        return RT_InsertionSpecifier(rt, parent: parent, kind: kind)
    }
    
    public func evaluateLocally(on evaluatedParent: RT_Object) throws -> RT_Object {
        throw InsertionSpecifierEvaluated(insertionSpecifier: self)
    }
    
    public func saSpecifier(app: App) throws -> AEthereal.Specifier? {
        guard let parent = self.parent as? RT_AESpecifier else {
            return nil
        }
        guard let parentSpecifier = try parent.saSpecifier(app: app) as? AEthereal.ObjectSpecifierProtocol else {
            // TODO: handle gracefully
            fatalError("cannot extend a non-object specifier")
        }
        
        switch kind {
        case .beginning:
            return parentSpecifier.beginning
        case .end:
            return parentSpecifier.end
        case .before:
            return parentSpecifier.before
        case .after:
            return parentSpecifier.after
        }
    }
    
    public convenience init?(_ rt: Runtime, saSpecifier: AEthereal.InsertionSpecifier) {
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
        
        guard
            let kind: Kind = saSpecifier.kind.map({
                switch $0 {
                case .beginning:
                    return .beginning
                case .end:
                    return .end
                case .before:
                    return .before
                case .after:
                    return .after
                }
            })
        else {
            return nil
        }
        
        self.init(rt, parent: parent!, kind: kind)
    }
    
    public override var description: String {
        let parentDescription: String? = {
            if let parent = parent as? RT_RootSpecifier {
                return parent.rootDescription
            } else {
                return parent.description
            }
        }()
        
        let (selfDescription, useOf): (String, Bool) = {
            switch kind {
            case .beginning:
                return ("at beginning", true)
            case .end:
                return ("at end", true)
            case .before:
                return ("before", false)
            case .after:
                return ("after", false)
            }
        }()
        
        if let parentDescription = parentDescription {
            return "\(selfDescription)\(useOf ? " of" : "") \(parentDescription)"
        } else {
            return selfDescription
        }
    }
    
    public override class var staticType: Types {
        .specifier
    }
    
}

extension RT_InsertionSpecifier {
    
    public override var debugDescription: String {
        super.debugDescription + "[parent: \(parent), kind: \(kind)]"
    }
    
}

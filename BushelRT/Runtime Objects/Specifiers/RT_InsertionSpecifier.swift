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
    
    public func appleEventQuery() throws -> AEthereal.Query? {
        guard let parent = self.parent as? RT_AEQuery else {
            return nil
        }
        guard case let .objectSpecifier(parentSpecifier) = try parent.appleEventQuery() else {
            return nil
        }
        return .insertionSpecifier(parentSpecifier.insertion(at: {
            switch kind {
            case .beginning:
                return .beginning
            case .end:
                return .end
            case .before:
                return .before
            case .after:
                return .after
            }
        }()))
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

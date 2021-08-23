import Bushel
import AEthereal

extension RT_Object {
    
    public func evaluateLocalSpecifierRootedAtSelf(_ specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        // Start from the top and work down
        let evaluatedParent: RT_Object = try {
            if
                let parent = specifier.parent as? RT_HierarchicalSpecifier,
                parent !== self
            {
                // Eval the parent specifier before working with this one.
                return try evaluateLocalSpecifierRootedAtSelf(parent)
            } else {
                // We are the specifier directly under the root.
                return self
            }
        }()
        return try specifier.evaluateLocally(on: evaluatedParent)
    }
    
}

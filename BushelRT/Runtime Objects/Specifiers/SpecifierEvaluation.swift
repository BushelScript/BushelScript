import Bushel
import AEthereal

extension RT_HierarchicalSpecifier {
    
    public func evaluate_() throws -> RT_Object {
        switch rootAncestor() {
        case let app as RT_Application:
            let get = rt.reflection.commands[.get]
            return try self.handleByAppleEvent(
                RT_Arguments(rt, get, [:]),
                app: app.app
            )
        default:
            // Eval as a local specifier.
            func evaluateLocalSpecifier(_ specifier: RT_HierarchicalSpecifier, from root: RT_Object) throws -> RT_Object {
                // Start from the top and work down
                let evaluatedParent: RT_Object = try {
                    if
                        let parent = specifier.parent as? RT_HierarchicalSpecifier,
                        parent !== root
                    {
                        // Eval the parent specifier before working with this one.
                        return try evaluateLocalSpecifier(parent, from: root)
                    } else {
                        // We are the specifier directly under the root.
                        return root
                    }
                }()
                return try specifier.evaluateLocally(on: evaluatedParent)
            }
            var root = rootAncestor()
            if root is RT_RootSpecifier {
                root = rt.context.target
            }
            return try evaluateLocalSpecifier(self, from: root)
        }
    }
    
}

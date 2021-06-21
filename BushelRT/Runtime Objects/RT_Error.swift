import Bushel

/// A runtime error caught by an error handler.
public class RT_Error: RT_Object {
    
    public var error: Error
    
    public init(_ rt: Runtime, _ error: Error) {
        self.error = error
        super.init(rt)
    }
    
    public override class var staticType: Types {
        .error
    }
    
    public override var description: String {
        error.localizedDescription
    }
    
}


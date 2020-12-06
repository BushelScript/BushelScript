
public class InsertionSpecifier {
    
    /// This insertion specifier's parent expression.
    ///
    /// For instance:
    ///
    ///      before window 1
    ///      ^^^^^^ ~~~~~~~~
    ///    ins spec   parent
    ///
    /// Here, `window 1` is parent to `before`.
    public var parent: Expression?
    
    public var kind: Kind
    
    public init(kind: Kind, parent: Expression? = nil) {
        self.kind = kind
        self.parent = parent
    }
    
    public enum Kind {
        
        case beginning, end
        case before, after
        
    }
    
}

import Bushel

/// A constant identified by name alone. Like a symbol in Ruby.
public class RT_SymbolicConstant: RT_Object {
    
    public var value: Bushel.TermName
    
    public init(value: Bushel.TermName) {
        self.value = value
    }
    public init(value: String) {
        self.value = Bushel.TermName(value)
    }
    
    public override var description: String {
        return String(describing: value)
    }
    
}

extension RT_SymbolicConstant {
    
    public override var debugDescription: String {
        super.description + "[value: \(value)]"
    }
    
}

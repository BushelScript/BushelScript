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
    
    public override var debugDescription: String {
        return super.description + "[value: \(value)]"
    }
    
}

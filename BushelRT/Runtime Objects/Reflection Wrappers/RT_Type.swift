import Bushel
import AEthereal

/// A runtime type reflected as a dynamic object.
public class RT_Type: RT_ValueWrapper<Reflection.`Type`> {
    
    public override class var staticType: Types {
        .type
    }
    
    public override var description: String {
        "\(value.name as Any? ?? "#type [\(value.uri)]")"
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        value == (other as? RT_Type)?.value
    }
    
    public override var hash: Int {
        value.hashValue
    }
    
}

import Bushel
import AEthereal

/// A symbolic constant.
public class RT_Constant: RT_ValueWrapper<Reflection.Constant> {
    
    public override class var staticType: Types {
        .constant
    }
    
    public override var description: String {
        "\(value.name as Any? ?? "«constant \(value.uri)»")"
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        value == (other as? RT_Constant)?.value
    }
    
    public override var hash: Int {
        value.hashValue
    }
    
}

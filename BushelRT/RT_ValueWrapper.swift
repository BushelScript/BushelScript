import Foundation

public class RT_ValueWrapper<Value: Codable & Hashable>: RT_Object, Codable {
    
    public var value: Value
    
    public init(_ rt: Runtime, value: Value) {
        self.value = value
        super.init(rt)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
    
    public required convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(decoder.userInfo[.rt] as! Runtime, value: try container.decode(Value.self))
    }
    
    public override var description: String {
        "\(value)"
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        value == (other as? RT_ValueWrapper)?.value
    }
    
    public override var hash: Int {
        value.hashValue
    }
    
}

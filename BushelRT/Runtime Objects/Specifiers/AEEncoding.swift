import Bushel
import AEthereal

func aeEncode(_ arguments: RT_Arguments, app: App) throws -> [OSType : NSAppleEventDescriptor] {
    if let unencodableKey = arguments.contents.keys.first(where: { $0.id.ae4Code == nil }) {
        throw Unencodable(object: unencodableKey)
    }
    let keys = arguments.contents.keys.map { $0.id.ae4Code! }
    
    let values: [NSAppleEventDescriptor] = try arguments.contents.values.map { (argument: RT_Object) -> NSAppleEventDescriptor in
        guard let encodable = argument as? AEEncodable else {
            throw Unencodable(object: argument)
        }
        return try encodable.encodeAEDescriptor(app)
    }

    return [OSType : NSAppleEventDescriptor](uniqueKeysWithValues: zip(keys, values))
}

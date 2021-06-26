import Bushel
import AEthereal

func makeAEParameters(_ arguments: RT_Arguments, app: App) throws -> [AE4 : Encodable] {
    if let unencodableKey = arguments.contents.keys.first(where: { $0.id.ae4Code == nil }) {
        throw Unencodable(object: unencodableKey)
    }
    let keys = arguments.contents.keys.map { $0.id.ae4Code! }
    
    let values: [Encodable] = try arguments.contents.values.map { (argument: RT_Object) -> Encodable in
        guard let encodable = argument as? Encodable else {
            throw Unencodable(object: argument)
        }
        return encodable
    }

    return [AE4 : Encodable](uniqueKeysWithValues: zip(keys, values))
}

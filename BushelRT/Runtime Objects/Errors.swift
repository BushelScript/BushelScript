import Bushel

public struct Unpackable: LocalizedError {
    public var errorDescription: String? {
        "An object couldn’t be sent in an AppleEvent because it can’t be represented as an AppleEvent descriptor"
    }
}

public struct NoPropertyExists: LocalizedError {
    public let type: TypeInfo
    public let property: PropertyInfo
    
    public var errorDescription: String? {
        "Objects of type \(type) do not have a property named \(property)"
    }
    
}

public struct UnsupportedIndexForm: LocalizedError {
    public enum IndexForm: String {
        case index
        case name
        case id
        case relative
        case absolute
        case all
        case range
        case filter
    }
    
    public let indexForm: IndexForm
    public let `class`: TypeInfo
    
    public var errorDescription: String? {
        "The indexing form ‘\(indexForm)’ is unsupported by items of type \(`class`)"
    }
}

public struct NoElementExists: LocalizedError {
    public let locationDescription: String
    
    public var errorDescription: String? {
        "No element exists \(locationDescription)"
    }
}

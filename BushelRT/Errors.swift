import Bushel

public struct Unencodable: LocalizedError {
    
    public let object: Any
    
    public var errorDescription: String? {
        "\(object) couldn’t be sent in an AppleEvent because it can’t be represented as an AppleEvent descriptor"
    }
    
}

public struct Undecodable : LocalizedError {
    
    public let error: Error
    
    public var errorDescription: String? {
        "An object couldn’t be decoded from an AppleEvent descriptor: \(error)"
    }
    
}

public struct RemoteCommandError : LocalizedError {
    
    public let remoteObject: Any
    public let command: CommandInfo
    public let error: Error
    
    public var errorDescription: String? {
        "\(remoteObject) got an error while performing \(command): \(error)"
    }
    
}

public struct RemoteCommandsDisallowed : LocalizedError {
    
    public let remoteObject: Any
    
    public var errorDescription: String? {
        // Generalize this once multiple possibly inaccessible remote target types exist
        "Not allowed to send AppleEvents to \(remoteObject)"
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

public struct InvalidSpecifierDataType: LocalizedError {
    
    public enum SpecifierType: String {
        
        case byIndex = "by-index"
        case byName = "by-name"
        case simple = "simple"
        case byTest = "by-test"
        
    }
    
    public let specifierType: SpecifierType
    public let specifierData: Any
    
    public var errorDescription: String? {
        "\(specifierData) is of incorrect type for a \(specifierType) specifier"
    }
    
}

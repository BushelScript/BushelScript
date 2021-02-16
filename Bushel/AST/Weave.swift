import Foundation

public struct Bihash {
    
    public let delimiter: String
    
    public init(delimiter: String) {
        self.delimiter = delimiter
    }
    
}

public struct Hashbang {
    
    public let invocation: String
    public let location: SourceLocation
    
    public var isEmpty: Bool {
        invocation.isEmpty
    }
    
    public init?(_ invocation: String, at location: SourceLocation) {
        var invocation = invocation
        if invocation.starts(with: "#!") {
            invocation = String(invocation[invocation.index(invocation.startIndex, offsetBy: 2)...])
        }
        
        self.invocation = invocation
        self.location = location
    }
    
}

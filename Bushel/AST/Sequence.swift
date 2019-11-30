import Foundation

public struct Sequence {
    
    public let expressions: [Expression]
    public let location: SourceLocation
    
    public static func empty(at index: String.Index) -> Sequence {
        return Sequence(expressions: [], location: SourceLocation(at: index, source: ""))
    }
    
    public init(expressions: [Expression], location: SourceLocation) {
        self.expressions = expressions
        self.location = location
    }
    
}

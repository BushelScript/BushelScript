import Foundation

public class Program {
    
    public let ast: Expression
    public let elements: Set<SourceElement>
    public let source: String
    public let terms: TermPool
    
    public init(_ ast: Expression, _ elements: Set<SourceElement>, source: String, terms: TermPool) {
        self.ast = ast
        self.elements = elements
        self.source = source
        self.terms = terms
    }
    
}

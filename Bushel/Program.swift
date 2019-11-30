import Foundation

public class Program {
    
    public let ast: Expression
    public let source: String
    public let terms: TermPool
    
    public init(_ ast: Expression, source: String, terms: TermPool) {
        self.ast = ast
        self.source = source
        self.terms = terms
    }
    
}

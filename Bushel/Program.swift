import Foundation

public class Program {
    
    public let ast: Expression
    public let elements: Set<SourceElement>
    public let source: String
    public let rootTerm: Term
    public let typeTree: TypeTree
    
    public init(_ ast: Expression, _ elements: Set<SourceElement>, source: String, rootTerm: Term, typeTree: TypeTree) {
        self.ast = ast
        self.elements = elements
        self.source = source
        self.rootTerm = rootTerm
        self.typeTree = typeTree
    }
    
}

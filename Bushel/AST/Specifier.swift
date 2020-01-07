import Foundation

public class Specifier {
    
    /// This specifier's parent expression.
    ///
    /// For instance:
    ///
    ///      window 1 of application "Safari"
    ///      ^^^^^^^^    ~~~~~~~~~~~~~~~~~~~~
    ///     specifier          parent
    ///
    /// Here, `application "Safari"` is parent to `window 1`.
    public var parent: Expression?
    
    /// The class of data specified.
    /// Eventually encoded as `keyAEDesiredClass`.
    public var idTerm: Located<Term>
    
    public var kind: Kind
    
    public init(class: Located<Term>, kind: Kind, parent: Expression? = nil) {
        self.idTerm = `class`
        self.kind = kind
        self.parent = parent
    }
    
    public func allDataExpressions() -> [Expression] {
        return kind.allDataExpressions()
    }
    
    public enum Kind {
        
        /// A specifier with one data expression. The keyform to be used is
        /// inferred from the type of the data expression at time of evaluation.
        case simple(Expression)
        case index(Expression)
        case name(Expression)
        case id(Expression)
        case all
        case first
        case middle
        case last
        case random
        case before(Expression)
        case after(Expression)
        case range(from: Expression, to: Expression)
        case test(predicate: Expression)
        case property
        
        public func allDataExpressions() -> [Expression] {
            switch self {
            case .simple(let dataExpression),
                 .index(let dataExpression),
                 .name(let dataExpression),
                 .id(let dataExpression),
                 .before(let dataExpression),
                 .after(let dataExpression):
                return [dataExpression]
            case .all, .first, .middle, .last, .random:
                return []
            case .range(let from, let to):
                return [from, to]
            case .test(let predicate):
                return [predicate]
            case .property:
                return []
            }
        }
        
    }
    
}

extension Specifier {
    
    public func topParent() -> Expression? {
        guard
            let parent = parent,
            case .specifier(let parentSpecifier) = parent.kind,
            parentSpecifier.parent != nil
        else {
            return nil
        }
        return parentSpecifier.topParent()
    }
    
    public func allDataExpressionsFromSelfAndAncestors() -> [Expression] {
        var expressions: [Expression] = allDataExpressions()
        
        guard parent != nil else {
            return expressions
        }
        
        var specifier = self
        while let parent = specifier.parent {
            guard case .specifier(let parentSpecifier) = parent.kind else {
                expressions.append(parent)
                break
            }
            specifier = parentSpecifier
            expressions.append(contentsOf: parentSpecifier.allDataExpressions())
        }
        
        return expressions
    }
    
}

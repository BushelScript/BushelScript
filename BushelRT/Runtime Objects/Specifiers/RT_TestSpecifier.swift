import Bushel
import SwiftAutomation

/// A test clause specifier.
public final class RT_TestSpecifier: RT_Object {
    
    public var operation: BinaryOperation
    public var lhs: RT_Object
    public var rhs: RT_Object
    
    public init(operation: BinaryOperation, lhs: RT_Object, rhs: RT_Object) {
        self.operation = operation
        
        let specimenRoot = RT_RootSpecifier(kind: .specimen)
        if let lhs = lhs as? RT_HierarchicalSpecifier {
            lhs.setRootAncestor(specimenRoot)
        }
        self.lhs = lhs
        if let rhs = rhs as? RT_HierarchicalSpecifier {
            rhs.setRootAncestor(specimenRoot)
        }
        self.rhs = rhs
    }
    
    public func saTestClause(appData: AppData) -> SwiftAutomation.TestClause? {
        func makeLogicalTestClause() -> SwiftAutomation.TestClause? {
            guard
                let lhsClause = (lhs as? RT_TestSpecifier)?.saTestClause(appData: appData),
                let rhsClause = (rhs as? RT_TestSpecifier)?.saTestClause(appData: appData)
            else {
                return nil
            }
            switch operation {
            case .or:
                return lhsClause || rhsClause
            case .xor:
                return
                    (lhsClause && !rhsClause) ||
                    (!lhsClause && rhsClause)
            case .and:
                return lhsClause && rhsClause
            default:
                fatalError("unreachable")
            }
        }
        func makeComparisonTestClause() -> SwiftAutomation.TestClause? {
            let objectSpecifier: SwiftAutomation.ObjectSpecifier
            let other: RT_Object
            let reverse: Bool
            if let lhsObjectSpecifier = (lhs as? RT_SASpecifierConvertible)?.saSpecifier(appData: appData) as? SwiftAutomation.ObjectSpecifier {
                objectSpecifier = lhsObjectSpecifier
                other = rhs
                reverse = false
            } else {
                guard let rhsObjectSpecifier = (rhs as? RT_SASpecifierConvertible)?.saSpecifier(appData: appData) as? SwiftAutomation.ObjectSpecifier else {
                    return nil
                }
                objectSpecifier = rhsObjectSpecifier
                other = lhs
                // SwiftAutomation always has its lhs be the object specifier,
                // so we must reverse the operands to preserve the intended
                // semantics.
                reverse = true
            }
            
            switch operation {
            case .equal:
                return objectSpecifier == other
            case .notEqual:
                return objectSpecifier != other
            case .less:
                return reverse ? (objectSpecifier >= other) : (objectSpecifier < other)
            case .lessEqual:
                return reverse ? (objectSpecifier > other) : (objectSpecifier <= other)
            case .greater:
                return reverse ? (objectSpecifier <= other) : (objectSpecifier > other)
            case .greaterEqual:
                return reverse ? (objectSpecifier < other) : (objectSpecifier >= other)
            case .startsWith:
                return reverse ? nil : objectSpecifier.beginsWith(other)
            case .endsWith:
                return reverse ? nil : objectSpecifier.endsWith(other)
            case .contains:
                return reverse ? objectSpecifier.isIn(other) : objectSpecifier.contains(other)
            case .notContains:
                return !(reverse ? objectSpecifier.isIn(other) : objectSpecifier.contains(other))
            case .containedBy:
                return reverse ? objectSpecifier.contains(other) : objectSpecifier.isIn(other)
            case .notContainedBy:
                return !(reverse ? objectSpecifier.contains(other) : objectSpecifier.isIn(other))
            default:
                fatalError("unreachable")
            }
        }
        
        return testKind.flatMap { kind in
            switch kind {
            case .logical:
                return makeLogicalTestClause()
            case .comparison:
                return makeComparisonTestClause()
            }
        }
    }
    
    private enum TestKind {
        
        case logical
        case comparison
        
    }
    
    private var testKind: TestKind? {
        switch operation {
        case .or, .xor, .and:
            return .logical
        case .equal, .notEqual, .less, .lessEqual, .greater, .greaterEqual, .startsWith, .endsWith, .contains, .notContains, .containedBy, .notContainedBy:
            return .comparison
        default:
            // Unsupported by AEOM test clauses
            return nil
        }
    }
    
    public override var description: String {
        switch operation {
        case .or:
            return "\(lhs) or \(rhs)"
        case .xor:
            return "\(lhs) xor \(rhs)"
        case .and:
            return "\(lhs) and \(rhs)"
        case .equal:
            return "\(lhs) = \(rhs)"
        case .notEqual:
            return "\(lhs) ≠ \(rhs)"
        case .less:
            return "\(lhs) < \(rhs)"
        case .lessEqual:
            return "\(lhs) ≤ \(rhs)"
        case .greater:
            return "\(lhs) > \(rhs)"
        case .greaterEqual:
            return "\(lhs) ≥ \(rhs)"
        case .startsWith:
            return "\(lhs) starts with \(rhs)"
        case .endsWith:
            return "\(lhs) ends with \(rhs)"
        case .contains:
            return "\(lhs) contains \(rhs)"
        case .notContains:
            return "\(lhs) does not contain\(rhs)"
        case .containedBy:
            return "\(lhs) is in \(rhs)"
        case .notContainedBy:
            return "\(lhs) is not in \(rhs)"
        default:
            return "(test specifier with unsupported operator \(operation))"
        }
    }
    
    // We technically don't know the type statically, since it's either
    // .comparisonTestSpecifier or .logicalTestSpecifier
    private static let typeInfo_ = TypeInfo(.item, [.dynamic])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var dynamicTypeInfo: TypeInfo {
        switch testKind {
        case .logical:
            return TypeInfo(.logicalTestSpecifier)
        case .comparison:
            return TypeInfo(.comparisonTestSpecifier)
        case nil:
            return TypeInfo(.item)
        }
    }
    
}

extension RT_TestSpecifier {
    
    public override var debugDescription: String {
        super.debugDescription + "[operation: \(operation), lhs: \(lhs), rhs: \(rhs)]"
    }
    
}

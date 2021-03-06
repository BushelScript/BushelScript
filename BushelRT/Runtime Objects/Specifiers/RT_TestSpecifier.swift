import Bushel
import AEthereal

/// A test clause specifier.
public final class RT_TestSpecifier: RT_Object {
    
    public var operation: BinaryOperation
    public var lhs: RT_Object
    public var rhs: RT_Object
    
    public init(_ rt: Runtime, operation: BinaryOperation, lhs: RT_Object, rhs: RT_Object) {
        self.operation = operation
        
        let specimenRoot = RT_RootSpecifier(rt, kind: .specimen)
        if let lhs = lhs as? RT_HierarchicalSpecifier {
            lhs.setRootAncestor(specimenRoot)
        }
        self.lhs = lhs
        if let rhs = rhs as? RT_HierarchicalSpecifier {
            rhs.setRootAncestor(specimenRoot)
        }
        self.rhs = rhs
        
        super.init(rt)
    }
    
    public func appleEventTestClause() throws -> AEthereal.ObjectSpecifier.TestClause? {
        func makeLogicalTestClause() throws -> AEthereal.ObjectSpecifier.TestClause? {
            guard
                let lhsClause = try (lhs as? RT_TestSpecifier)?.appleEventTestClause(),
                let rhsClause = try (rhs as? RT_TestSpecifier)?.appleEventTestClause()
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
        func makeComparisonTestClause() throws -> AEthereal.ObjectSpecifier.TestClause? {
            let objectSpecifier: AEthereal.ObjectSpecifier
            let otherObject: RT_Object
            let reverse: Bool
            if case let .objectSpecifier(lhsObjectSpecifier) = try (lhs as? RT_AEQuery)?.appleEventQuery() {
                objectSpecifier = lhsObjectSpecifier
                otherObject = rhs
                reverse = false
            } else {
                guard case let .objectSpecifier(rhsObjectSpecifier) = try (rhs as? RT_AEQuery)?.appleEventQuery() else {
                    return nil
                }
                objectSpecifier = rhsObjectSpecifier
                otherObject = lhs
                // AEthereal always has its lhs be the object specifier,
                // so we must reverse the operands to preserve the intended
                // semantics.
                reverse = true
            }
            guard let other = otherObject as? Codable else {
                return nil
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
        
        return try testKind.flatMap { kind in
            switch kind {
            case .logical:
                return try makeLogicalTestClause()
            case .comparison:
                return try makeComparisonTestClause()
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
    
    public override var type: Reflection.`Type` {
        switch testKind {
        case .logical:
            return rt.reflection.types[.logicalTestSpecifier]
        case .comparison:
            return rt.reflection.types[.comparisonTestSpecifier]
        case nil:
            return rt.reflection.types[.item]
        }
    }
    
}

extension RT_TestSpecifier {
    
    public override var debugDescription: String {
        super.debugDescription + "[operation: \(operation), lhs: \(lhs), rhs: \(rhs)]"
    }
    
}

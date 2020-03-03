import Foundation

// Langauge-agnostic pretty printing.

public protocol PrettyPrintable {
    
    var location: SourceLocation { get }
    var spacing: Spacing { get }
    var prettified: String { get }
    
}

public extension PrettyPrintable {
    
    var spacing: Spacing {
        .none
    }
    
}

public enum Spacing {
    
    // When applied to "b":
    case leftRight  // a b c
    case left       // a bc
    case right      // ab c
    case none       // abc
    
    var hasLeft: Bool {
        switch self {
        case .leftRight, .left:
            return true
        case .right, .none:
            return false
        }
    }
    
    var hasRight: Bool {
        switch self {
        case .leftRight, .right:
            return true
        case .left, .none:
            return false
        }
    }
    
}

public func prettyPrint(_ elements: Set<SourceElement>) -> String {
    let elements = elements.sorted()
    
    var result: String = ""
    for index in elements.indices {
        let element = elements[index]
        let lastElement = elements.indices.contains(index - 1) ? elements[index - 1] : nil
        
        let pretty = element.prettified
        
        if
            !(result.last?.isWhitespace ?? true),
            !(pretty.first?.isWhitespace ?? true),
            lastElement?.spacing.hasRight ?? false,
            element.spacing.hasLeft
        {
            result += " "
        }
        
        result += pretty
    }
    
    return result
}

public struct SourceElement: PrettyPrintable {
    
    public var value: PrettyPrintable
    
    public init(_ value: PrettyPrintable) {
        self.value = value
    }
    
    public var location: SourceLocation {
        value.location
    }
    
    public var spacing: Spacing {
        value.spacing
    }
    
    public var prettified: String {
        value.prettified
    }
    
}

extension SourceElement: Hashable {
    
    public static func == (lhs: SourceElement, rhs: SourceElement) -> Bool {
        lhs.location == rhs.location
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(location)
    }
    
}

extension SourceElement: Comparable {
    
    public static func < (lhs: SourceElement, rhs: SourceElement) -> Bool {
        let lhs = lhs.location.range
        let rhs = rhs.location.range
        if lhs.lowerBound < rhs.lowerBound {
            return true
        } else {
            return lhs.lowerBound == rhs.lowerBound && lhs.upperBound < rhs.upperBound
        }
    }
    
}

private let oneLevelIndentation = "\t"

public struct Indentation: PrettyPrintable {
    
    public var level: Int
    public var location: SourceLocation
    
    public init(level: Int, location: SourceLocation) {
        self.level = level
        self.location = location
    }
    
    public var prettified: String {
        String(repeating: oneLevelIndentation, count: level)
    }
    
}

extension Expression {
    
//    public func collectElements(_ elements: inout Set<SourceElement>, level: Int) {
//        elements.formUnion(self.elements)
//
//        if case .sequence(let expressions) = kind {
//            let level = level + 1
//
//            for (index, expression) in expressions.enumerated() {
//                var exprLevel = level
//                if
//                    case .end = expression.kind,
//                    level > 0
//                {
//                    exprLevel -= 1
//                }
//
//                let indentation = SourceElement(Indentation(level: exprLevel, withNewline: index != 0, location: SourceLocation(at: expression.location)))
//                elements.remove(indentation) // Possible other occupying element
//                elements.insert(indentation)
//
//                expression.collectElements(&elements, level: level)
//            }
//        } else {
//            for expression in subexpressions() {
//                expression.collectElements(&elements, level: level)
//            }
//        }
//    }
    
}

extension LocatedTerm {
    
    public var prettified: String {
        String(describing: self)
    }
    
}

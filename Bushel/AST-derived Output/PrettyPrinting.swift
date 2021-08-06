import Foundation

// Langauge-agnostic pretty printing.

public protocol PrettyPrintable {
    
    var location: SourceLocation { get }
    var spacing: Spacing { get }
    var styling: Styling { get }
    var prettified: String { get }
    
}

public extension PrettyPrintable {
    
    var spacing: Spacing {
        .none
    }
    var styling: Styling {
        .comment
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

public func highlight(source: Substring, _ elements: Set<SourceElement>, with styles: Styles) -> NSAttributedString {
    let elements = elements.sorted()
    
    guard let commentAttributes = styles[.comment] else {
        return NSAttributedString(string: String(source))
    }
    
    let result = NSMutableAttributedString(string: String(source), attributes: commentAttributes)
    for element in elements {
        let attributes = styles[element.styling] ?? commentAttributes
        let range = NSRange(element.location.range, in: source)
        result.addAttributes(attributes, range: range)
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
    
    public var styling: Styling {
        value.styling
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

public struct Terminal: PrettyPrintable {
    
    public var value: String
    public var location: SourceLocation
    public var spacing: Spacing
    public var styling: Styling
    
    public init(_ value: String, at location: SourceLocation, spacing: Spacing = .leftRight, styling: Styling = .keyword) {
        self.value = value
        self.location = location
        self.spacing = spacing
        self.styling = styling
    }
    
    public var prettified: String {
        value
    }
    
}

public enum Styling {
    case comment
    case keyword
    case `operator`
    case dictionary
    case type
    case property
    case constant
    case command
    case parameter
    case variable
    case resource
    case number
    case string
    case weave
}

public typealias Styles = [Styling : [NSAttributedString.Key : Any]]

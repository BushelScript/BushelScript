import Foundation

// Langauge-agnostic pretty printing.

public protocol PrettyPrintable {
    
    func prettified(source: String, level: Int) -> String
    
}

public enum Printable {
    
    case expression(Expression)
    case sequence(Sequence)
    case indentation(level: Int)
    case newline
    
}

extension Printable {
    
    public func prettified(source: String) -> String {
        return prettified(source: source, level: -1)
    }
    
}

private let oneLevelIndentation = "    "

extension Printable {
    
    public func prettified(source: String, level: Int) -> String {
        switch self {
        case .expression(let prettyPrintable as PrettyPrintable),
             .sequence(let prettyPrintable as PrettyPrintable):
            return prettyPrintable.prettified(source: source, level: level)
        case .indentation(let level):
            return String(repeating: oneLevelIndentation, count: level)
        case .newline:
            return "\n"
        }
    }
    
}

extension Expression: PrettyPrintable {
    
    public func prettified(source: String, level: Int) -> String {
        return elements.map { $0.prettified(source: source, level: level) }.joined(separator: " ")
    }
    
}

extension Sequence: PrettyPrintable {
    
    public func prettified(source: String, level: Int) -> String {
        let level = level + 1
        
        var printables: [Printable] = []
        
        if level != 0 {
            printables.append(.newline)
        }
        
        printables += [Printable](expressions.map { (expression) -> [Printable] in
            let indentation: Int
            switch expression.kind {
            case .empty:
                indentation = 0
            case .end:
                indentation = (level > 0) ? level - 1 : level
            default:
                indentation = level
            }
            
            return [.indentation(level: indentation), .expression(expression)]
        }.joined(separator: [.newline]))
        
        return printables.reduce("", { (acc, printable) -> String in
            acc + printable.prettified(source: source)
        })
    }
    
}

extension NamedTerm {
    
    public func prettified(source: String, level: Int) -> String {
        displayName
    }
    
}

extension Resource {
    
    public var prettified: String {
        switch self {
        case .applicationByName(let term as NamedTerm),
             .applicationByID(let term as NamedTerm):
            return term.displayName
        }
    }
    
}

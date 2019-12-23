// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import Foundation

private enum OptionAwaitingArgument: String {
    case e, l
}

private var optionAwaitingArgument: OptionAwaitingArgument? = nil

func parse(longOption option: Substring) {
    switch option {
    case "version":
        parse(shortOptions: "v")
    case "help":
        parse(shortOptions: "h")
    default:
        unknownOption(String(option))
    }
}

func parse(shortOptions options: Substring) {
    for option in options {
        if let awaiting = OptionAwaitingArgument(rawValue: String(option)) {
            optionAwaitingArgument = awaiting
        } else {
            switch option {
            case "v":
                exit(printVersion())
            case "h":
                printUsage()
                exit(0)
            default:
                unknownOption(String(option))
            }
        }
    }
}

func unknownOption(_ option: String) -> Never {
    print("Unknown option ‘\(option)’")
    printUsage()
    exit(0)
}

func parse(argument: Substring) {
    if let option = optionAwaitingArgument {
        optionAwaitingArgument = nil
        switch option {
        case .e:
            invocation.scriptLines.append(argument)
        case .l:
            invocation.language = String(argument)
        }
    } else {
        invocation.files.append(argument)
    }
}

public extension Substring {
    
    mutating func removeFirst(while predicate: (Character) throws -> Bool) rethrows {
        self = try drop(while: predicate)
    }
    
    mutating func removeLast(while predicate: (Character) throws -> Bool) rethrows {
        while
            let last = self.last,
            try predicate(last)
        {
            removeLast()
        }
    }
    
    func dropLast(while predicate: (Character) throws -> Bool) rethrows -> Substring {
        var copy = self
        try copy.removeLast(while: predicate)
        return copy
    }
    
    mutating func removeLeadingWhitespace(removingNewlines: Bool = false) {
        removeFirst(while: { $0.isWhitespace && (removingNewlines || !$0.isNewline) })
    }
    
    mutating func removeTrailingWhitespace(removingNewlines: Bool = false) {
        removeLast(while: { $0.isWhitespace && (removingNewlines || !$0.isNewline) })
    }
    
    func removingPrefix(_ prefix: String) -> Substring? {
        var copy = Substring(self)
        return copy.removePrefix(prefix) ? copy : nil
    }
    
    mutating func removePrefix(_ prefix: String) -> Bool {
        removeLeadingWhitespace()
        if hasPrefix(prefix) {
            removeFirst(prefix.count)
            return true
        } else {
            return false
        }
    }
    
    func removingSuffix(_ suffix: String) -> Substring? {
        var copy = self
        return copy.removeSuffix(suffix) ? copy : nil
    }
    
    mutating func removeSuffix(_ suffix: String) -> Bool {
        removeTrailingWhitespace()
        if hasSuffix(suffix) {
            removeLast(suffix.count)
            return true
        } else {
            return false
        }
    }
    
}

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
            case "i":
                invocation.interactive = true
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

// BushelScript command-line interface.
//
// © 2019-2021 Ian A. Gregory.
// Released under the terms of the MIT License, copied below.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import ArgumentParser
import LineNoise
import AppKit
import Bushel
import BushelRT

let stdin = "/dev/stdin"
let defaultLanguageID = "bushelscript_en"

@main
struct BushelScript: ParsableCommand {
    
    static var configuration = CommandConfiguration(
        commandName: "bushelscript",
        abstract: "Run a BushelScript script.",
        discussion: "Scripts can be given as files or stitched together from -e <line> arguments. The result is printed automatically, which can be disabled with -R."
    )
    
    @OptionGroup
    var options: Options
    
    @OptionGroup
    var mode: Mode
    
    @Argument(help: "Arguments to pass to the script.")
    var arguments: [String] = []
    
    private var scriptName: String {
        if mode.interactive {
            return "<repl>"
        }
        if !mode.lines.isEmpty {
            return "<command-line>"
        }
        if let file = mode.scriptFile {
            return file == "-" ? "<stdin>" : URL(fileURLWithPath: file).lastPathComponent
        }
        fatalError("unreachable")
    }
    private func runtime() -> Runtime {
        return Runtime(arguments: arguments, scriptName: scriptName)
    }
    
    struct Options: ParsableArguments {
        
        @Option(
            name: [.short, .long],
            help: ArgumentHelp(
                "ID of the language module that should interpret the script."
            )
        )
        var language: String = defaultLanguageID
        
        @Flag(
            name: [.customShort("R"), .long],
            help: ArgumentHelp(
                "Don't automatically print the final result."
            )
        )
        var noResult = false
        
    }
    
    struct Mode: ParsableArguments {
        
        @Flag(name: [.short, .long], help: "Run an interactive REPL.")
        var interactive = false
        
        @Option(
            name: [.customShort("e")],
            parsing: ArrayParsingStrategy.unconditionalSingleValue,
            help: ArgumentHelp(
                "A line of code to be stitched into a script and then run.",
                discussion: "Multiple -e may be specified, one per line of code.",
                valueName: "line"
            )
        )
        var lines: [String] = []
        
        @Argument(help: "A script file to run; use '-' for stdin.")
        var scriptFile: String?
        
        @Flag(name: [.short, .long], help: "Show version information.")
        var version = false
        
    }
    
    mutating func validate() throws {
        if mode.version {
            return
        }
        if let scriptFile = mode.scriptFile, mode.interactive || !mode.lines.isEmpty {
            // Hack: Treat as script argument. (I don't know how to make
            // ArgumentParser treat these as mutually exclusive.)
            arguments.insert(scriptFile, at: 0)
            mode.scriptFile = nil
        }
        let modeCount = [mode.interactive, !mode.lines.isEmpty, mode.scriptFile != nil].filter({ $0 }).count
        guard modeCount != 0 else {
            throw CleanExit.helpRequest()
        }
        guard modeCount == 1 else {
            throw ValidationError("-i, -e and <script-file> are mutually exclusive.")
        }
    }
    
    func run() throws {
        Bundle.main.executablePath!.withCString {
            guard let ourPathCString = realpath($0, nil) else {
                FileHandle.standardError.write(Data("Warning: Failed to find path to own executable. Language modules installed in the app bundle will not be available.".utf8))
                return
            }
            defer {
                free(ourPathCString)
            }
            
            let us = URL(fileURLWithPath: String(cString: ourPathCString))
            LanguageModule.appBundle = Bundle(url:
                us
                    .deletingLastPathComponent() // bushelscript
                    .deletingLastPathComponent() // Resources
                    .deletingLastPathComponent() // Contents
            )
            if LanguageModule.appBundle == nil {
                FileHandle.standardError.write(Data("Warning: Failed to find app bundle from path to own executable. Language modules installed in the app bundle will not be available.".utf8))
            }
        }
        
        if mode.version {
            printVersion()
            return
        } else if mode.interactive {
            try runREPL()
        } else if !mode.lines.isEmpty {
            let source = mode.lines.map { String($0) }.joined(separator: "\n")
            let parser = try LanguageModule(identifier: options.language).parser()
            try run(parser: parser, rt: runtime(), source: source, fileName: scriptName)
        } else if let file = mode.scriptFile {
            if file == "-" {
                try runFile(stdin, fileName: scriptName)
            } else {
                try runFile(file, fileName: file, url: URL(fileURLWithPath: file))
            }
        }
    }
    
    private func runFile(_ path: String, fileName: String, url: URL? = nil) throws {
        var source = try String.read(fromPath: path)
        let language = LanguageModule.takeLanguageFromHashbang(&source) ?? options.language
        return try run(parser: try LanguageModule(identifier: language).parser(), rt: runtime(), source: source, fileName: fileName, url: url)
    }
    
    private func runREPL() throws {
        printVersion()
        print("Type :exit or CTRL-D to exit")
        
        var lineNumber = 0
        let lineNoise = LineNoise()
        func prompt() throws -> String? {
            lineNumber += 1
            let input = try lineNoise.getLine(prompt: "\(lineNumber)> ")
            print() // LineNoise eats the line break.
            lineNoise.addHistory(input)
            return input
        }
        
        let parser = try LanguageModule(identifier: options.language).parser()
        let rt = runtime()
        while let line = try prompt() {
            let trimmed = Substring(line).trimmingWhitespace()
            guard !(trimmed == ":exit") else {
                return
            }
            guard !trimmed.isEmpty else {
                parser.entireSource += "\n"
                continue
            }
            let oldEntireSource = parser.entireSource
            let lineBreak = (lineNumber == 1) ? "" : "\n"
            do {
                let program = try parser.continueParsing(from: lineBreak + line)
                let result = try rt.run(program)
                print(result)
            } catch {
                printError(error, in: parser.entireSource, fileName: scriptName)
                parser.entireSource = oldEntireSource + lineBreak
                continue
            }
        }
        print()
    }
    
    private func run(parser: SourceParser, rt: Runtime, source: String, fileName: String, url: URL? = nil) throws {
        do {
            let program = try parser.parse(source: source, at: url)
            let result = try rt.run(program)
            if !options.noResult {
                print(result)
            }
        } catch {
            printError(error, in: parser.entireSource, fileName: fileName)
            throw ExitCode.failure
        }
    }
    
}

private func printError(_ error: Error, in source: String, fileName: String) {
    if let error = error as? (Located & Error) {
        printErrorMessage(error.localizedDescription, in: source, at: error.location, fileName: fileName)
        printLocationSnippet(for: error.location, in: source, indentation: 4, withMarker: true)
    } else {
        printErrorMessage(error.localizedDescription, fileName: fileName)
    }
    if let error = error as? ParseErrorProtocol {
        printSourceFixes(error.fixes, in: source)
    }
}

private func printErrorMessage(_ message: String, fileName: String) {
    print("error in \(fileName): \(message)")
}
private func printErrorMessage(_ message: String, in source: String, at location: SourceLocation, fileName: String) {
    let lines = location.lines(in: source).colloquialStringRepresentation
    let columns = location.columns(in: source).colloquialStringRepresentation
    print("error in \(fileName):\(lines):\(columns): \(message)")
}

private func printLocationSnippet(for location: SourceLocation, in source: String, indentation indentCount: Int, withMarker: Bool) {
    let indentation = String(repeating: " ", count: indentCount)
    
    let lineRange = source.lineRange(for: location.range)
    var line = source[lineRange].drop(while: { $0.isWhitespace }).dropLast(while: { $0.isNewline })
    if line.last?.isNewline ?? false {
        line.removeLast()
    }
    
    print("\(indentation)\(line)")
    
    if withMarker {
        let rangeLength = source.distance(from: location.range.lowerBound, to: location.range.upperBound)
        let highlightIndentCount = source.distance(from: line.startIndex, to: location.range.lowerBound)
        let highlightIndentation = String(repeating: " ", count: highlightIndentCount)
        
        print("\(indentation)\(highlightIndentation)\(rangeLength <= 1 ? "^" : String(repeating: "~", count: rangeLength))")
        print("\(indentation)\(highlightIndentation)HERE")
    }
}

extension Range where Bound: SignedInteger {
    
    var colloquialStringRepresentation: String {
        guard upperBound - 1 > lowerBound else {
            return "\(lowerBound)"
        }
        return "\(lowerBound)–\(upperBound - 1)"
    }
    
}

private func printSourceFixes(_ fixes: [SourceFix], in source: String) {
    for fix in fixes {
        print("  > possible fix: \(fix.contextualDescription(in: Substring(source)).replacingOccurrences(of: "\n", with: "\\n"))")
        
        var fixedSource = source
        var impacts: [FixImpact] = []
        do {
            try fix.apply(to: &fixedSource, initialSource: source, impacts: &impacts)
        } catch {
            print("error while applying fix: \(error)") // TODO: Move this code to Bushel and make this print an os_log
        }
        
        let lowestIndex = fix.locations.reduce(fix.locations[0].range.lowerBound) { $1.range.lowerBound < $0 ? $1.range.lowerBound : $0 }
        let highestIndex = fix.locations.reduce(fix.locations[0].range.upperBound) { $1.range.upperBound > $0 ? $1.range.upperBound : $0 }
        let combinedLocation = SourceLocation(lowestIndex..<highestIndex, source: fixedSource)
        printLocationSnippet(for: combinedLocation, in: fixedSource, indentation: 8, withMarker: true)
    }
}

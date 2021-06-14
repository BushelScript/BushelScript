// BushelScript command-line interface.
//
// © 2019-2021 Ian A. Gregory, licensed under the terms of the GPL v3 or later.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

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
        
        func validate() throws {
            if version {
                return
            }
            let modeCount = [interactive, !lines.isEmpty, scriptFile != nil].filter({ $0 }).count
            guard modeCount != 0 else {
                throw CleanExit.helpRequest()
            }
            guard modeCount == 1 else {
                throw ValidationError("-i, -e and <script-file> are mutually exclusive.")
            }
        }
        
    }
    
    func run() throws {
        if mode.version {
            printVersion()
            return
        } else if mode.interactive {
            try runREPL()
        } else if !mode.lines.isEmpty {
            let source = mode.lines.map { String($0) }.joined(separator: "\n")
            let parser = try module(for: options.language).parser()
            try run(parser: parser, rt: Runtime(), source: source, fileName: "<command-line>")
        } else if let file = mode.scriptFile {
            if file == "-" {
                try runFile(stdin, fileName: "<stdin>")
            } else {
                try runFile(file, fileName: file, url: URL(fileURLWithPath: file))
            }
        }
    }
    
    private func runFile(_ path: String, fileName: String, url: URL? = nil) throws {
        var source = try String.read(fromPath: path)
        var language = options.language
        var firstLine = source.prefix(while: { !$0.isNewline })
        firstLine.removeLeadingWhitespace()
        if firstLine.hasPrefix("#!") {
            let hashbang = String(firstLine)
            let languageIDRegex = try! NSRegularExpression(pattern: "-l\\s*(\\w+)", options: [])
            if
                let match = languageIDRegex.firstMatch(in: hashbang, options: [], range: NSRange(hashbang.range, in: hashbang)),
                let languageIDRange = Range<String.Index>(match.range(at: 1), in: hashbang)
            {
                language = String(hashbang[languageIDRange])
            }
            source = String(
                source[hashbang.endIndex...]
                .drop(while: { $0.isNewline })
            )
        }
        return try run(parser: try module(for: language).parser(), rt: Runtime(), source: source, fileName: fileName, url: url)
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
        
        let parser = try module(for: options.language).parser()
        let rt = Runtime()
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
                printError(error, in: parser.entireSource, fileName: "<repl>")
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

private struct NoSuchLanguage: LocalizedError {
    
    var language: String
    
    var errorDescription: String? {
        "Language module not found: \(language)"
    }
    
}

private func module(for language: String) throws -> LanguageModule {
    guard let languageModule = LanguageModule(identifier: language) else {
        throw NoSuchLanguage(language: language)
    }
    return languageModule
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

// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import Bushel
import BushelRT

private var defaultLanguageID = "bushelscript_en"

struct ToolInvocation {
    
    var files: [Substring] = []
    var scriptLines: [Substring] = []
    
    var language: String?
    var interactive: Bool = false
    var printResult: Bool = true
    
}

private struct InvocationState {
    
    var storedLanguageModule: (module: LanguageModule, language: String)?
    var storedParser: (parser: SourceParser, module: LanguageModule)?
    var rt = Runtime(currentApplicationBundleID: "com.justcheesy.BushelGUIHost")
    
}

extension ToolInvocation {
    
    func run() throws {
        var state = InvocationState()
        var lastResult: RT_Object?
        if !scriptLines.isEmpty {
            lastResult = run(&state, source: scriptLines.map { String($0) }.joined(separator: "\n"), fileName: "<command-line>", url: nil)
        }
        if !files.isEmpty {
            for file in files {
                let file = String(file)
                lastResult = run(&state, source: try String(contentsOfFile: file), fileName: file, url: URL(fileURLWithPath: file))
            }
        }
        if interactive {
            try runREPL(&state)
        } else if printResult, let lastResult = lastResult {
            print(lastResult)
        }
    }
    
    private func run(_ state: inout InvocationState, source: String, fileName: String, url: URL?) -> RT_Object? {
        var source = source
        var language = self.language
        
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
        
        do {
            let program = try parser(&state, for: language).parse(source: source, at: url)
            return try state.rt.run(program)
        } catch {
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
        return nil
    }
    
    private func runREPL(_ state: inout InvocationState) throws {
        printShortVersion()
        print("Type :exit or CTRL-D to exit")
        
        var lineNumber = 0
        func prompt() -> String? {
            print("\(lineNumber)> ", terminator: "")
            lineNumber += 1
            return readLine()
        }
        
        while let line = prompt() {
            guard !(Substring(line).trimmingWhitespace() == ":exit") else {
                return
            }
            if let result = run(&state, source: line, fileName: "<repl>", url: nil) {
                print(result)
            }
        }
        print()
    }
    
    private func parser(_ state: inout InvocationState, for language: String?) -> SourceParser {
        let languageModule = module(&state, for: language)
        if
            let (parser, storedModule) = state.storedParser,
            storedModule === languageModule
        {
            return parser
        }
        
        let parser = languageModule.parser()
        state.storedParser = (parser: parser, module: languageModule)
        return parser
    }
    
    private func module(_ state: inout InvocationState, for language: String?) -> LanguageModule {
        if
            let (module, storedLanguage) = state.storedLanguageModule,
            storedLanguage == language
        {
            return module
        }
        
        let language = language ?? defaultLanguageID
        guard let languageModule = LanguageModule(identifier: language) else {
            print("\nbushelscript: error: Language with identifier ‘\(language)’ not found!\n")
            exit(0)
        }
        return languageModule
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

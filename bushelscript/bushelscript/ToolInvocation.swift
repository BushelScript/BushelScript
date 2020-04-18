// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import BushelLanguage
import BushelRT
import Bushel // TEMPORARY!!

private var defaultLanguageID = "bushelscript_en"

struct ToolInvocation {
    
    var files: [Substring] = []
    var scriptLines: [Substring] = []
    
    var language: String?
    var interactive: Bool = false
    
}

private struct InvocationState {
    
    var storedLanguageModule: (module: LanguageModule, language: String)?
    var storedParser: (parser: SourceParser, module: LanguageModule)?
    var rt = RTInfo(currentApplicationBundleID: "com.justcheesy.BushelGUIHost")
    
}

extension ToolInvocation {
    
    func run() throws {
        var state = InvocationState()
        if !scriptLines.isEmpty {
            try run(&state, source: scriptLines.map { String($0) }.joined(separator: "\n"), fileName: "<command-line>")
        }
        if !files.isEmpty {
            for file in files {
                let file = String(file)
                try run(&state, source: try String(contentsOfFile: file), fileName: file)
            }
        }
        if interactive {
            try runREPL(&state)
        }
    }
    
    private func run(_ state: inout InvocationState, source: String, fileName: String) throws {
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
            let program = try parser(&state, for: language).parse(source: source)
            print(state.rt.run(program))
        } catch let error as ParseErrorProtocol {
            print(error: error, in: source, fileName: fileName)
        }
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
            try run(&state, source: line, fileName: "<repl>")
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

private func print(error: ParseErrorProtocol, in source: String, fileName: String) {
    let location = error.location

    let lines = location.lines(in: source).colloquialStringRepresentation
    let columns = location.columns(in: source).colloquialStringRepresentation
    print("error in \(fileName):\(lines):\(columns): \(error)") // FIXME: format the error
    
    printLocationSnippet(for: location, in: source, indentation: 4, withMarker: true)
    
    for fix in error.fixes {
        print("  > possible fix: \(fix.contextualDescription(in: Substring(source)).replacingOccurrences(of: "\n", with: "\\n"))")
        
        var fixedSource = source
        var impacts: [FixImpact] = []
        do {
            try fix.apply(to: &fixedSource, initialSource: source, impacts: &impacts)
        } catch {
            print("error while applying fix: \(error)") // TODO: Move this code to BushelLanguage and make this print an os_log
        }
        
        let lowestIndex = fix.locations.reduce(fix.locations[0].range.lowerBound) { $1.range.lowerBound < $0 ? $1.range.lowerBound : $0 }
        let highestIndex = fix.locations.reduce(fix.locations[0].range.upperBound) { $1.range.upperBound > $0 ? $1.range.upperBound : $0 }
        let combinedLocation = SourceLocation(lowestIndex..<highestIndex, source: fixedSource)
        printLocationSnippet(for: combinedLocation, in: fixedSource, indentation: 8, withMarker: true)
    }
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

private func description<S: StringProtocol>(of range: Range<S.Index>, mappedOnto string: S) -> String {
    return "[\(string.distance(from: string.startIndex, to: range.lowerBound)), \(string.distance(from: string.startIndex, to: range.upperBound)))"
}

extension Range where Bound: SignedInteger {
    
    var colloquialStringRepresentation: String {
        guard upperBound - 1 > lowerBound else {
            return "\(lowerBound)"
        }
        return "\(lowerBound)–\(upperBound - 1)"
    }
    
}

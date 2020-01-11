// BushelScript command-line interface.
// See file main.swift for copyright and licensing information.

import BushelLanguage
import BushelRT
import Bushel // TEMPORARY!!
import os

private var defaultLanguageID = "bushelscript_en"

struct ToolInvocation {
    
    var files: [Substring] = []
    var scriptLines: [Substring] = []
    
    var language: String?
    
}

extension ToolInvocation {
    
    func run() throws {
        if !scriptLines.isEmpty {
            try run(source: scriptLines.map { String($0) }.joined(separator: "\n"), fileName: "<command-line>")
        }
        if !files.isEmpty {
            for file in files {
                let file = String(file)
                try run(source: try String(contentsOfFile: file), fileName: file)
            }
        }
    }
    
    func run(source: String, fileName: String) throws {
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
        
        language = language ?? defaultLanguageID
        guard let languageModule = LanguageModule(identifier: language!) else {
            print("\nbushelscript: error: Language with identifier ‘\(language!)’ not found!\n")
            exit(0)
        }
        
        let parser: BushelLanguage.SourceParser = languageModule.parser(for: source)
        do {
            let program = try parser.parse()
            let rt = RTInfo(termPool: program.terms)
            rt.currentApplicationBundleID = "com.apple.systemevents" // TODO: Add an application ID here (similar to osascript)
            print(rt.run(program.ast))
        } catch let error as ParseError {
            print(error: error, in: source, fileName: fileName)
        }
    }
    
}

private func print(error: ParseError, in source: String, fileName: String) {
    let location = error.location
    #if DEBUG
    print(description(of: location.range, mappedOnto: source))
    #endif

    let lines = location.lines(in: source).colloquialStringRepresentation
    let columns = location.columns(in: source).colloquialStringRepresentation
    print("error in \(fileName):\(lines):\(columns): \(error.description)")
    
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

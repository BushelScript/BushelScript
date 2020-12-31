import XCTest
import BushelLanguage
import Bushel

open class FormatterTestCase: XCTestCase {
    
    public func runTest_programsCompileAfterReformatting(languageModule: LanguageModule, programs: [(name: String, source: String)]) {
        for (name, source) in programs {
            let program: Program
            do {
                program = try languageModule.parser().parse(source: source)
            } catch {
                return XCTFail("Initial parsing should succeed for \(name); error: \(error)")
            }
            let formattedSource = languageModule.formatter().format(program.ast)
            
            XCTAssertNoThrow(
                try languageModule.parser().parse(source: formattedSource),
                "Parsing after formatting should succeed for \(name)"
            )
        }
    }
    
    public func runTest_programsAreReformattedAsExpected(languageModule: LanguageModule, inPrograms: [(name: String, source: String)], outPrograms: [(name: String, source: String)]) {
        let outPrograms = [String : String](uniqueKeysWithValues: outPrograms)
        for (name, source) in inPrograms {
            guard let expectedOutSource = outPrograms[name] else {
                print("Skipping \(name) because it has no output defined")
                continue
            }
            
            let program: Program
            do {
                program = try languageModule.parser().parse(source: source)
            } catch {
                return XCTFail("Initial parsing should succeed for \(name); error: \(error)")
            }
            let formattedSource = languageModule.formatter().format(program.ast)
            
            XCTAssertEqual(
                formattedSource,
                expectedOutSource
            )
        }
    }
    
    public static func readPrograms(for class: FormatterTestCase.Type, from directory: String, subdirectory: String? = nil) -> [(name: String, source: String)] {
        let bundle = Bundle(for: `class`)
        let directoryURL = bundle.url(forResource: subdirectory ?? directory, withExtension: nil, subdirectory: subdirectory == nil ? nil : directory)!
        return readPrograms(from: directoryURL)
    }
    
    public static func readPrograms(from directoryURL: URL) -> [(name: String, source: String)] {
        try! FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: [])
            .map { fileURL in
                (
                    name: fileURL.lastPathComponent,
                    source: try String(contentsOf: fileURL)
                )
            }
    }

}

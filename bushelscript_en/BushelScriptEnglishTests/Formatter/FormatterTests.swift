import XCTest
import BushelLanguageTestingTools
import BushelLanguage

// Protip: ⌥⇧⌘← to fold all methods

private let inPrograms = FormatterTestCase.readPrograms(for: FormatterTests.self, from: "Formatter Test Cases", subdirectory: "In")
private let outPrograms = FormatterTestCase.readPrograms(for: FormatterTests.self, from: "Formatter Test Cases", subdirectory: "Out")

final class FormatterTests: FormatterTestCase {
    
    func test_programsCompileAfterReformatting() {
        runTest_programsCompileAfterReformatting(languageModule: module, programs: inPrograms)
    }
    
    func test_programsAreReformattedAsExpected() {
        runTest_programsAreReformattedAsExpected(languageModule: module, inPrograms: inPrograms, outPrograms: outPrograms)
    }

}

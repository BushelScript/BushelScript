import XCTest
@testable import BushelLanguage
import Bushel

// Protip: ⌥⇧⌘← to fold all methods

class TermNameSearchingTests: XCTestCase {
    
    func test_searchPerformace_alwaysSuccess_shortWords() {
        let source = String(
            repeating: "if let let end if to on let me to if on if to let let end end to on ", // 20 words
            count: 10
        )
        let terms: [TermName] = [
            "if",
            "let",
            "end",
            "on",
            "to"
        ].map { TermName($0) }
        
        measure {
            var source = Substring(source)
            while case (let termString, _?) = terms.findTermName(in: source) {
                source.removeFirst(termString.count)
            }
        }
    }

}

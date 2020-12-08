import XCTest
@testable import BushelLanguage
import Bushel

// Protip: ⌥⇧⌘← to fold all methods

private let sourceOrig = "one two three a b c"
private let source = sourceOrig[...]

class TermNameSearchingTests: XCTestCase {
    
    func termNames(_ strings: [String]) -> Set<TermName> {
        Set(strings.map { TermName($0) })
    }
    
    func test_simpleSearch_matchesAtBeginning() {
        let (termString, termName) = termNames(["one", "two"]).findSimpleTermName(in: source)
        XCTAssertEqual(termString, "one")
        XCTAssertEqual(termName, TermName("one"))
    }
    func test_simpleSearch_doesNotMatchBeyondFirst() {
        let (termString, termName) = termNames(["two", "three"]).findSimpleTermName(in: source)
        XCTAssertEqual(termString, "")
        XCTAssertEqual(termName, nil)
    }
    
    func test_complexSearch_matchesSingleWordAtBeginning() {
        let (termString, termName) = termNames(["one", "two"]).findComplexTermName(in: source)
        XCTAssertEqual(termString, "one")
        XCTAssertEqual(termName, TermName("one"))
    }
    func test_complexSearch_doesNotMatchSingleWordBeyondFirst() {
        let (termString, termName) = termNames(["two", "three"]).findComplexTermName(in: source)
        XCTAssertEqual(termString, "")
        XCTAssertEqual(termName, nil)
    }
    func test_complexSearch_matchesMultiWordAtBeginning() {
        let (termString, termName) = termNames(["one two three", "two", "three", "a"]).findComplexTermName(in: source)
        XCTAssertEqual(termString, "one two three")
        XCTAssertEqual(termName, TermName("one two three"))
    }
    
    func testPerformence_simpleSearch_shortWords() {
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
            while case (let termString, _?) = terms.findSimpleTermName(in: source) {
                source.removeFirst(termString.count)
            }
        }
    }

}

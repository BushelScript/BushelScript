import XCTest
@testable import BushelLanguage
import Bushel

// Protip: ⌥⇧⌘← to fold all methods

private let sourceOrig = "one two three a b c"
private let source = sourceOrig[...]

class TermNameSearchingTests: XCTestCase {
    
    func termNames(_ strings: [String]) -> Set<Term.Name> {
        Set(strings.map { Term.Name($0) })
    }
    
    func test_simpleSearch_matchesAtBeginning() {
        let (termString, termName) = termNames(["one", "two"]).findSimpleTermName(in: source)
        XCTAssertEqual(termString, "one")
        XCTAssertEqual(termName, Term.Name("one"))
    }
    func test_simpleSearch_doesNotMatchBeyondFirst() {
        let (termString, termName) = termNames(["two", "three"]).findSimpleTermName(in: source)
        XCTAssertEqual(termString, "")
        XCTAssertEqual(termName, nil)
    }
    
    func test_complexSearch_matchesSingleWordAtBeginning() {
        let table = buildTraversalTable(for: termNames(["one", "two"]))
        let (termString, termName) = findComplexTermName(from: table, in: source)
        XCTAssertEqual(termString, "one")
        XCTAssertEqual(termName, Term.Name("one"))
    }
    func test_complexSearch_doesNotMatchSingleWordBeyondFirst() {
        let table = buildTraversalTable(for: termNames(["two", "three"]))
        let (termString, termName) = findComplexTermName(from: table, in: source)
        XCTAssertEqual(termString, "")
        XCTAssertEqual(termName, nil)
    }
    func test_complexSearch_matchesMultiWordAtBeginning() {
        let table = buildTraversalTable(for: termNames(["one two three", "two", "three", "a"]))
        let (termString, termName) = findComplexTermName(from: table, in: source)
        XCTAssertEqual(termString, "one two three")
        XCTAssertEqual(termName, Term.Name("one two three"))
    }
    
    func testPerformence_simpleSearch_shortWords() {
        let source = String(
            repeating: "if let let end if to on let me to if on if to let let end end to on ", // 20 words
            count: 10
        )
        let terms: [Term.Name] = [
            "if",
            "let",
            "end",
            "on",
            "to"
        ].map { Term.Name($0) }
        
        measure {
            var source = Substring(source)
            while case (let termString, _?) = terms.findSimpleTermName(in: source) {
                source.removeFirst(termString.count)
            }
        }
    }

}

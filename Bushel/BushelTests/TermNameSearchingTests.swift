import XCTest
@testable import Bushel

// Protip: ⌥⇧⌘← to fold all methods

private let sourceOrig = "one two three a b c"
private let source = sourceOrig[...]

class TermNameSearchingTests: XCTestCase {
    
    func termNames(_ strings: [String]) -> Set<Term.Name> {
        Set(strings.map { Term.Name($0) })
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

}

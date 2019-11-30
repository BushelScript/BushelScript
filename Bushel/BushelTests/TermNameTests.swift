import XCTest
@testable import Bushel

// Protip: ⌥⇧⌘← to fold all methods

class TermNameSingleWordTests: XCTestCase {
    
    let nameStrings = [
        "h",
        "hi",
        "hello",
        "testing123",
        "l33t5p34ki5C00l",
        "headache-inducing",
        "com.example.My-App",
        "a_really_really_really_long_snake_case_name"
    ]
    lazy var names = nameStrings.map { TermName($0) }

    func test_noChangeOnNormalize() {
        XCTAssertEqual(names.map { $0.normalized }, nameStrings)
    }

}

class TermNameSingleWordWithWhitespaceTests: XCTestCase {
    
    let nameStrings = [
        " h ",
        " hi ",
        "  hello   ",
        " testing123",
        "   l33t5p34ki5C00l  ",
        "\theadache-inducing  ",
        "   com.example.My-App ",
        "            \t\n\r\na_really_really_really_long_snake_case_name    \r\n\t"
    ]
    lazy var names = nameStrings.map { TermName($0) }
    
    func test_whitespaceRemovedOnNormalize() {
        XCTAssertEqual(names.map { $0.normalized }, [
            "h",
            "hi",
            "hello",
            "testing123",
            "l33t5p34ki5C00l",
            "headache-inducing",
            "com.example.My-App",
            "a_really_really_really_long_snake_case_name"
        ])
    }
    
}

class TermNameMultiWordTests: XCTestCase {
    
    let nameStrings = [
        "h g",
        "hg hg",
        "hg is mercury",
        "Hg is the chemical symbol for mercury.",
        "The following dot forms a separate word .",
        "This hyphen is all alone , forming a separate word -",
        "Fun fact. A single underscore like the following is a valid C identifier. _"
    ]
    lazy var names = nameStrings.map { TermName($0) }
    
    func test_noChangeOnNormalize() {
        XCTAssertEqual(names.map { $0.normalized }, nameStrings)
    }
    
}

class TermNameMultiWordWithWhitespaceTests: XCTestCase {
    
    let nameStrings = [
        " h g ",
        " hg hg ",
        " hg  is \t mercury ",
        "  Hg is the chemical symbol for \tmercury.",
        " \n \r The following dot forms a separate word .\r\n",
        "     This  hyphen is   all alone,  forming a separate word \t  -",
        "Fun fact.  A single underscore like the following\r is a  valid \r\nC   identifier. _"
    ]
    lazy var names = nameStrings.map { TermName($0) }
    
    func test_properlySeparatedOnNormalize() {
        XCTAssertEqual(names.map { $0.normalized }, [
            "h g",
            "hg hg",
            "hg is mercury",
            "Hg is the chemical symbol for mercury.",
            "The following dot forms a separate word .",
            "This hyphen is all alone , forming a separate word -",
            "Fun fact. A single underscore like the following is a valid C identifier. _"
        ])
    }
    
}

class TermNameSinglyQualifiedTests: XCTestCase {
    
    let nameStrings = [
        "t : o",
        "t:o",
        "t: o",
        " t :o",
        "to : on",
        "Toronto :  Ontario ",
        " New York.  :  United States of America "
    ]
    lazy var names = nameStrings.map { TermName($0) }
    
    func test_properlySeparatedOnNormalize() {
        XCTAssertEqual(names.map { $0.normalized }, [
            "t : o",
            "t : o",
            "t : o",
            "t : o",
            "to : on",
            "Toronto : Ontario",
            "New York. : United States of America"
        ])
    }
    
}

class TermNameMultiQualifiedTests: XCTestCase {
    
    let nameStrings = [
        "g : d : g",
        "g:d:g",
        "g: d: g",
        " g :d :g",
        "go : dog : \tgo ",
        "Do you \t: like\t :  my hat\r\n : ‽",
    ]
    lazy var names = nameStrings.map { TermName($0) }
    
    func test_properlySeparatedOnNormalize() {
        XCTAssertEqual(names.map { $0.normalized }, [
            "g : d : g",
            "g : d : g",
            "g : d : g",
            "g : d : g",
            "go : dog : go",
            "Do you : like : my hat : ‽",
        ])
    }
    
}

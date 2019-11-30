import XCTest
@testable import bushelscript_en

// Protip: ⌥⇧⌘← to fold all methods

class LanguageConstructTests: XCTestCase {
    
    func test_use_invalidResourceType_emitsError() {
        XCTAssertThrowsError(try EnglishParser(source: "use Finder").parse())
        XCTAssertThrowsError(try EnglishParser(source: "use appl Finder").parse())
        XCTAssertThrowsError(try EnglishParser(source: "use application \"Finder\"").parse())
        XCTAssertThrowsError(try EnglishParser(source: "use com.apple.Finder").parse())
        XCTAssertThrowsError(try EnglishParser(source: "use appl com.apple.Finder").parse())
        XCTAssertThrowsError(try EnglishParser(source: "use id com.apple.Finder").parse())
        XCTAssertThrowsError(try EnglishParser(source: "use application id \"com.apple.Finder\"").parse())
    }
    
    func test_useApplication_notFound_emitsError() {
        XCTAssertThrowsError(try EnglishParser(source: "use app ThisAppDoesNotExistOnAnybodysSystem").parse())
        XCTAssertThrowsError(try EnglishParser(source: "use app id abc.xyz.ThisAppDoesNotExistOnAnybodysSystem").parse())
    }
    
    func test_useApplication_byName_findsApplication() {
        XCTAssertNoThrow(try EnglishParser(source: "use application Finder").parse())
        XCTAssertNoThrow(try EnglishParser(source: "use app Finder").parse())
    }
    
    func test_useApplication_byID_findsApplication() {
        XCTAssertNoThrow(try EnglishParser(source: "use application id com.apple.Finder").parse())
        XCTAssertNoThrow(try EnglishParser(source: "use app id com.apple.Finder").parse())
    }
    
    func test_if() {
        // if-end
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
    789
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
    789
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
    789
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
    789
end
""").parse())
        
        // single-line if
        XCTAssertNoThrow(try EnglishParser(source: "if 123 then 456").parse())
        
        // if-else-end
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
else
    789
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
else
    789
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
else
    789
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
else
    789
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
else
    789
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
else
    789
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
else
    789
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
else
    789
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
    789
else
    654
    321
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
    789
else
    654
    321
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
    789
else
    654
    321
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
    789
else
    654
    321
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
else
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
else
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
else
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
else
end
""").parse())
        
        // single-line if with multi-line else
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then 456
else 789
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then 456
else
    789
end if
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then 456
else
    789
end
""").parse())
        
        // multi-line if with single-line else
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
else 789
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123
    456
else 789
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
else 789
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
if 123 then
    456
else 789
""").parse())
    }
    
    func test_tell() {
        XCTAssertNoThrow(try EnglishParser(source: """
tell 123
    456
end tell
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
tell 123
    456
    789
end tell
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
tell 123
end tell
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
tell 123
    456
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
tell 123
    456
    789
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: """
tell 123
end
""").parse())
        XCTAssertNoThrow(try EnglishParser(source: "tell 123 to 456").parse())
    }
    
}

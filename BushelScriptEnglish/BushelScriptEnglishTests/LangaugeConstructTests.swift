import XCTest
@testable import bushelscript_en

// Protip: ⌥⇧⌘← to fold all methods

class LanguageConstructTests: XCTestCase {
    
    func test_use_invalidResourceType_emitsError() {
        XCTAssertThrowsError(try EnglishParser().parse(source: "use Finder"))
        XCTAssertThrowsError(try EnglishParser().parse(source: "use appl Finder"))
        XCTAssertThrowsError(try EnglishParser().parse(source: "use application \"Finder\""))
        XCTAssertThrowsError(try EnglishParser().parse(source: "use com.apple.Finder"))
        XCTAssertThrowsError(try EnglishParser().parse(source: "use appl com.apple.Finder"))
        XCTAssertThrowsError(try EnglishParser().parse(source: "use id com.apple.Finder"))
        XCTAssertThrowsError(try EnglishParser().parse(source: "use application id \"com.apple.Finder\""))
    }
    
    func test_useApplication_notFound_emitsError() {
        XCTAssertThrowsError(try EnglishParser().parse(source: "use app ThisAppDoesNotExistOnAnybodysSystem"))
        XCTAssertThrowsError(try EnglishParser().parse(source: "use app id abc.xyz.ThisAppDoesNotExistOnAnybodysSystem"))
    }
    
    func test_useApplication_byName_findsApplication() {
        XCTAssertNoThrow(try EnglishParser().parse(source: "use application Finder"))
        XCTAssertNoThrow(try EnglishParser().parse(source: "use app Finder"))
    }
    
    func test_useApplication_byID_findsApplication() {
        XCTAssertNoThrow(try EnglishParser().parse(source: "use application id com.apple.Finder"))
        XCTAssertNoThrow(try EnglishParser().parse(source: "use app id com.apple.Finder"))
    }
    
    func test_if() {
        // if-end
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
    789
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
    789
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
    789
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
    789
end
"""))
        
        // single-line if
        XCTAssertNoThrow(try EnglishParser().parse(source: "if 123 then 456"))
        
        // if-else-end
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
else
    789
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
else
    789
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
else
    789
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
else
    789
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
else
    789
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
else
    789
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
else
    789
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
else
    789
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
    789
else
    654
    321
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
    789
else
    654
    321
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
    789
else
    654
    321
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
    789
else
    654
    321
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
else
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
else
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
else
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
else
end
"""))
        
        // single-line if with multi-line else
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then 456
else 789
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then 456
else
    789
end if
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then 456
else
    789
end
"""))
        
        // multi-line if with single-line else
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
else 789
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123
    456
else 789
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
else 789
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
if 123 then
    456
else 789
"""))
    }
    
    func test_tell() {
        XCTAssertNoThrow(try EnglishParser().parse(source: """
tell 123
    456
end tell
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
tell 123
    456
    789
end tell
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
tell 123
end tell
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
tell 123
    456
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
tell 123
    456
    789
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: """
tell 123
end
"""))
        XCTAssertNoThrow(try EnglishParser().parse(source: "tell 123 to 456"))
    }
    
}

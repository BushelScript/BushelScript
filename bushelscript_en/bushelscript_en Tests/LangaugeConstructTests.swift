import XCTest
import Bushel

// Protip: ⌥⇧⌘← to fold all methods

class LanguageConstructTests: XCTestCase {
    
    func test_require_invalidResourceType_emitsError() {
        let parser = module.parser()
        XCTAssertThrowsError(try parser.parse(source: "require Finder"))
        XCTAssertThrowsError(try parser.parse(source: "require ap Finder"))
        XCTAssertThrowsError(try parser.parse(source: "require com.apple.Finder"))
        XCTAssertThrowsError(try parser.parse(source: "require ap com.apple.Finder"))
        XCTAssertThrowsError(try parser.parse(source: "require id com.apple.Finder"))
    }
    
    func test_requireApplication_notFound_emitsError() {
        let parser = module.parser()
        XCTAssertThrowsError(try parser.parse(source: "require app ThisAppDoesNotExistOnAnybodysSystem"))
        XCTAssertThrowsError(try parser.parse(source: "require app id abc.xyz.ThisAppDoesNotExistOnAnybodysSystem"))
    }
    
    func test_requireApplication_byName_findsApplication() {
        let parser = module.parser()
        XCTAssertNoThrow(try parser.parse(source: "require app Finder"))
    }
    
    func test_requireApplication_byID_findsApplication() {
        let parser = module.parser()
        XCTAssertNoThrow(try parser.parse(source: "require app id com.apple.Finder"))
    }
    
    func test_if() {
        let parser = module.parser()
        // if-end
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
    789
end
"""))
        
        // single-line if
        XCTAssertNoThrow(try parser.parse(source: "if 123 then 456"))
        
        // if-else-end
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
else
    789
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
else
    789
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
    789
else
    654
    321
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
else
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
else
end
"""))
        
        // multi-line if with single-line else
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
else 789
"""))
    }
    
    func test_tell() {
        let parser = module.parser()
        XCTAssertNoThrow(try parser.parse(source: """
tell 123
    456
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
tell 123
    456
    789
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
tell 123
end
"""))
        XCTAssertNoThrow(try parser.parse(source: "tell 123 to 456"))
    }
    
}

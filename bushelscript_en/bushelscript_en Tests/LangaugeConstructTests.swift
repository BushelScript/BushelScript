import XCTest
import BushelLanguage

// Protip: ⌥⇧⌘← to fold all methods

internal let moduleID = "bushelscript_en"
internal let module = LanguageModule(identifier: "bushelscript_en")!

class LanguageConstructTests: XCTestCase {
    
    func test_use_invalidResourceType_emitsError() {
        let parser = module.parser()
        XCTAssertThrowsError(try parser.parse(source: "use Finder"))
        XCTAssertThrowsError(try parser.parse(source: "use appl Finder"))
        XCTAssertThrowsError(try parser.parse(source: "use application \"Finder\""))
        XCTAssertThrowsError(try parser.parse(source: "use com.apple.Finder"))
        XCTAssertThrowsError(try parser.parse(source: "use appl com.apple.Finder"))
        XCTAssertThrowsError(try parser.parse(source: "use id com.apple.Finder"))
        XCTAssertThrowsError(try parser.parse(source: "use application id \"com.apple.Finder\""))
    }
    
    func test_useApplication_notFound_emitsError() {
        let parser = module.parser()
        XCTAssertThrowsError(try parser.parse(source: "use app ThisAppDoesNotExistOnAnybodysSystem"))
        XCTAssertThrowsError(try parser.parse(source: "use app id abc.xyz.ThisAppDoesNotExistOnAnybodysSystem"))
    }
    
    func test_useApplication_byName_findsApplication() {
        let parser = module.parser()
        XCTAssertNoThrow(try parser.parse(source: "use application Finder"))
        XCTAssertNoThrow(try parser.parse(source: "use app Finder"))
    }
    
    func test_useApplication_byID_findsApplication() {
        let parser = module.parser()
        XCTAssertNoThrow(try parser.parse(source: "use application id com.apple.Finder"))
        XCTAssertNoThrow(try parser.parse(source: "use app id com.apple.Finder"))
    }
    
    func test_if() {
        let parser = module.parser()
        // if-end
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then
    456
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then
    456
    789
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
if 123 then
    456
else
    789
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
else
    789
end
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then
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
if 123 then
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
        
        // single-line if with multi-line else
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then 456
else 789
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then 456
else
    789
end
"""))
        
        // multi-line if with single-line else
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then
    456
else 789
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123
    456
else 789
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then
    456
else 789
"""))
        XCTAssertNoThrow(try parser.parse(source: """
if 123 then
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

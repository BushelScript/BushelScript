import XCTest
@testable import BushelLanguage
import Bushel

// Protip: ⌥⇧⌘← to fold all methods

class TranslationParserTests: XCTestCase {
    
    private let currentFormat = "0.1"
    
    func test_parsesMetadata() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(translation.format, currentFormat, "Should parse the 'format' key")
        XCTAssertEqual(translation.language, "bushelscript_en", "Should parse the 'language' key")
    }
    
    func test_rejectsNewerFormat() throws {
        let translationSource = """
translation:
    format: 9999.0
    language: bushelscript_en
"""
        XCTAssertThrowsError(try Translation(source: translationSource), "A newer translation format should be rejected") { error in
            guard
                let parseError = error as? BushelLanguage.Translation.ParseError,
                case .invalidFormat = parseError
            else {
                return XCTFail("Should throw a Translation.ParseError.invalidFormat")
            }
        }
    }

    func test_parsesMappings_ae4() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        type:
            ae4:
                cobj: item
        property:
            ae4:
                pALL: properties
        constant:
            ae4:
                'true': 'true'
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.type, .ae4(code: try! FourCharCode(fourByteString: "cobj")))],
            TermName("item"),
            "ae4 type should have supplied name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.property, .ae4(code: try! FourCharCode(fourByteString: "pALL")))],
            TermName("properties"),
            "ae4 property should have supplied name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.constant, .ae4(code: try! FourCharCode(fourByteString: "true")))],
            TermName("true"),
            "ae4 constant should have supplied name"
        )
    }
    
    func test_parsesMappings_ae8() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        command:
            ae8:
                coresetd: set
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.command, .ae8(class: try! FourCharCode(fourByteString: "core"), id: try! FourCharCode(fourByteString: "setd")))],
            TermName("set"),
            "ae8 command should have supplied name"
        )
    }
        
    func test_parsesMappings_ae12() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        parameter:
            ae12:
                coresetddata: to
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.parameter, .ae12(class: try! FourCharCode(fourByteString: "core"), id: try! FourCharCode(fourByteString: "setd"), code: try! FourCharCode(fourByteString: "data")))],
            TermName("to"),
            "ae12 parameter should have supplied name"
        )
    }
    
    func test_parsesMappings_id_simple() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        type:
            id:
                global: BushelScript
        property:
            id:
                current date: current date
        command:
            id:
                delay: delay
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.type, .id("global"))],
            TermName("BushelScript"),
            "id type should have supplied name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.property, .id("current date"))],
            TermName("current date"),
            "id property should have supplied name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.command, .id("delay"))],
            TermName("delay"),
            "id command should have supplied name"
        )
    }
    
    func test_parsesMappings_id_nested() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        property:
            id:
                Math:
                    pi: pi
        command:
            id:
                Math:
                    abs: absolute value
                    sqrt: √
        parameter:
            id:
                Math:
                    pow:
                        /direct: of
                        exponent: to the
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.property, .id("Math:pi"))],
            TermName("pi"),
            "Nested id property should have supplied name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.command, .id("Math:abs"))],
            TermName("absolute value"),
            "Nested id command should have supplied name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.command, .id("Math:sqrt"))],
            TermName("√"),
            "Nested id command should have supplied name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.parameter, .id("Math:pow:/direct"))],
            TermName("of"),
            "Nested id parameter should have supplied name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.parameter, .id("Math:pow:exponent"))],
            TermName("to the"),
            "Nested id parameter should have supplied name"
        )
    }
    
    func test_parsesMappings_ae4_withSynonyms() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        type:
            ae4:
                capp:
                    - application
                    - app
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.type, .ae4(code: try! FourCharCode(fourByteString: "capp")))],
            [TermName("application"), TermName("app")],
            "ae4 type should have supplied synonymous names"
        )
    }
    
    func test_parsesMappings_id_withSynonyms() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        command:
            id:
                delay:
                    - delay
                    - wait
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.command, .id("delay"))],
            [TermName("delay"), TermName("wait")],
            "id command should have supplied synonymous names"
        )
    }
        
    func test_parsesMappings_ae4_withVariants() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        type:
            ae4:
                alis:
                    /standard: alias
                    /plural: aliases
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.type, .ae4(code: try! FourCharCode(fourByteString: "alis")))],
            [TermName("alias")],
            "ae4 type should have variant name"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.type, .variant(.plural, .ae4(code: try! FourCharCode(fourByteString: "alis"))))],
            [TermName("aliases")],
            "ae4 type should have variant name"
        )
    }
    
    
    func test_parsesMappings_ae4_withSynonymousVariants() throws {
        let translationSource = """
translation:
    format: \(currentFormat)
    language: bushelscript_en
    mappings:
        type:
            ae4:
                utxt:
                    /standard:
                        - string
                        - text
                    /plural:
                        - strings
                        - text
                utf8:
                    -
                        /standard: UTF-8 string
                        /plural: UTF-8 strings
                    -
                        /standard: UTF-8 text
                        /plural: UTF-8 text
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[TypedTermUID(.type, .ae4(code: try! FourCharCode(fourByteString: "utxt")))],
            [TermName("string"), TermName("text")],
            "ae4 type should have supplied synonymous variant names"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.type, .variant(.plural, .ae4(code: try! FourCharCode(fourByteString: "utxt"))))],
            [TermName("strings"), TermName("text")],
            "ae4 type should have supplied synonymous variant names"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.type, .ae4(code: try! FourCharCode(fourByteString: "utf8")))],
            [TermName("UTF-8 string"), TermName("UTF-8 text")],
            "ae4 type should have supplied synonymous variant names"
        )
        XCTAssertEqual(
            translation[TypedTermUID(.type, .variant(.plural, .ae4(code: try! FourCharCode(fourByteString: "utf8"))))],
            [TermName("UTF-8 strings"), TermName("UTF-8 text")],
            "ae4 type should have supplied synonymous variant names"
        )
    }
    
}

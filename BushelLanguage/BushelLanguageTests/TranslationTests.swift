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
            translation[Term.ID(.type, .ae4(code: try! FourCharCode(fourByteString: "cobj")))],
            Term.Name("item"),
            "ae4 type should have supplied name"
        )
        XCTAssertEqual(
            translation[Term.ID(.property, .ae4(code: try! FourCharCode(fourByteString: "pALL")))],
            Term.Name("properties"),
            "ae4 property should have supplied name"
        )
        XCTAssertEqual(
            translation[Term.ID(.constant, .ae4(code: try! FourCharCode(fourByteString: "true")))],
            Term.Name("true"),
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
            translation[Term.ID(.command, .ae8(class: try! FourCharCode(fourByteString: "core"), id: try! FourCharCode(fourByteString: "setd")))],
            Term.Name("set"),
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
            translation[Term.ID(.parameter, .ae12(class: try! FourCharCode(fourByteString: "core"), id: try! FourCharCode(fourByteString: "setd"), code: try! FourCharCode(fourByteString: "data")))],
            Term.Name("to"),
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
            translation[Term.ID(.type, .id("global"))],
            Term.Name("BushelScript"),
            "id type should have supplied name"
        )
        XCTAssertEqual(
            translation[Term.ID(.property, .id("current date"))],
            Term.Name("current date"),
            "id property should have supplied name"
        )
        XCTAssertEqual(
            translation[Term.ID(.command, .id("delay"))],
            Term.Name("delay"),
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
                        .direct: of
                        exponent: to the
"""
        let translation = try Translation(source: translationSource)
        
        XCTAssertEqual(
            translation[Term.ID(.property, .id("Math:pi"))],
            Term.Name("pi"),
            "Nested id property should have supplied name"
        )
        XCTAssertEqual(
            translation[Term.ID(.command, .id("Math:abs"))],
            Term.Name("absolute value"),
            "Nested id command should have supplied name"
        )
        XCTAssertEqual(
            translation[Term.ID(.command, .id("Math:sqrt"))],
            Term.Name("√"),
            "Nested id command should have supplied name"
        )
        XCTAssertEqual(
            translation[Term.ID(.parameter, .id("Math:pow:.direct"))],
            Term.Name("of"),
            "Nested id parameter should have supplied name"
        )
        XCTAssertEqual(
            translation[Term.ID(.parameter, .id("Math:pow:exponent"))],
            Term.Name("to the"),
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
            translation[Term.ID(.type, .ae4(code: try! FourCharCode(fourByteString: "capp")))],
            [Term.Name("application"), Term.Name("app")],
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
            translation[Term.ID(.command, .id("delay"))],
            [Term.Name("delay"), Term.Name("wait")],
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
            translation[Term.ID(.type, .ae4(code: try! FourCharCode(fourByteString: "alis")))],
            [Term.Name("alias")],
            "ae4 type should have variant name"
        )
        XCTAssertEqual(
            translation[Term.ID(.type, .variant(.plural, .ae4(code: try! FourCharCode(fourByteString: "alis"))))],
            [Term.Name("aliases")],
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
            translation[Term.ID(.type, .ae4(code: try! FourCharCode(fourByteString: "utxt")))],
            [Term.Name("string"), Term.Name("text")],
            "ae4 type should have supplied synonymous variant names"
        )
        XCTAssertEqual(
            translation[Term.ID(.type, .variant(.plural, .ae4(code: try! FourCharCode(fourByteString: "utxt"))))],
            [Term.Name("strings"), Term.Name("text")],
            "ae4 type should have supplied synonymous variant names"
        )
        XCTAssertEqual(
            translation[Term.ID(.type, .ae4(code: try! FourCharCode(fourByteString: "utf8")))],
            [Term.Name("UTF-8 string"), Term.Name("UTF-8 text")],
            "ae4 type should have supplied synonymous variant names"
        )
        XCTAssertEqual(
            translation[Term.ID(.type, .variant(.plural, .ae4(code: try! FourCharCode(fourByteString: "utf8"))))],
            [Term.Name("UTF-8 strings"), Term.Name("UTF-8 text")],
            "ae4 type should have supplied synonymous variant names"
        )
    }
    
}

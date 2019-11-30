//
//  GlueTable.swift
//  SwiftAutomation
//
//  Combines default and application-specific terminology into lookup tables used
//  by AE bridge.
//
//  The `aeglue` tool uses these tables to add properties and methods to a glue's
//  Symbol subclass and Query and Command protocol extensions; formatAppleEvent()
//  uses them to translate typeAppleEvent descriptors to SwiftAutomation syntax.
//
//  May also be used by dynamic AE bridges.
//

// TO DO: this isn't the most efficient design: the parser loops over entire dictionary to extract lists of name+code pairs, then GlueTable loops over those again. Ideally parsers would add entries to glue tables directly as they read dictionaries; however, this'll need some thought as the order in which duplicate names/codes are read is significant. The current implementation mimics the AS behavior (when names are duplicated the last definition is used; however, when codes are duplicated the first definition is used); any replacement would need to do likewise. (Keyword conversion could also be more efficient; may be worth moving that to AETE+SDEF parsers.)

import Foundation
import SDEFinitely

public typealias ElementName = (singular: String, plural: String)


public class GlueTable {
    // provides lookup tables used by language-specific bridges to pack/unpack/format symbols, specifiers, and commands
    // note: dictionary structures are optimized for dynamic bridges, but are also usable
    // by static glue generators (which aren't performance-sensitive anyway)
    
    public private(set) var typesByName:      [String:NSAppleEventDescriptor] = [:] // Symbol members (properties, types, and enums)
    public private(set) var typesByCode:      [OSType:String]      = [:]
    
    public private(set) var elementsByName:   [String:KeywordTerm] = [:]
    public private(set) var elementsByCode:   [OSType:ElementName] = [:] // (singular, plural)
    
    public private(set) var propertiesByName: [String:KeywordTerm] = [:] // e.g. AERecord keys
    public private(set) var propertiesByCode: [OSType:String]      = [:]
    
    public private(set) var commandsByName:   [String:CommandTerm] = [:]
    public private(set) var commandsByCode:   [UInt64:CommandTerm] = [:] // key is eventClass<<32|eventID
    
    private var _specifiersByName:            [String:Term]?
    
    // get property/elements/command by name; this eliminates duplicate (e.g. property+elements) names,
    // according [hopefully] to the same internal rules used by AppleScript; note, however, that AS does
    // still allow elements names masked by property names to be used by adding `every` keyword;
    // TO DO: add an `ObjectSpecifier.all` property to do the same (also, review special-case handling of
    // `text` property/element - it's probably correct since AS defines `text` as an element name itself,
    // but best be safe)
    public var specifiersByName: [String:Term] {
        if self._specifiersByName == nil {
            self._specifiersByName = [String:Term]()
            for termsByName in [self.elementsByName, self.propertiesByName, self.commandsByName] as [[String:Term]] {
                for (key, value) in termsByName { self._specifiersByName![key] = value }
            }
        }
        return self._specifiersByName!
    }
    
    // copies of SwiftAutomation's built-in terms, used to disambiguate any conflicting app-defined names
    private var defaultTypesByName: [String:NSAppleEventDescriptor] = [:]
    private var defaultPropertiesByName: [String:KeywordTerm] = [:]
    private var defaultElementsByName: [String:KeywordTerm] = [:]
    private var defaultCommandsByName: [String:CommandTerm] = [:]
    
    private let keywordConverter: KeywordConverter
    private let allowSingularElements: Bool
    
    public init(keywordConverter: KeywordConverter, allowSingularElements: Bool = false) {
        self.keywordConverter = keywordConverter
        self.allowSingularElements = allowSingularElements
        self.add(terminology: keywordConverter.defaultTerminology)
        // retain copies of default type and command terms; these will be used to disambiguate
        // any conflicting application-defined terms added later
        self.defaultTypesByName = self.typesByName
        self.defaultPropertiesByName = self.propertiesByName
        self.defaultElementsByName = self.elementsByName
        self.defaultCommandsByName = self.commandsByName
    }
    
    
    private func add(symbolKeywords keywords: [KeywordTerm], descriptorType: OSType) {
        let len = keywords.count
        for i in 0..<len {
            do { // add a definition to typeByCode table
                // to handle synonyms, if same code appears more than once then uses name from last definition in list
                let term = keywords[i]
                var name = term.name
                let code = term.code
                if !(name == "missing value" && code == _cMissingValue) { // (ignore `missing value` as it's treated separately)
                    // escape definitions that semi-overlap default definitions
                    if let desc = self.defaultTypesByName[name] {
                        if desc.typeCodeValue != code {
                            name = self.keywordConverter.escapeName(name)
                            term.name = name
                        }
                    }
                    // add item
                    self.typesByCode[code] = name
                }
            }
            do { // add a definition to typeByName table
                // to handle synonyms, if same name appears more than once then uses code from first definition in list (iterating array in reverse ensures this)
                let term = keywords[len - 1 - i]
                var name = term.name
                var code = term.code // actually constant, but NSAppleEventDescriptor constructor below insists on var
                if !(name == "missing value" && code == _cMissingValue) { // (ignore `missing value` as it's treated separately)
                    // escape definitions that semi-overlap default definitions
                    if let desc = self.defaultTypesByName[name] {
                        if desc.typeCodeValue != code {
                            name = self.keywordConverter.escapeName(name)
                            term.name = name
                        }
                    }
                    // add item
                    self.typesByName[name] = NSAppleEventDescriptor(descriptorType: descriptorType,
                                                                    bytes: &code, length: MemoryLayout<OSType>.size)
                }
            }
        }
    }
    
    private func add(propertyKeywords keywords: [KeywordTerm], defaultKeywordsByName: [String : KeywordTerm]? = nil) {
        let defaultKeywordsByName = defaultKeywordsByName ?? self.defaultPropertiesByName
        let len = keywords.count
        for i in 0..<len {
            do { // add a definition to the propertiesByCode table
                // to handle synonyms, if same code appears more than once then uses name from last definition in list
                let term = keywords[i]
                var name = term.name
                let code = term.code
                if let defaultTerm = defaultKeywordsByName[name] {
                    if code != defaultTerm.code {
                        name = self.keywordConverter.escapeName(name)
                        term.name = name
                    }
                }
                self.propertiesByCode[code] = name
            }
            do { // add a definition to the propertiesByName table
                // to handle synonyms, if same name appears more than once then uses code from first definition in list (iterating array in reverse ensures this)
                let term = keywords[len - 1 - i]
                var name = term.name
                let code = term.code
                if let defaultTerm = defaultKeywordsByName[name] {
                    if code != defaultTerm.code {
                        name = self.keywordConverter.escapeName(name)
                        term.name = name
                    }
                }
                self.propertiesByName[name] = term
            }
        }
    }
    
    private func add(elementKeywords keywords: [ClassTerm], defaultKeywordsByName: [String : KeywordTerm]? = nil) {
        let defaultKeywordsByName = defaultKeywordsByName ?? self.defaultElementsByName
        let len = keywords.count
        for i in 0..<len {
            do { // add a definition to the elementsByCode table
                // to handle synonyms, if same code appears more than once then uses name from last definition in list
                let term = keywords[i]
                var singular = term.singular
                var plural = term.plural
                let code = term.code
                if let defaultTerm = defaultKeywordsByName[singular] {
                    if code != defaultTerm.code {
                        singular = self.keywordConverter.escapeName(singular)
                        term.singular = singular
                    }
                }
                if let defaultTerm = defaultKeywordsByName[plural] {
                    if code != defaultTerm.code {
                        plural = self.keywordConverter.escapeName(plural)
                        term.plural = plural
                    }
                }
                self.elementsByCode[code] = (singular, plural)
            }
            do { // add a definition to the elementsByName table
                // to handle synonyms, if same name appears more than once then uses code from first definition in list (iterating array in reverse ensures this)
                let term = keywords[len - 1 - i]
                var plural = term.plural
                let code = term.code
                if let defaultTerm = defaultKeywordsByName[plural] {
                    if code != defaultTerm.code {
                        plural = self.keywordConverter.escapeName(plural)
                        term.plural = plural
                    }
                }
                self.elementsByName[plural] = term
                // optionally also allow singular form in element references, e.g. `document 1`
                if self.allowSingularElements {
                    var singular = term.singular
                    let code = term.code
                    if let defaultTerm = defaultKeywordsByName[singular] {
                        if code != defaultTerm.code {
                            singular = self.keywordConverter.escapeName(singular)
                            term.singular = singular
                        }
                    }
                    self.elementsByName[singular] = term
                }
            }
        }
    }

    private func add(commandKeywords commands: [CommandTerm]) {
        let len = commands.count
        for i in 0..<len {
            // to handle synonyms, if two commands have same name but different codes, only the first definition should be used (iterating array in reverse ensures this)
            let term = commands[len - 1 - i]
            var name = term.name;
            let eventClass = term.eventClass
            let eventID = term.eventID
            // Avoid collisions between default commands and application-defined commands with same name
            // but different code (e.g. 'get' and 'set' in InDesign CS2):
            if let existingCommandDef = self.defaultCommandsByName[name] {
                if existingCommandDef.eventClass != eventClass || existingCommandDef.eventID != eventID {
                    term.name = keywordConverter.escapeName(name)
                    name = term.name
                }
            }
            // add item
            self.commandsByName[name] = term
            self.commandsByCode[eightCharCode(eventClass, eventID)] = term
        }
    }

    // called by parseAETE/parseSDEF 
    // (note: default terminology is added automatically when GlueTable is instantiated; users should not add it themselves)
    public func add(terminology terms: ApplicationTerminology) {
        // build type tables
        self.add(symbolKeywords: terms.properties, descriptorType: typeType) // technically typeProperty, but typeType is prob. safest
        self.add(symbolKeywords: terms.enumerators, descriptorType: typeEnumerated)
        self.add(symbolKeywords: terms.types, descriptorType: typeType)
        // build specifier tables
        self.add(elementKeywords: terms.elements, defaultKeywordsByName: self.defaultElementsByName)
        self.add(propertyKeywords: terms.properties, defaultKeywordsByName: self.defaultPropertiesByName)
        // build command table
        self.add(commandKeywords: terms.commands)
        // special case: if property table contains a 'text' definition, move it to element table
        // (AppleScript always packs 'text of...' as an all-elements specifier, not a property specifier)
        // TO DO: should check if this rule only applies to 'text', or other ambiguous property/element names too
        if let specialTerm = self.propertiesByName["text"] {
            self.elementsByName["text"] = ClassTerm(singular: specialTerm.name, plural: specialTerm.name, code: specialTerm.code)
            self.propertiesByName.removeValue(forKey: "text")
        }
        self._specifiersByName = nil
    }
    
    //
    
    public func add(AETE descriptor: NSAppleEventDescriptor) throws {
        // note: use `try AEApplication(url: url).getAETE()` to retrieve typeAETE descriptor via an 'ascr'/'gdte' Apple event, or use
        // `OSAGetSysTerminology()` to get typeAEUT (language component)'s AETE/AEUT resource (e.g. for AppleScript's built-in terminology)
        let parser = AETEParser(keywordConverter: self.keywordConverter)
        try parser.parse(descriptor)
        self.add(terminology: parser)
    }
    
    public func add(SDEF data: Data) throws {
        struct Delegate: SDEFParserDelegate {
            init(table: GlueTable) {
                self.table = table
            }
            let table: GlueTable
            func addType(_ term: SDEFinitely.KeywordTerm) {
                table.add(symbolKeywords: [KeywordTerm(name: term.name, kind: .type, code: term.code)], descriptorType: typeType)
            }
            func addClass(_ term: SDEFinitely.ClassTerm) {
                table.add(elementKeywords: [ClassTerm(singular: term.name, plural: term.pluralName, code: term.code)])
            }
            func addProperty(_ term: SDEFinitely.KeywordTerm) {
                table.add(symbolKeywords: [KeywordTerm(name: term.name, kind: .property, code: term.code)], descriptorType: typeType) // technically typeProperty, but typeType is prob. safest
            }
            func addEnumerator(_ term: SDEFinitely.KeywordTerm) {
                table.add(symbolKeywords: [KeywordTerm(name: term.name, kind: .enumerator, code: term.code)], descriptorType: typeEnumerated)
            }
            func addCommand(_ term: SDEFinitely.CommandTerm) {
                table.add(commandKeywords: [CommandTerm(name: term.name, eventClass: term.eventClass, eventID: term.eventID)])
            }
        }
        let delegate = Delegate(table: self)
        let parser = SDEFParser(delegate: delegate)
        try parser.parse(data) 
    }
    
    public func add(SDEF url: URL) throws { // url may be file:// (for .sdef resource) or eppc:// (assuming OSACopyScriptingDefinitionFromURL works right now)
        try self.add(SDEF: SDEFinitely.readSDEF(from: url))
    }
}

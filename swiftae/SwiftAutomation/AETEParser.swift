//
//  AETEParser.swift
//  SwiftAutomation
//
//

// Ian's notes: Not currently used but could be useful in the future,
// especially if AppKit itself occasionally bungles AETE parsing as
// the original author so claims.

// TO DO: check endianness in read data methods

import Foundation
import SDEFinitely

/**********************************************************************/

public class AETEParser {
    
    public private(set) var types: [ClassTerm] = []
    public private(set) var enumerators: [KeywordTerm] = []
    public private(set) var properties: [KeywordTerm] = []
    public private(set) var elements: [ClassTerm] = []
    public var commands: [CommandTerm] { return Array(self.commandsDict.values) }
    
    private var commandsDict = [String:CommandTerm]()
    
    // following are used in parse() to supply 'missing' singular/plural class names
    private var classDefinitionsByCode = [OSType : ClassTerm]()
    
    var aeteData = NSData() // was char*
    var cursor: Int = 0 // was unsigned long
    
    public func parse(_ descriptor: NSAppleEventDescriptor) throws { // accepts AETE/AEUT or AEList of AETE/AEUTs
        switch descriptor.descriptorType {
        case _typeAETE, _typeAEUT:
            self.aeteData = descriptor.data as NSData
            self.cursor = 6 // skip version, language, script integers
            let n = self.short()
            do {
                for _ in 0..<n {
                    try self.parseSuite()
                }
                /* singular names are normally used in the classes table and plural names in the elements table. However, if an aete defines a singular name but not a plural name then the missing plural name is substituted with the singular name; and vice-versa if there's no singular equivalent for a plural name.
                */
                for var elementTerm in self.classDefinitionsByCode.values {
                    if elementTerm.name == "" {
                        elementTerm = ClassTerm(name: elementTerm.pluralName, pluralName: elementTerm.pluralName, code: elementTerm.code, inheritsFromName: nil)
                    } else if elementTerm.pluralName == "" {
                        elementTerm = ClassTerm(name: elementTerm.name, pluralName: elementTerm.name, code: elementTerm.code, inheritsFromName: nil)
                    }
                    self.elements.append(elementTerm)
                    self.types.append(elementTerm)
                }
                self.classDefinitionsByCode.removeAll()
            } catch {
                throw SDEFError(message: "An error occurred while parsing AETE.", cause: error)
            }
        case _typeAEList:
            for i in 1..<(descriptor.numberOfItems+1) {
                try self.parse(descriptor.atIndex(i)!)
            }
        default:
            throw SDEFError(message: "An error occurred while parsing AETE. Unsupported descriptor type: \(formatFourCharCodeString(descriptor.descriptorType))")
        }
    }
    
    public func parse(_ descriptors: [NSAppleEventDescriptor]) throws {
        for descriptor in descriptors {
            try self.parse(descriptor)
        }
    }
    
    // internal callbacks
    
    // read data methods
    
    @inline(__always) private func short() -> UInt16 { // unsigned short (2 bytes)
        var value: UInt16 = 0
        self.aeteData.getBytes(&value, range: NSMakeRange(self.cursor,MemoryLayout<UInt16>.size))
        self.cursor += MemoryLayout<UInt16>.size
        return value
    }
    
    @inline(__always) private func code() -> OSType { // (4 bytes)
        var value: OSType = 0
        self.aeteData.getBytes(&value, range: NSMakeRange(self.cursor,MemoryLayout<OSType>.size))
        self.cursor += MemoryLayout<OSType>.size
        return value
    }
    
    @inline(__always) private func string() -> String {
        var length: UInt8 = 0 // Pascal string = 1-byte length (unsigned char) followed by 0-255 MacRoman chars
        self.aeteData.getBytes(&length, range: NSMakeRange(self.cursor,MemoryLayout<UInt8>.size))
        self.cursor += MemoryLayout<UInt8>.size
        let value = length == 0 ? "" : String(data: aeteData.subdata(with: NSMakeRange(self.cursor,Int(length))),
                                                encoding: .macOSRoman)!
        self.cursor += Int(length)
        return value
    }
    
    // skip unneeded aete data
    
    @inline(__always) private func skipShort() {
        self.cursor += MemoryLayout<UInt16>.size
    }
    @inline(__always) private func skipCode() {
        self.cursor += MemoryLayout<OSType>.size
    }
    @inline(__always) private func skipString() {
        var len: UInt8 = 0
        self.aeteData.getBytes(&len, range: NSMakeRange(self.cursor,MemoryLayout<UInt8>.size))
        self.cursor += MemoryLayout<UInt8>.size + Int(len)
    }
    @inline(__always) private func alignCursor() { // realign aete data cursor on even byte after reading strings
        if self.cursor % 2 != 0 {
            self.cursor += 1
        }
    }
    
    // perform a bounds check on aete data cursor to protect against malformed aete data
    
    @inline(__always) private func checkCursor() throws {
        if cursor > self.aeteData.length {
            throw SDEFError(message: "The AETE ended prematurely: \(self.aeteData.length) bytes expected, \(self.cursor) bytes read.")
        }
    }
    
    
    // Parse methods
    
    func parseCommand() throws {
        let name = self.string()
        self.skipString()   // description
        self.alignCursor()
        let classCode = self.code()
        let code = self.code()
        var commandDef = CommandTerm(name: name, eventClass: classCode, eventID: code)
        // skip result
        self.skipCode()     // datatype
        self.skipString()   // description
        self.alignCursor()
        self.skipShort()    // flags
        // skip direct parameter
        self.skipCode()     // datatype
        self.skipString()   // description
        self.alignCursor()
        self.skipShort()    // flags
        // parse keyword parameters
        /* Note: overlapping command definitions (e.g. InDesign) should be processed as follows:
        - If their names and codes are the same, only the last definition is used; other definitions are ignored and will not compile.
        - If their names are the same but their codes are different, only the first definition is used; other definitions are ignored and will not compile.
        - If a dictionary-defined command has the same name but different code to a built-in definition, escape its name so it doesn't conflict with the default built-in definition.
        */
        let otherCommandDef: CommandTerm! = self.commandsDict[name]
        if otherCommandDef == nil || (commandDef.eventClass == otherCommandDef.eventClass
            && commandDef.eventID == otherCommandDef.eventID) {
                self.commandsDict[name] = commandDef
        }
        let n = self.short()
        for _ in 0..<n {
            let paramName = self.string()
            self.alignCursor()
            let paramCode = self.code()
            self.skipCode()     // datatype
            self.skipString()   // description
            self.alignCursor()
            self.skipShort()    // flags
            commandDef.addParameter(paramName, code: paramCode)
            try self.checkCursor()
        }
    }
    
    
    func parseClass() throws {
        var isPlural = false
        let className = self.string()
        self.alignCursor()
        let classCode = self.code()
        self.skipString()   // description
        self.alignCursor()
        // properties
        let n = self.short()
        for _ in 0..<n {
            let propertyName = self.string()
            self.alignCursor()
            let propertyCode = self.code()
            self.skipCode()     // datatype
            self.skipString()   // description
            self.alignCursor()
            let flags = self.short()
            if propertyCode != _kAEInheritedProperties { // it's a normal property definition, not a superclass  definition
                let propertyDef = KeywordTerm(name: propertyName, code: propertyCode, kind: .property)
                if (flags % 2 != 0) { // class name is plural
                    isPlural = true
                } else if !properties.contains(propertyDef) { // add to list of property definitions
                    self.properties.append(propertyDef)
                }
            }
            try self.checkCursor()
        }
        // skip elements
        let n2 = self.short()
        for _ in 0..<n2 {
            self.skipCode()         // code
            let m = self.short()    // number of reference forms
            self.cursor += 4 * Int(m)
            try self.checkCursor()
        }
        // add either singular (class) or plural (element) name definition
        let elementDef: ClassTerm
        let oldDef = self.classDefinitionsByCode[classCode]
        if isPlural {
            elementDef = ClassTerm(name: oldDef?.name ?? "", pluralName: className, code: classCode, inheritsFromName: nil)
        } else {
            elementDef = ClassTerm(name: className, pluralName: oldDef?.pluralName ?? "", code: classCode, inheritsFromName: nil)
        }
        self.classDefinitionsByCode[classCode] = elementDef
    }
    
    func parseComparison() throws {  // comparison info isn't used
        self.skipString()   // name
        self.alignCursor()
        self.skipCode()     // code
        self.skipString()   // description
        self.alignCursor()
    }
    
    func parseEnumeration() throws {
        self.skipCode()         // code
        let n = self.short()
        // enumerators
        for _ in 0..<n {
            let name = self.string()
            self.alignCursor()
            let enumeratorDef = KeywordTerm(name: name, code: self.code(), kind: .enumerator)
            self.skipString()    // description
            self.alignCursor()
            if !self.enumerators.contains(enumeratorDef) {
                self.enumerators.append(enumeratorDef)
            }
            try self.checkCursor()
        }
    }
    
    func parseSuite() throws {
        self.skipString()   // name string
        self.skipString()   // description
        self.alignCursor()
        self.skipCode()     // code
        self.skipShort()    // level
        self.skipShort()    // version
        let n = self.short()
        for _ in 0..<n {
            try self.parseCommand()
            try self.checkCursor()
        }
        let n2 = self.short()
        for _ in 0..<n2 {
            try self.parseClass()
            try self.checkCursor()
        }
        let n3 = self.short()
        for _ in 0..<n3 {
            try self.parseComparison()
            try self.checkCursor()
        }
        let n4 = self.short()
        for _ in 0..<n4 {
            try self.parseEnumeration()
            try self.checkCursor()
        }
    }
}

extension RootSpecifier { // extends the built-in Application object with convenience method for getting its AETE resource
    
    public func getAETE() throws -> NSAppleEventDescriptor {
        return try self.sendAppleEvent(_kASAppleScriptSuite, _kGetAETE, [keyDirectObject: 0]) as NSAppleEventDescriptor
    }
    
}


//
//  Symbol.swift
//  SwiftAutomation
//
//
//  Represents typeType/typeEnumerated/typeProperty/typeKeyword descriptors. Static glues subclass this to add static vars representing each type/enum/property keyword defined by the application dictionary.
//
//  Also used to represent string-based record keys (where type=0 and name!=nil) when unpacking an AERecord's keyASUserRecordFields property, allowing the resulting dictionary to hold any mixture of terminology- (keyword) and user-defined (string) keys while typed as [Symbol:Any].
//

import Foundation

public struct Symbol: Hashable, Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable, AEEncodable {
    
    public let name: String?
    public let code: OSType
    public let type: OSType
    
    public var typeAliasName: String {
        return "AE"
    } // provides prefix used in description var; glue subclasses override this with their own strings (e.g. "FIN" for Finder)
    
    public init(name: String?, code: OSType, type: OSType = typeType) {
        self.name = name
        self.code = code
        self.type = type
    }
    
    // special constructor for string-based record keys (avoids the need to wrap dictionary keys in a `StringOrSymbol` enum when unpacking)
    // e.g. the AppleScript record `{name:"Bob", isMyUser:true}` maps to the Swift Dictionary `[Symbol.name:"Bob", Symbol("isMyUser"):true]`
    
    public init(_ name: String) {
        self.init(name: name, code: noOSType, type: noOSType)
    }
    
    // convenience constructors for creating Symbols using raw four-char codes
    
    public init(code: String, type: String = "type") {
        self.init(name: nil, code: UTGetOSTypeFromString(code as CFString), type: UTGetOSTypeFromString(type as CFString))
    }
    
    public init(code: OSType, type: OSType = typeType) {
        self.init(name: nil, code: code, type: type)
    }
    
    // this is called by AppData when unpacking typeType, typeEnumerated, etc; glue-defined symbol subclasses should override to return glue-defined symbols where available
    public static func symbol(code: OSType, type: OSType = typeType) -> Symbol {
        return self.init(name: nil, code: code, type: type)
    }
    
    // this is called by AppData when unpacking string-based record keys
    public static func symbol(string: String) -> Symbol {
        return self.init(name: string, code: noOSType, type: noOSType)
    }
    
    // display
    
    public var description: String {
        if let name = self.name {
            return self.nameOnly ? "\(self.typeAliasName)(\(name.debugDescription))" : "\(self.typeAliasName).\(name)"
        } else {
            return "\(self.typeAliasName)(code:\(formatFourCharCodeString(self.code)),type:\(formatFourCharCodeString(self.type)))"
        }
    }
    
    public var debugDescription: String { return self.description }
    
    public var customMirror: Mirror {
        let children: [Mirror.Child] = [(label: "description", value: self.description), (label: "name", value: self.name ?? ""),
                                        (label: "code", value: String(fourCharCode: self.code)), (label: "type", value: String(fourCharCode: self.type))]
        return Mirror(self, children: children, displayStyle: .`class`, ancestorRepresentation: .suppressed)
    }
    
    // packing
    
    public var descriptor: NSAppleEventDescriptor { // used by encodeAEDescriptor and previous()/next() selectors
        if self.nameOnly {
            return NSAppleEventDescriptor(string: self.name!)
        } else {
            return NSAppleEventDescriptor(type: self.type, code: self.code)
        }
    }
    
    // returns true if Symbol contains name but not code (i.e. it represents a string-based record property key)
    public var nameOnly: Bool { return self.type == noOSType && self.name != nil }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return self.descriptor
    }
    
    // equatable, hashable
    
    public func hash(into hasher: inout Hasher) {
        if self.nameOnly {
            hasher.combine(self.name!)
        } else {
            hasher.combine(self.code)
        }
    }
    
    public static func ==(lhs: Symbol, rhs: Symbol) -> Bool {
        // note: operands are not required to be the same subclass as this compares for AE equality only, e.g.:
        //
        //    TED.document == AESymbol(code: "docu") -> true
        //
        // note: AE types are also ignored on the [reasonable] assumption that any differences in descriptor type (e.g. typeType vs typeProperty) are irrelevant as apps will only care about the code itself
        return lhs.nameOnly && rhs.nameOnly ? lhs.name == rhs.name : lhs.code == rhs.code
    }
}





//
//  TermTypes.swift
//  SwiftAutomation
//
//

import Foundation

public class TerminologyError: AutomationError {
    public init(_ message: String, cause: Error? = nil) {
        super.init(code: errOSACorruptTerminology, message: message, cause: cause)
    }
}

public protocol ApplicationTerminology { // GlueTable.add() accepts any object that adopts this protocol (normally AETEParser/SDEFParser, but a dynamic bridge could also use this to reimport previously exported tables to which manual corrections have been made)
    var types: [KeywordTerm] {get}
    var enumerators: [KeywordTerm] {get}
    var properties: [KeywordTerm] {get}
    var elements: [ClassTerm] {get}
    var commands: [CommandTerm] {get}
}

// TO DO: get rid of Term classes; rename TermType enum to Term and attach names and codes to that

public enum TermType {
    case type
    case enumerator
    case property
    case command
    case parameter
}

public class Term { // base class for keyword and command definitions

    public var name: String // editable as GlueTable may need to escape names to disambiguate conflicting terms
    public let kind: TermType

    init(name: String, kind: TermType) {
        self.name = name
        self.kind = kind
    }
}

public class KeywordTerm: Term, Hashable, CustomStringConvertible { // type/enumerator/property/element/parameter name

    public let code: OSType
    
    public init(name: String, kind: TermType, code: OSType) {
        self.code = code
        super.init(name: name, kind: kind)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.code)
    }
    
    public var description: String { return "<\(type(of:self))=\(self.kind):\(self.name)=\(String(fourCharCode: self.code))>" }
    
    public static func ==(lhs: KeywordTerm, rhs: KeywordTerm) -> Bool {
        return lhs.kind == rhs.kind && lhs.code == rhs.code && lhs.name == rhs.name
    }
}

public class ClassTerm: KeywordTerm {
    
    public var singular: String
    public var plural: String
    
    public init(singular: String, plural: String, code: OSType) {
        self.singular = singular
        self.plural = plural
        super.init(name: self.singular, kind: .type, code: code)
    }
}

public class CommandTerm: Term, Hashable, CustomStringConvertible {

    public let eventClass: OSType
    public let eventID: OSType
    
    private(set) public var parameters: [KeywordTerm] = []

    public init(name: String, eventClass: OSType, eventID: OSType) {
        self.eventClass = eventClass
        self.eventID = eventID
        super.init(name: name, kind: .command)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.eventClass)
        hasher.combine(self.eventID)
    }
    
    public var description: String {
        let params = self.parameters.map({ "\($0.name)=\(String(fourCharCode: $0.code))" }).joined(separator: ",")
        return "<Command:\(self.name)=\(String(fourCharCode: self.eventClass))\(String(fourCharCode: self.eventID))(\(params))>"
    }
    
    func addParameter(_ name: String, code: OSType) {
        let paramDef = KeywordTerm(name: name, kind: .parameter, code: code)
        self.parameters.append(paramDef)
    }
    
    public static func ==(lhs: CommandTerm, rhs: CommandTerm) -> Bool {
        return lhs.eventClass == rhs.eventClass && lhs.eventID == rhs.eventID
            && lhs.name == rhs.name && lhs.parameters == rhs.parameters
    }
}

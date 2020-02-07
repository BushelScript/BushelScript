//
//  Symbol.swift
//  SwiftAutomation
//

// Ian's notes: SA's method of representing ae4 codes.

import Foundation

public struct Symbol {
    
    public let code: OSType
    public let type: OSType
    
    public init(code: OSType, type: OSType) {
        self.code = code
        self.type = type
    }
    
}

// MARK: AEEncodable
extension Symbol: AEEncodable {
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        encodeAEDescriptor()
    }
    
    public func encodeAEDescriptor() -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(type: type, code: code)
    }
    
}

// MARK: Hashable
extension Symbol: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
    
    public static func ==(lhs: Symbol, rhs: Symbol) -> Bool {
        // note: operands are not required to be the same subclass as this compares for AE equality only, e.g.:
        //
        //    TED.document == AESymbol(code: "docu") -> true
        //
        // note: AE types are also ignored on the [reasonable] assumption that any differences in descriptor type (e.g. typeType vs typeProperty) are irrelevant as apps will only care about the code itself
        lhs.code == rhs.code
    }
    
}

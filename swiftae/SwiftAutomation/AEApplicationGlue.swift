//
//  AEApplicationGlue.swift
//  built-in 
//  SwiftAutomation.framework 0.1.0
//  `aeglue -e 'Symbol+String' -e 'String+MissingValue' -D`
//

import Foundation

/******************************************************************************/
// Create an untargeted AppData instance for use in App, Con, Its roots,
// and in Application initializers to create targeted AppData instances.

public let untargetedAppData = AppData()

/******************************************************************************/
// Specifier extensions; these add command methods and property/elements getters based on built-in terminology

// Command->Any will be bound when return type can't be inferred, else Command->T

extension ObjectSpecifier { // provides AE dispatch methods
    @discardableResult public func get(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "get", eventClass: 0x636f7265, eventID: 0x67657464, // "core"/"getd"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func get<T>(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "get", eventClass: 0x636f7265, eventID: 0x67657464, // "core"/"getd"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
}

/******************************************************************************/
// Specifier subclasses add app-specific extensions

// App/Con/Its root objects used to construct untargeted specifiers; these can be used to construct specifiers for use in commands, though cannot send commands themselves

public let AEApp = untargetedAppData.application
public let AECon = untargetedAppData.container
public let AEIts = untargetedAppData.specimen

/******************************************************************************/
// Static types

public typealias AERecord = [Symbol:Any] // default Swift type for AERecordDescs

public enum AESymbolOrString: AECodable {
    case symbol(Symbol)
    case string(String)
    
    public init(_ value: Symbol) { self = .symbol(value) }
    public init(_ value: String) { self = .string(value) }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        switch self {
        case .symbol(let value): return try appData.pack(value)
        case .string(let value): return try appData.pack(value)
        }
    }
    public init(from descriptor: NSAppleEventDescriptor, appData: AppData) throws {
        do { self = .symbol(try appData.unpack(descriptor) as Symbol) } catch {}
        do { self = .string(try appData.unpack(descriptor) as String) } catch {}
        throw UnpackError(appData: appData, descriptor: descriptor, type: AESymbolOrString.self,
                          message: "Can't coerce descriptor to Swift type: \(AESymbolOrString.self)")
    }
    public static func SwiftAutomation_noValue() throws -> AESymbolOrString { throw AutomationError(code: -1708) }
}

public enum AEStringOrMissingValue: AECodable {
    case missing(MissingValueType)
    case string(String)
    
    public init(_ value: MissingValueType) { self = .missing(value) }
    public init(_ value: String) { self = .string(value) }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        switch self {
        case .missing(let value): return try appData.pack(value)
        case .string(let value): return try appData.pack(value)
        }
    }
    public init(from descriptor: NSAppleEventDescriptor, appData: AppData) throws {
        do { self = .missing(try appData.unpack(descriptor) as MissingValueType) } catch {}
        do { self = .string(try appData.unpack(descriptor) as String) } catch {}
        throw UnpackError(appData: appData, descriptor: descriptor, type: AEStringOrMissingValue.self,
                          message: "Can't coerce descriptor to Swift type: \(AEStringOrMissingValue.self)")
    }
    public static func SwiftAutomation_noValue() throws -> AEStringOrMissingValue { return .missing(MissingValue) }
}

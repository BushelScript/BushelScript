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

private let specifierFormatter = SpecifierFormatter(applicationClassName: "AEApplication",
                                                     classNamePrefix: "AE",
                                                     typeNames: [:],
                                                     propertyNames: [:],
                                                     elementsNames: [:])

public let untargetedAppData = AppData(formatter: specifierFormatter)

/******************************************************************************/
// Specifier extensions; these add command methods and property/elements getters based on built-in terminology

// Command->Any will be bound when return type can't be inferred, else Command->T

extension ObjectSpecifier { // provides AE dispatch methods
    @discardableResult public func activate(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "activate", eventClass: 0x6d697363, eventID: 0x61637476, // "misc"/"actv"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func activate<T>(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "activate", eventClass: 0x6d697363, eventID: 0x61637476, // "misc"/"actv"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
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
    @discardableResult public func open(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "open", eventClass: 0x61657674, eventID: 0x6f646f63, // "aevt"/"odoc"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func open<T>(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "open", eventClass: 0x61657674, eventID: 0x6f646f63, // "aevt"/"odoc"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    @discardableResult public func openLocation(_ directParameter: Any = NoParameter,
            window: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "openLocation", eventClass: 0x4755524c, eventID: 0x4755524c, // "GURL"/"GURL"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                    ("window", 0x57494e44, window), // "WIND"
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func openLocation<T>(_ directParameter: Any = NoParameter,
            window: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "openLocation", eventClass: 0x4755524c, eventID: 0x4755524c, // "GURL"/"GURL"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                    ("window", 0x57494e44, window), // "WIND"
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    @discardableResult public func print(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "print", eventClass: 0x61657674, eventID: 0x70646f63, // "aevt"/"pdoc"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func print<T>(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "print", eventClass: 0x61657674, eventID: 0x70646f63, // "aevt"/"pdoc"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    @discardableResult public func quit(_ directParameter: Any = NoParameter,
            saving: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "quit", eventClass: 0x61657674, eventID: 0x71756974, // "aevt"/"quit"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                    ("saving", 0x7361766f, saving), // "savo"
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func quit<T>(_ directParameter: Any = NoParameter,
            saving: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "quit", eventClass: 0x61657674, eventID: 0x71756974, // "aevt"/"quit"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                    ("saving", 0x7361766f, saving), // "savo"
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    @discardableResult public func reopen(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "reopen", eventClass: 0x61657674, eventID: 0x72617070, // "aevt"/"rapp"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func reopen<T>(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "reopen", eventClass: 0x61657674, eventID: 0x72617070, // "aevt"/"rapp"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    @discardableResult public func run(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "run", eventClass: 0x61657674, eventID: 0x6f617070, // "aevt"/"oapp"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func run<T>(_ directParameter: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "run", eventClass: 0x61657674, eventID: 0x6f617070, // "aevt"/"oapp"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    @discardableResult public func set(_ directParameter: Any = NoParameter,
            to: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try self.appData.sendAppleEvent(name: "set", eventClass: 0x636f7265, eventID: 0x73657464, // "core"/"setd"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                    ("to", 0x64617461, to), // "data"
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
    public func set<T>(_ directParameter: Any = NoParameter,
            to: Any = NoParameter,
            requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
            withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try self.appData.sendAppleEvent(name: "set", eventClass: 0x636f7265, eventID: 0x73657464, // "core"/"setd"
                parentSpecifier: self, directParameter: directParameter, keywordParameters: [
                    ("to", 0x64617461, to), // "data"
                ], requestedType: requestedType, waitReply: waitReply, sendOptions: sendOptions,
                withTimeout: withTimeout, considering: considering)
    }
}

extension ObjectSpecifier { // provides vars and methods for constructing specifiers
    
    // Properties
    public var class_: AEItem {return self.property(0x70636c73) as! AEItem} // "pcls"
    public var id: AEItem {return self.property(0x49442020) as! AEItem} // "ID\0x20\0x20"
    public var properties: AEItem {return self.property(0x70414c4c) as! AEItem} // "pALL"

    // Elements
    public var items: AEItems {return self.elements(0x636f626a) as! AEItems} // "cobj"
    
}

/******************************************************************************/
// Specifier subclasses add app-specific extensions

// beginning/end/before/after
public class AEInsertion: InsertionSpecifier {}

// property/by-index/by-name/by-id/previous/next/first/middle/last/any
public class AEItem: ObjectSpecifier {
}

// by-range/by-test/all
public class AEItems: AEItem, MultipleObjectSpecifier {}

// App/Con/Its root objects used to construct untargeted specifiers; these can be used to construct specifiers for use in commands, though cannot send commands themselves

public let AEApp = untargetedAppData.app
public let AECon = untargetedAppData.con
public let AEIts = untargetedAppData.its


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

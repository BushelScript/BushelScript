//
//  SpecifierExtensions.swift
//  SwiftAutomation
//
//  Extensions that add the standard selector vars/methods to each glue's custom Specifier classes.
//  These allow specifiers to be built up via chained calls, e.g.:
//
//     paragraphs 1 thru -2 of text of document "README" of it
//
//     AEApp.elements(cDocument)["README"].property(cText).elements(cParagraph)[1,-2]
//
//

import Foundation

/******************************************************************************/
// Property/single-element specifier; identifies an attribute/describes a one-to-one relationship between nodes in the app's AEOM graph

public extension ObjectSpecifierProtocol {

    func userProperty(_ name: String) -> ObjectSpecifier {
        return AEItem(wantType: _typePropertyDesc, selectorForm: _formUserPropertyDesc, selectorData: NSAppleEventDescriptor(string: name), parentQuery: self, appData: self.appData)
    }

    func property(_ code: OSType) -> ObjectSpecifier {
		return AEItem(wantType: _typePropertyDesc, selectorForm: _formPropertyDesc, selectorData: NSAppleEventDescriptor(typeCode: code), parentQuery: self, appData: self.appData)
    }
    
    func property(_ code: String) -> ObjectSpecifier {
        let data: Any
        do {
            data = NSAppleEventDescriptor(typeCode: try FourCharCode(fourByteString: code))
        } catch {
            data = error
        }
        return AEItem(wantType: _typePropertyDesc, selectorForm: _formPropertyDesc, selectorData: data, parentQuery: self, appData: self.appData)
    }
    
    func elements(_ code: OSType) -> MultipleObjectSpecifier {
        return AEItems(wantType: NSAppleEventDescriptor(typeCode: code), selectorForm: _formAbsolutePositionDesc, selectorData: _kAEAllDesc, parentQuery: self, appData: self.appData)
    }
    
    func elements(_ code: String) -> MultipleObjectSpecifier {
        let want: NSAppleEventDescriptor, data: Any
        do {
            want = NSAppleEventDescriptor(typeCode: try FourCharCode(fourByteString: code))
            data = _kAEAllDesc
        } catch {
            want = NSAppleEventDescriptor.null()
            data = error
        } 
        return AEItems(wantType: want, selectorForm: _formAbsolutePositionDesc, selectorData: data, parentQuery: self, appData: self.appData)
    }
    
    // relative position selectors
    func previous(_ elementClass: Symbol? = nil) -> ObjectSpecifier {
        return AEItem(wantType: elementClass == nil ? self.wantType : elementClass!.descriptor,
                                        selectorForm: _formRelativePositionDesc, selectorData: _kAEPreviousDesc,
                                        parentQuery: self, appData: self.appData)
    }
    
    func next(_ elementClass: Symbol? = nil) -> ObjectSpecifier {
        return AEItem(wantType: elementClass == nil ? self.wantType : elementClass!.descriptor,
                                        selectorForm: _formRelativePositionDesc, selectorData: _kAENextDesc,
                                        parentQuery: self, appData: self.appData)
    }
    
    // insertion specifiers
    var beginning: InsertionSpecifier {
        return AEInsertion(insertionLocation: _kAEBeginningDesc, parentQuery: self, appData: self.appData)
    }
    var end: InsertionSpecifier {
        return AEInsertion(insertionLocation: _kAEEndDesc, parentQuery: self, appData: self.appData)
    }
    var before: InsertionSpecifier {
        return AEInsertion(insertionLocation: _kAEBeforeDesc, parentQuery: self, appData: self.appData)
    }
    var after: InsertionSpecifier {
        return AEInsertion(insertionLocation: _kAEAfterDesc, parentQuery: self, appData: self.appData)
    }
    
    var all: MultipleObjectSpecifier { // equivalent to `every REFERENCE`; applied to a property specifier, converts it to all-elements (this may be necessary when property and element names are identical, in which case [with exception of `text`] a property specifier is constructed by default); applied to an all-elements specifier, returns it as-is; applying it to any other reference form will throw an error when used
        if self.selectorForm.typeCodeValue == _formPropertyID {
            return AEItems(wantType: self.selectorData as! NSAppleEventDescriptor, selectorForm: _formAbsolutePositionDesc, selectorData: _kAEAllDesc, parentQuery: self.parentQuery, appData: self.appData)
        } else if self.selectorForm.typeCodeValue == _formAbsolutePosition
                && (self.selectorData as? NSAppleEventDescriptor)?.enumCodeValue == _kAEAll,
                let specifier = self as? MultipleObjectSpecifier {
            return specifier
        } else {
            let error = AutomationError(code: 1, message: "Invalid specifier: \(self).all")
            return AEItems(wantType: self.wantType, selectorForm: _formAbsolutePositionDesc, selectorData: error, parentQuery: self.parentQuery, appData: self.appData)
        }
    }
}

/******************************************************************************/
// Multi-element specifier; represents a one-to-many relationship between nodes in the app's AEOM graph

public protocol MultipleObjectSpecifier: ObjectSpecifier {}

extension MultipleObjectSpecifier {

    // Note: calling an element[s] selector on an all-elements specifier effectively replaces its original gAll selector data with the new selector data, instead of extending the specifier chain. This ensures that applying any selector to `elements[all]` produces `elements[selector]` (effectively replacing the existing selector), while applying a second selector to `elements[selector]` produces `elements[selector][selector2]` (appending the second selection to the first) as normal; e.g. `first document whose modified is true` would be written as `documents[Its.modified==true].first`.
    var baseQuery: Query {
        if let desc = self.selectorData as? NSAppleEventDescriptor,
                desc.descriptorType == _typeAbsoluteOrdinal && desc.enumCodeValue == _kAEAll {
            return self.parentQuery
        } else {
            return self
        }
    }
    
    // by-index, by-name, by-test
    public subscript(index: Any) -> ObjectSpecifier {
        var form: NSAppleEventDescriptor
        switch (index) {
        case is TestClause:
            return self[index as! TestClause]
        case is String:
            form = _formNameDesc
        default:
            form = _formAbsolutePositionDesc
        }
        return AEItem(wantType: self.wantType, selectorForm: form, selectorData: index, parentQuery: self.baseQuery, appData: self.appData)
    }

    public subscript(test: TestClause) -> MultipleObjectSpecifier {
        return AEItems(wantType: self.wantType, selectorForm: _formTestDesc, selectorData: test, parentQuery: self.baseQuery, appData: self.appData)
    }
    
    // by-name, by-id, by-range
    public func named(_ name: Any) -> ObjectSpecifier { // use this if name is not a String, else use subscript // TO DO: trying to think of a use case where this has ever been found necessary; DELETE? (see also TODOs on whether or not to add an explicit `all` selector property)
        return AEItem(wantType: self.wantType, selectorForm: _formNameDesc, selectorData: name, parentQuery: self.baseQuery, appData: self.appData)
    }
    public func id(_ id: Any) -> ObjectSpecifier {
        return AEItem(wantType: self.wantType, selectorForm: _formUniqueIDDesc, selectorData: id, parentQuery: self.baseQuery, appData: self.appData)
    }
    public subscript(from: Any, to: Any) -> MultipleObjectSpecifier {
        // caution: by-range specifiers must be constructed as `elements[from,to]`, NOT `elements[from...to]`, as `Range<T>` types are not supported
        // Note that while the `x...y` form _could_ be supported (via the SelfPacking protocol, since Ranges are generics), the `x..<y` form is problematic as it doesn't have a direct analog in Apple events (which are always inclusive of both start and end points). Automatically mapping `x..<y` to `x...y.previous()` is liable to cause its own set of problems, e.g. some apps may fail to resolve this more complex query correctly/at all), and it's hard to justify the additional complexity of having two different ways of constructing ranges, one of which brings various caveats and limitations, and the more complicated user documentation that will inevitably require.
        // Another concern is that supporting 'standard' Range syntax will further encourage users to lapse into using Swift-style zero-indexing (e.g. `0..<3`) instead of the correct Apple event one-indexing (`1 thru 3`) – it'll be hard enough keeping them right when using the single-element by-index syntax (where `elements[0]` is a common user error, and - worse - one that CocoaScripting intentionally indulges instead of reporting as an error, so that both `elements[0]` and `elements[1]` actually refer to the _same_ element, not consecutive elements as expected).
        return AEItems(wantType: self.wantType, selectorForm: _formRangeDesc, selectorData: RangeSelector(start: from, stop: to, wantType: self.wantType), parentQuery: self.baseQuery, appData: self.appData)
    }
    
    // by-ordinal
    public var first: ObjectSpecifier {
        return AEItem(wantType: self.wantType, selectorForm: _formAbsolutePositionDesc, selectorData: _kAEFirstDesc, parentQuery: self.baseQuery, appData: self.appData)
    }
    public var middle: ObjectSpecifier {
        return AEItem(wantType: self.wantType, selectorForm: _formAbsolutePositionDesc, selectorData: _kAEMiddleDesc, parentQuery: self.baseQuery, appData: self.appData)
    }
    public var last: ObjectSpecifier {
        return AEItem(wantType: self.wantType, selectorForm: _formAbsolutePositionDesc, selectorData: _kAELastDesc, parentQuery: self.baseQuery, appData: self.appData)
    }
    public var any: ObjectSpecifier {
        return AEItem(wantType: self.wantType, selectorForm: _formAbsolutePositionDesc, selectorData: _kAEAnyDesc, parentQuery: self.baseQuery, appData: self.appData)
    }
}

extension RootSpecifier { // Was protocol Application
    
    // note: users may access Application.appData.target directly for troubleshooting purposes, but are strongly discouraged from using it directly (it is public so that generated glues can use it, but should otherwise be treated as an internal implementation detail)
    
    // Application object constructors
    
    private convenience init(target: TargetApplication, launchOptions: LaunchOptions, relaunchMode: RelaunchMode) {
        let appData = untargetedAppData.targetedCopy(target, launchOptions: launchOptions, relaunchMode: relaunchMode)
        self.init(rootObject: AppRootDesc, appData: appData)
    }
    
    public convenience init(name: String, launchOptions: LaunchOptions = DefaultLaunchOptions, relaunchMode: RelaunchMode = DefaultRelaunchMode) {
        self.init(target: .name(name), launchOptions: launchOptions, relaunchMode: relaunchMode)
    }
    
    public convenience init(url: URL, launchOptions: LaunchOptions = DefaultLaunchOptions, relaunchMode: RelaunchMode = DefaultRelaunchMode) {
        self.init(target: .url(url), launchOptions: launchOptions, relaunchMode: relaunchMode)
    }
    
    public convenience init(bundleIdentifier: String, launchOptions: LaunchOptions = DefaultLaunchOptions, relaunchMode: RelaunchMode = DefaultRelaunchMode) {
        self.init(target: .bundleIdentifier(bundleIdentifier, false), launchOptions: launchOptions, relaunchMode: relaunchMode)
    }
    
    public convenience init(processIdentifier: pid_t, launchOptions: LaunchOptions = DefaultLaunchOptions, relaunchMode: RelaunchMode = DefaultRelaunchMode) {
        self.init(target: .processIdentifier(processIdentifier), launchOptions: launchOptions, relaunchMode: relaunchMode)
    }
    
    public convenience init(addressDescriptor: NSAppleEventDescriptor, launchOptions: LaunchOptions = DefaultLaunchOptions, relaunchMode: RelaunchMode = DefaultRelaunchMode) {
        self.init(target: .Descriptor(addressDescriptor), launchOptions: launchOptions, relaunchMode: relaunchMode)
    }
    
    public static func currentApplication() -> RootSpecifier {
        let appData = untargetedAppData.targetedCopy(.current, launchOptions: DefaultLaunchOptions, relaunchMode: DefaultRelaunchMode)
        return RootSpecifier(rootObject: AppRootDesc, appData: appData)
    }
    
    public func customRoot(_ object: Any) -> RootSpecifier {
        return RootSpecifier(rootObject: object, appData: self.appData)
    }
    
    // launch this application (equivalent to AppleScript's `launch` command)
    
    public func launch() throws {
        try self.appData.target.launch()
    }
    
    // is the target application currently running?
    
    public var isRunning: Bool {
        return self.appData.target.isRunning
    }
    
    // transaction support
    
    public func doTransaction<T>(session: Any? = nil, closure: () throws -> (T)) throws -> T {
        return try self.appData.doTransaction(session: session, closure: closure)
    }
}



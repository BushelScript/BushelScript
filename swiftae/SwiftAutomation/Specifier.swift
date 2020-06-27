//
//  Specifier.swift
//  SwiftAutomation
//
//  Base classes for constructing AE queries.
//
//  Notes:
//
//  An AE query is represented as a linked list of AEDescs, primarily AERecordDescs of typeObjectSpecifier. Each object specifier record has four properties:
//
//      'want' -- the type of element to identify (or 'prop' when identifying a property)
//      'form', 'seld' -- the reference form and selector data identifying the element(s) or property
//      'from' -- the parent descriptor in the linked list
//
//    For example:
//
//      name of document "ReadMe" [of application "TextEdit"]
//
//    is represented by the following chain of AEDescs:
//
//      {want:'prop', form:'prop', seld:'pnam', from:{want:'docu', form:'name', seld:"ReadMe", from:null}}
//
//    Additional AERecord types (typeInsertionLocation, typeRangeDescriptor, typeCompDescriptor, typeLogicalDescriptor) are also used to construct specialized query forms describing insertion points before/after existing elements, element ranges, and test clauses.
//
//    Atomic AEDescs of typeNull, typeCurrentContainer, and typeObjectBeingExamined are used to terminate the linked list.
//
//
//  [TO DO: developer notes on Apple event query forms and Apple Event Object Model's relational object graphs (objects with attributes, one-to-one relationships, and one-to-many relationships); aka "AE IPC is simple first-class relational queries, not OOP"]
//
//
//  Specifier.swift defines the base classes from which concrete Specifier classes representing each major query form are constructed. These base classes combine with various SpecifierExtensions (which provide by-index, by-name, etc selectors and Application object constructors) and glue-defined Query and Command extensions (which provide property and all-elements selectors, and commands) to form the following concrete classes:
//
//    CLASS                 DESCRIPTION                         CAN CONSTRUCT
//
//    Query                 [base class]
//     ├─PREFIXInsertion    insertion location specifier        ├─commands
//     └─PREFIXObject       [object specifier base protocol]    └─commands, and property and all-elements specifiers
//        ├─PREFIXItem         single-object specifier             ├─previous/next selectors
//        │  └─PREFIXItems     multi-object specifier              │  └─by-index/name/id/ordinal/range/test selectors
//        └─PREFIXRoot         App/Con/Its (untargeted roots)      ├─[1]
//           └─APPLICATION     Application (app-targeted root)     └─initializers
//
//
//    (The above diagram fudges the exact inheritance hierarchy for illustrative purposes. Commands are actually provided by a PREFIXCommand protocol [not shown], which is adopted by APPLICATION and all PREFIX classes except PREFIXRoot [1] - which cannot construct working commands as it has no target information, so omits these methods for clarity. Strictly speaking, the only class which should implement commands is APPLICATION, as Apple event IPC is based on Remote *Procedure* Calls, not OOP; however, they also appear on specifier classes as a convenient shorthand when writing commands whose direct parameter is a specifier. Note that while all specifier classes provide command methods [including those used to construct relative-specifiers in by-range and by-test clauses, as omitting commands from these is more trouble than its worth] they will automatically throw if their root is an untargeted App/Con/Its object.)
//
//    The following classes are also defined for use with Its-based object specifiers in by-test selectors.
//
//    Query
//     └─TestClause         [test clause base class]
//        ├─ComparisonTest     comparison/containment test
//        └─LogicalTest        Boolean logic test
//
//
//    Except for APPLICATION, users do not instantiate any of these classes directly, but instead by chained property/method calls on existing Query instances.
//

import Foundation
import AppKit

/******************************************************************************/
// Common protocol for all specifier and test clause types.

public protocol Query: CustomStringConvertible, AEEncodable {
    
    var rootSpecifier: RootSpecifier { get }

    var appData: AppData { get set }
    
}

extension Query {
    
    public var description: String {
        formatSAObject(self)
    }
    
}

/******************************************************************************/
// Abstract base class for all object and insertion specifiers

// An object specifier is constructed as a linked list of AERecords of typeObjectSpecifier, terminated by a root descriptor (e.g. a null descriptor represents the root node of the app's Apple event object graph). The topmost node may also be an insertion location specifier, represented by an AERecord of typeInsertionLoc. The abstract Specifier class implements functionality common to both object and insertion specifiers.

public class Specifier: Query {
    
    public var appData: AppData
    
    public init(appData: AppData) {
        self.appData = appData
    }
    
    public var rootSpecifier: RootSpecifier {
        return parentQuery.rootSpecifier
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        fatalError()
    }
    
}

public protocol ChildQuery: Query {
    
    // note that parentQuery and rootSpecifier properties are really only intended for internal use when traversing a specifier chain; while there is nothing to prevent client code using these properties the results are not guaranteed to be valid or usable queries (once constructed, object specifiers should be treated as opaque values); the proper way to identify an object's (or objects') container is to ask the application to return a specifier (or list of specifiers) to its `container` property, if it has one, e.g. `let parentFolder:FinItem = someFinderItem.container.get()`
    
    // return the next ObjectSpecifier/TestClause in query chain
    var parentQuery: Query { get }
    
}

extension ChildQuery {
    
    public var parentQuery: Query {
        fatalError("ChildQuery.parentQuery must be overridden by subclasses.")
    }
    
    public var rootSpecifier: RootSpecifier {
        fatalError("ChildQuery.rootSpecifier must be overridden by subclasses.")
    }
    
}

extension Specifier: ChildQuery {

    // convenience methods for sending Apple events using four-char codes (either OSTypes or Strings)

    public func sendAppleEvent<T>(_ eventClass: OSType, _ eventID: OSType, _ parameters: [OSType: Any] = [:],
                                  requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
                                  withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> T {
        return try appData.sendAppleEvent(eventClass: eventClass, eventID: eventID,
                                          parentSpecifier: self, parameters: parameters,
                                          requestedType: requestedType, waitReply: waitReply,
                                          sendOptions: sendOptions, withTimeout: withTimeout, considering: considering)
    }

    // non-generic version of the above method; bound when T can't be inferred (either because caller doesn't use the return value or didn't declare a specific type for it, e.g. `let result = cmd.call()`), in which case Any is used

    @discardableResult public func sendAppleEvent(_ eventClass: OSType, _ eventID: OSType, _ parameters: [OSType: Any] = [:],
                                                  requestedType: Symbol? = nil, waitReply: Bool = true, sendOptions: SendOptions? = nil,
                                                  withTimeout: TimeInterval? = nil, considering: ConsideringOptions? = nil) throws -> Any {
        return try appData.sendAppleEvent(eventClass: eventClass, eventID: eventID,
                                          parentSpecifier: self, parameters: parameters,
                                          requestedType: requestedType, waitReply: waitReply,
                                          sendOptions: sendOptions, withTimeout: withTimeout, considering: considering)
    }
    
}

/******************************************************************************/
// Insertion location specifier

public class InsertionSpecifier: Specifier {

    // 'insl'
    public let insertionLocation: NSAppleEventDescriptor

    private(set) public var parentQuery: Query

    public required init(insertionLocation: NSAppleEventDescriptor,
                         parentQuery: Query, appData: AppData) {
        self.insertionLocation = insertionLocation
        self.parentQuery = parentQuery
        super.init(appData: appData)
    }
    
    func encodeAEDescriptor() throws -> NSAppleEventDescriptor {
        let desc = NSAppleEventDescriptor.record().coerce(toDescriptorType: typeInsertionLoc)!
        desc.setDescriptor(try parentQuery.encodeAEDescriptor(appData), forKeyword: keyAEObject)
        desc.setDescriptor(insertionLocation, forKeyword: keyAEPosition)
        return desc
    }
}

/******************************************************************************/
// Property/single-element specifiers; identifies an attribute/describes a one-to-one relationship between nodes in the app's AEOM graph

public protocol ObjectSpecifierProtocol: ChildQuery {
    
    var wantType: NSAppleEventDescriptor { get }
    var selectorForm: NSAppleEventDescriptor { get }
    var selectorData: Any { get }
    var parentQuery: Query { get }
    
}

// Represents property or single element specifier; adds property+elements vars, relative selectors, insertion specifiers
public class ObjectSpecifier: Specifier, ObjectSpecifierProtocol {

    // 'want', 'form', 'seld'
    public let wantType: NSAppleEventDescriptor
    public let selectorForm: NSAppleEventDescriptor
    public let selectorData: Any
    
    private(set) public var parentQuery: Query

    public required init(wantType: NSAppleEventDescriptor, selectorForm: NSAppleEventDescriptor, selectorData: Any,
                         parentQuery: Query, appData: AppData) {
        self.wantType = wantType
        self.selectorForm = selectorForm
        self.selectorData = selectorData
        self.parentQuery = parentQuery
        super.init(appData: appData)
    }

    public override func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        let desc = NSAppleEventDescriptor.record().coerce(toDescriptorType: typeObjectSpecifier)!
        desc.setDescriptor(try parentQuery.encodeAEDescriptor(appData), forKeyword: _keyAEContainer)
        desc.setDescriptor(wantType, forKeyword: _keyAEDesiredClass)
        desc.setDescriptor(selectorForm, forKeyword: _keyAEKeyForm)
        desc.setDescriptor(try appData.pack(selectorData), forKeyword: _keyAEKeyData)
        return desc
    }

    // Containment test constructors

    // note: ideally the following would only appear on objects constructed from an Its root; however, this would complicate the implementation while failing to provide any real benefit to users, who are unlikely to make such a mistake in the first place

    public func beginsWith(_ value: Any) -> TestClause {
        return ComparisonTest(operatorType: _kAEBeginsWithDesc, operand1: self, operand2: value, appData: appData)
    }

    public func endsWith(_ value: Any) -> TestClause {
        return ComparisonTest(operatorType: _kAEEndsWithDesc, operand1: self, operand2: value, appData: appData)
    }

    public func contains(_ value: Any) -> TestClause {
        return ComparisonTest(operatorType: _kAEContainsDesc, operand1: self, operand2: value, appData: appData)
    }

    public func isIn(_ value: Any) -> TestClause {
        return ComparisonTest(operatorType: _kAEIsInDesc, operand1: self, operand2: value, appData: appData)
    }
    
}

// Comparison test constructors

public func <(lhs: ObjectSpecifier, rhs: Any) -> TestClause {
    return ComparisonTest(operatorType: _kAELessThanDesc, operand1: lhs, operand2: rhs, appData: lhs.appData)
}

public func <=(lhs: ObjectSpecifier, rhs: Any) -> TestClause {
    return ComparisonTest(operatorType: _kAELessThanEqualsDesc, operand1: lhs, operand2: rhs, appData: lhs.appData)
}

public func ==(lhs: ObjectSpecifier, rhs: Any) -> TestClause {
    return ComparisonTest(operatorType: _kAEEqualsDesc, operand1: lhs, operand2: rhs, appData: lhs.appData)
}

public func !=(lhs: ObjectSpecifier, rhs: Any) -> TestClause {
    return ComparisonTest(operatorType: _kAENotEqualsDesc, operand1: lhs, operand2: rhs, appData: lhs.appData)
}

public func >(lhs: ObjectSpecifier, rhs: Any) -> TestClause {
    return ComparisonTest(operatorType: _kAEGreaterThanDesc, operand1: lhs, operand2: rhs, appData: lhs.appData)
}

public func >=(lhs: ObjectSpecifier, rhs: Any) -> TestClause {
    return ComparisonTest(operatorType: _kAEGreaterThanEqualsDesc, operand1: lhs, operand2: rhs, appData: lhs.appData)
}

/******************************************************************************/
// Multi-element specifiers; represents a one-to-many relationship between nodes in the app's AEOM graph

// note: each glue should define an Elements class that subclasses ObjectSpecifier and adopts MultipleObjectSpecifier (which adds by range/test/all selectors)

// note: by-range selector doesn't confirm APP/CON-based roots for start+stop specifiers; as with ITS-based roots this would add significant complexity to class hierarchy in order to detect mistakes that are unlikely to be made in practice (most errors are likely to be made further down the chain, e.g. getting the 'containment' hierarchy for more complex specifiers incorrect)

public struct RangeSelector: AEEncodable { // holds data for by-range selectors
    // Start and stop are Con-based (i.e. relative to container) specifiers (App-based specifiers will also work, as
    // long as they have the same parent specifier as the by-range specifier itself). For convenience, users can also
    // pass non-specifier values (typically Strings and Ints) to represent simple by-name and by-index specifiers of
    // the same element class; these will be converted to specifiers automatically when packed.
    public let start: Any
    public let stop: Any
    public let wantType: NSAppleEventDescriptor

    public init(start: Any, stop: Any, wantType: NSAppleEventDescriptor) {
        self.start = start
        self.stop = stop
        self.wantType = wantType
    }

    private func packSelector(_ selectorData: Any, appData: AppData) throws -> NSAppleEventDescriptor {
        var selectorForm: NSAppleEventDescriptor
        switch selectorData {
        case is NSAppleEventDescriptor:
            return selectorData as! NSAppleEventDescriptor
        case is Specifier: // technically, only ObjectSpecifier makes sense here, tho AS prob. doesn't prevent insertion loc or multi-element specifier being passed instead
            return try (selectorData as! Specifier).encodeAEDescriptor(appData)
        default: // pack anything else as a by-name or by-index specifier
            selectorForm = selectorData is String ? _formNameDesc : _formAbsolutePositionDesc
            let desc = NSAppleEventDescriptor.record().coerce(toDescriptorType: _typeObjectSpecifier)!
            desc.setDescriptor(ConRootDesc, forKeyword: _keyAEContainer)
            desc.setDescriptor(wantType, forKeyword: _keyAEDesiredClass)
            desc.setDescriptor(selectorForm, forKeyword: _keyAEKeyForm)
            desc.setDescriptor(try appData.pack(selectorData), forKeyword: _keyAEKeyData)
            return desc
        }
    }

    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        // note: the returned desc will be cached by the MultipleObjectSpecifier, so no need to cache it here
        let desc = NSAppleEventDescriptor.record().coerce(toDescriptorType: _typeRangeDescriptor)!
        desc.setDescriptor(try packSelector(start, appData: appData), forKeyword: _keyAERangeStart)
        desc.setDescriptor(try packSelector(stop, appData: appData), forKeyword: _keyAERangeStop)
        return desc
    }
}

/******************************************************************************/
// Test clause; used in by-test specifiers

// note: glues don't define their own TestClause subclasses as tests don't implement any app-specific vars/methods, only the logical operators defined below, and there's little point doing so for static typechecking purposes as any values not handled by MultipleObjectSpecifier's subscript(test:TestClause) are accepted by its subscript(index:Any), so still wouldn't be caught at runtime (OTOH, it'd be worth considering should subscript(test:) need to be replaced with a separate byTest() method for any reason)

// note: only TestClauses constructed from Its roots are actually valid; however, enfording this at compile-time would require a more complex class/protocol structure, while checking this at runtime would require calling Query.rootSpecifier.rootObject and checking object is 'its' descriptor. As it's highly unlikely users will use an App or Con root by accident, we'll live recklessly and let the gods of AppleScript punish any user foolish enough to do so.

public protocol TestClause: Query {
}

// Logical test constructors

public func &&(lhs: TestClause, rhs: TestClause) -> TestClause {
    return LogicalTest(operatorType: _kAEANDDesc, operands: [lhs, rhs], appData: lhs.appData)
}

public func ||(lhs: TestClause, rhs: TestClause) -> TestClause {
    return LogicalTest(operatorType: _kAEORDesc, operands: [lhs, rhs], appData: lhs.appData)
}

public prefix func !(lhs: TestClause) -> TestClause {
    return LogicalTest(operatorType: _kAENOTDesc, operands: [lhs], appData: lhs.appData)
}

public class ComparisonTest: TestClause {
    
    public var appData: AppData
    
    public let operatorType: NSAppleEventDescriptor, operand1: ObjectSpecifier, operand2: Any
    
    init(operatorType: NSAppleEventDescriptor,
         operand1: ObjectSpecifier, operand2: Any, appData: AppData) {
        self.operatorType = operatorType
        self.operand1 = operand1
        self.operand2 = operand2
        self.appData = appData
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        if operatorType === _kAENotEqualsDesc { // AEM doesn't support a 'kAENotEqual' enum...
            return try (!(operand1 == operand2)).encodeAEDescriptor(appData) // so convert to kAEEquals+kAENOT
        } else {
            let desc = NSAppleEventDescriptor.record().coerce(toDescriptorType: typeCompDescriptor)!
            let opDesc1 = try appData.pack(operand1)
            let opDesc2 = try appData.pack(operand2)
            if operatorType === _kAEIsInDesc { // AEM doesn't support a 'kAEIsIn' enum...
                desc.setDescriptor(_kAEContainsDesc, forKeyword: _keyAECompOperator) // so use kAEContains with operands reversed
                desc.setDescriptor(opDesc2, forKeyword: _keyAEObject1)
                desc.setDescriptor(opDesc1, forKeyword: _keyAEObject2)
            } else {
                desc.setDescriptor(operatorType, forKeyword: _keyAECompOperator)
                desc.setDescriptor(opDesc1, forKeyword: _keyAEObject1)
                desc.setDescriptor(opDesc2, forKeyword: _keyAEObject2)
            }
            return desc
        }
    }
    
    public var parentQuery: Query {
        return operand1
    }
    
    public var rootSpecifier: RootSpecifier {
        return operand1.rootSpecifier
    }
    
}

public class LogicalTest: TestClause, ChildQuery {
    
    public var appData: AppData

    public let operatorType: NSAppleEventDescriptor
    public let operands: [TestClause] // note: this doesn't have a 'parent' as such; to walk chain, just use first operand

    init(operatorType: NSAppleEventDescriptor, operands: [TestClause], appData: AppData) {
        self.operatorType = operatorType
        self.operands = operands
        self.appData = appData
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        let desc = NSAppleEventDescriptor.record().coerce(toDescriptorType: typeLogicalDescriptor)!
        desc.setDescriptor(operatorType, forKeyword: _keyAELogicalOperator)
        desc.setDescriptor(try appData.pack(operands), forKeyword: _keyAELogicalTerms)
        return desc
    }
    
    public var parentQuery: Query {
        return operands[0]
    }

    public var rootSpecifier: RootSpecifier {
        return operands[0].rootSpecifier
    }
    
}

/******************************************************************************/
// Specifier roots (all Specifier chains must originate from a RootSpecifier instance)

public class RootSpecifier: Specifier, ObjectSpecifierProtocol {
    
    public enum Kind {
        /// Root of all absolute object specifiers.
        /// e.g., `document 1 of «application»`.
        case application
        /// Root of an object specifier specifying the start or end of a range of
        /// elements in a by-range specifier.
        /// e.g., `folders (folder 2 of «container») thru (folder -1 of «container»)`.
        case container
        /// Root of an object specifier specifying an element whose state is being
        /// compared in a by-test specifier.
        /// e.g., `every track where (rating of «specimen» > 50)`.
        case specimen
        /// Root of an object specifier that descends from a descriptor object.
        /// e.g., `item 1 of {1,2,3}`.
        /// (These sorts of descriptors are effectively exclusively generated
        /// by AppleScript).
        case object(NSAppleEventDescriptor)
    }
    
    public var kind: Kind
    
    public init(_ kind: Kind, appData: AppData) {
        self.kind = kind
        super.init(appData: appData)
    }
    
    public var wantType: NSAppleEventDescriptor {
        .null()
    }
    public var selectorForm: NSAppleEventDescriptor {
        .null()
    }
    
    public var selectorData: Any {
        switch kind {
        case .application:
            return NSAppleEventDescriptor.null()
        case .container:
            return NSAppleEventDescriptor(descriptorType: typeCurrentContainer, data: nil)!
        case .specimen:
            return NSAppleEventDescriptor(descriptorType: typeObjectBeingExamined, data: nil)!
        case let .object(descriptor):
            return descriptor
        }
    }
    
    // Query/Specifier-inherited properties and methods that recursively call their parent specifiers are overridden here to ensure they terminate:
    
    public var parentQuery: Query {
        self
    }
    
    public override var rootSpecifier: RootSpecifier {
        self
    }
    
    public override func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        try appData.pack(selectorData)
    }
    
}

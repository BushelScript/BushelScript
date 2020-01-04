import Bushel

/// Base type for all runtime objects.
@objc public class RT_Object: NSObject {
    
    private static let typeInfo_ = TypeInfo(.item, [.root])
    public class var typeInfo: TypeInfo {
        typeInfo_
    }
    public var dynamicTypeInfo: TypeInfo {
        type(of: self).typeInfo
    }
    var truthy: Bool {
        true
    }
    var properties: [RT_Object] {
        []
    }
    public func property(_ property: PropertyInfo) throws -> RT_Object {
        switch PropertyUID(property.typedUID) {
        case .properties:
            return RT_List(contents: self.properties)
        case .type:
            return RT_Class(value: self.dynamicTypeInfo)
        default:
            throw NoPropertyExists(type: self.dynamicTypeInfo, property: property)
        }
    }
    
    public func coerce(to type: TypeInfo) -> RT_Object? {
        if dynamicTypeInfo.isA(type) {
            return self
        } else {
            switch TypeUID(type.typedUID) {
            case .boolean:
                return RT_Boolean.withValue(self.truthy)
            case .string:
                return RT_String(value: String(describing: self))
            default:
                return nil
            }
        }
    }
    
    public func not() -> RT_Object? {
        return RT_Boolean.withValue(!truthy)
    }
    
    /// Compares this object with another object.
    ///
    /// - Parameter other: The object to compare against.
    /// - Returns: The ordering of this object relative to the other object,
    ///            or nil if there is no ordering relationship between them.
    public func compare(with other: RT_Object) -> ComparisonResult? {
        return nil
    }
    
    /// Checks this object for equality with another object.
    ///
    /// - Parameter other: The object to compare against.
    /// - Returns: Whether this object is equal to the other object.
    ///
    /// - Note: **If you override** `compareEqual(with:)`, **you must also override** `NSObject.hash`.
    public func compareEqual(with other: RT_Object) -> Bool {
        return self === other || (compare(with: other) == .orderedSame)
    }
    
    public final override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? RT_Object else { return false }
        return self.compareEqual(with: object)
    }
    
    public func or(_ other: RT_Object) -> RT_Object? {
        return RT_Boolean.withValue(truthy || other.truthy)
    }
    
    public func xor(_ other: RT_Object) -> RT_Object? {
        let lhsTruthy = truthy
        let rhsTruthy = other.truthy
        return RT_Boolean.withValue(lhsTruthy && !rhsTruthy || !lhsTruthy && rhsTruthy)
    }
    
    public func and(_ other: RT_Object) -> RT_Object? {
        return RT_Boolean.withValue(truthy && other.truthy)
    }
    
    public func equal(to other: RT_Object) -> RT_Object? {
        return RT_Boolean.withValue(compareEqual(with: other))
    }
    
    public func notEqual(to other: RT_Object) -> RT_Object? {
        return RT_Boolean.withValue(!compareEqual(with: other))
    }
    
    public func less(than other: RT_Object) -> RT_Object? {
        return compare(with: other).map { RT_Boolean.withValue($0 == .orderedAscending) }
    }
    
    public func lessEqual(to other: RT_Object) -> RT_Object? {
        return compare(with: other).map { RT_Boolean.withValue($0 != .orderedDescending) }
    }
    
    public func greater(than other: RT_Object) -> RT_Object? {
        return compare(with: other).map { RT_Boolean.withValue($0 == .orderedDescending) }
    }
    
    public func greaterEqual(to other: RT_Object) -> RT_Object? {
        return compare(with: other).map { RT_Boolean.withValue($0 != .orderedAscending) }
    }
    
    public func startsWith(_ other: RT_Object) -> RT_Object? {
        return nil
    }
    
    public func endsWith(_ other: RT_Object) -> RT_Object? {
        return nil
    }
    
    public func contains(_ other: RT_Object) -> RT_Object? {
        return nil
    }
    
    public func notContains(_ other: RT_Object) -> RT_Object? {
        return contains(other).map { RT_Boolean.withValue(!$0.truthy) }
    }
    
    public func contained(by other: RT_Object) -> RT_Object? {
        return other.contains(self)
    }
    
    public func notContained(by other: RT_Object) -> RT_Object? {
        return contained(by: other).map { RT_Boolean.withValue(!$0.truthy) }
    }
    
    public func adding(_ other: RT_Object) -> RT_Object? {
        return nil
    }
    
    public func subtracting(_ other: RT_Object) -> RT_Object? {
        return nil
    }
    
    public func multiplying(by other: RT_Object) -> RT_Object? {
        return nil
    }
    
    public func dividing(by other: RT_Object) -> RT_Object? {
        return nil
    }
    
    public func concatenating(_ other: RT_Object) -> RT_Object? {
        return nil
    }
    
    public func concatenated(to other: RT_Object) -> RT_Object? {
        return nil
    }
    
    /// Asks this object to perform the specified command.
    ///
    /// - Parameters:
    ///   - command: The command to perform.
    ///   - arguments: The arguments to the command.
    /// - Returns: The result of this object executing the command, or
    ///            `nil` if the command was not handled.
    public func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object]) throws -> RT_Object? {
        return nil
    }
    
    // Most of the following default implementations just throw UnsupportedIndexForm.
    
    /// Accesses the element at the given index.
    ///
    /// - Parameter index: The index of the element to access.
    /// - Returns: The element at index `index`.
    /// - Throws:
    ///     - `NoElementExists` if there is no element at the given index.
    ///     - `UnsupportedIndexForm` if indexed access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, at index: Int64) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .index, class: dynamicTypeInfo)
    }
    
    /// Accesses the element with the given name.
    ///
    /// - Parameter name: The name of the element to access.
    /// - Returns: The element named `name`.
    /// - Throws:
    ///     - `NoElementExists` if there is no element with the given name.
    ///     - `UnsupportedIndexForm` if named access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, named name: String) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .name, class: dynamicTypeInfo)
    }
    
    /// Accesses the element with the given unique ID.
    ///
    /// - Parameter id: The unique ID of the element to access. Can be of
    ///                 any runtime type.
    /// - Returns: The element with ID `id`.
    /// - Throws:
    ///     - `NoElementExists` if there is no element with the given ID.
    ///     - `UnsupportedIndexForm` if ID access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, id: RT_Object) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .id, class: dynamicTypeInfo)
    }
    
    /// Accesses the element positioned relative to the receiver
    /// within its primary container.
    ///
    /// The returned element should be a member of the receiver’s `parent`
    /// container, and that container alone should be used to determine
    /// element ordering.
    ///
    /// - Parameter positioning: The position, relative to the receiver,
    ///                          of the element to access.
    /// - Returns: The element positioned relative to the receiver.
    /// - Throws:
    ///     - `NoElementExists` if there is no element at the position
    ///       specified.
    ///     - `UnsupportedIndexForm` if relative access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, positioned positioning: RelativePositioning) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .relative, class: dynamicTypeInfo)
    }
    
    // TODO: doc comments
    
    public func element(_ type: TypeInfo, before child: RT_Object) throws -> RT_Object {
        return try child.element(type, positioned: .before)
    }
    
    public func element(_ type: TypeInfo, after child: RT_Object) throws -> RT_Object {
        return try child.element(type, positioned: .after)
    }
    
    public func element(_ type: TypeInfo, at positioning: AbsolutePositioning) throws -> RT_Object {
        switch positioning {
        case .first:
            return try element(type, at: 0)
        default:
            throw UnsupportedIndexForm(indexForm: .absolute, class: dynamicTypeInfo)
        }
    }
    
    public func elements(_ type: TypeInfo) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .all, class: dynamicTypeInfo)
    }
    
    public func elements(_ type: TypeInfo, from: RT_Object, thru: RT_Object) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .range, class: dynamicTypeInfo)
    }
    
    public func elements(_ type: TypeInfo, filtered: RT_Specifier) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .filter, class: dynamicTypeInfo)
    }
    
}

public enum RelativePositioning {
    case before
    case after
}
public enum AbsolutePositioning {
    case first
    case middle
    case last
    case random
}

func <=> (lhs: RT_Object, rhs: RT_Object) -> ComparisonResult? {
    return lhs.compare(with: rhs)
}

extension RT_Object: Comparable {
    
    public static func < (lhs: RT_Object, rhs: RT_Object) -> Bool {
        return lhs.compare(with: rhs) == .orderedAscending
    }
    
}

extension RT_Object {
    
    public func coerce<T: RT_Object>() -> T? {
        coerce(to: T.typeInfo) as? T
    }
    
}

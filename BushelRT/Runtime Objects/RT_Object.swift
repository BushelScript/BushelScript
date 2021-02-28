import Bushel

/// Base type for all runtime objects.
@objc public class RT_Object: NSObject, RTTyped {
    
    private static let typeInfo_ = TypeInfo(.item, [.root])
    
    /// The runtime type that this `RT_Object` subclass implements.
    /// Should probably be overridden in every subclass.
    public class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    /// The runtime type of this instance.
    /// The base implementation returns `Swift.type(of: self).typeInfo`.
    ///
    /// Overridable for cases when an `RT_Object` subclass can represent values
    /// of different runtime types.
    public var dynamicTypeInfo: TypeInfo {
        Swift.type(of: self).typeInfo
    }
    
    /// Whether this object should be considered equivalent to the boolean
    /// `true` when the predicate of a conditional or coerced to boolean type.
    ///
    /// The base implementation returns `true`. Should only be `false` for
    /// cases where being untruthy would be intuitive, i.e., for `null`,
    /// empty strings, a `false` boolean itself, etc.
    public var truthy: Bool {
        true
    }
    
    /// A map of property terms to the static keypaths through which
    /// their values may be accessed on instances of this runtime type.
    ///
    /// - Important: If this is overridden, then `evaluateStaticProperty(_:)`
    /// must also be overridden so that the static keypath mapping machinery
    /// knows what type it is applying the keypath to.
    public class var propertyKeyPaths: [PropertyInfo : AnyKeyPath] {
        [:]
    }
    /// A peer to `propertyKeyPaths`. This must be also overridden whenever
    /// `propertyKeyPaths` is overridden.
    ///
    /// A subclass implementation should look like this:
    ///
    ///     public func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
    ///         keyPath.evaluate(on: self)
    ///     }
    ///
    public func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    /// A map of statically-declared property terms to their current values.
    /// Does not include any properties that are not known to exist until
    /// until runtime, e.g., record keys.
    public var staticProperties: [PropertyInfo : RT_Object] {
        [PropertyInfo(Properties.type): RT_Object.type(dynamicTypeInfo)].merging(
            RT_Object.propertyKeyPaths.compactMapValues { evaluateStaticProperty($0) },
            uniquingKeysWith: { old, new in new }
        )
    }
    
    /// A map of all property terms to their current values.
    ///
    /// Overridable to allow for dynamic property listings; for properties that
    /// are statically known to exist, an overridden `propertyKeyPaths` and
    /// `evaluateStaticProperty(_:)` pair is preferable.
    public var properties: [PropertyInfo : RT_Object] {
        staticProperties
    }
    
    /// This object's value for the requested property, if available.
    /// Throws if unavailable.
    ///
    /// - Parameter property: The requested property.
    ///
    /// - Throws:
    ///   - `NoPropertyExists` if the property does not exist on this object.
    ///   - Any errors produced during evaluation of the property.
    ///
    /// Overridable to allow for more efficient dynamic property lookup.
    /// Dynamic properties from the `properties` member are automatically
    /// searched by the base implementation, but this will be slower since it
    /// requires computing all property values when only one is needed.
    ///
    /// For properties that are statically known to exist, an overridden
    /// `propertyKeyPaths` and `evaluateStaticProperty(_:)` pair is preferable.
    public func property(_ property: PropertyInfo) throws -> RT_Object {
        switch Properties(property.id) {
        case .properties:
            return RT_Record(contents:
                [RT_Object : RT_Object](uniqueKeysWithValues:
                    self.properties.map { (key: .property($0.key), value: $0.value) }
                )
            )
        case .type:
            return RT_Type(value: self.dynamicTypeInfo)
        default:
            // Prefer to avoid evaluating all properties if we can.
            if
                let keyPath = Swift.type(of: self).propertyKeyPaths[property],
                let value = evaluateStaticProperty(keyPath)
            {
                return value
            }
            
            // Bite the bullet and evaluate all properties to check if there's
            // a satisfactory dynamic property.
            if let value = properties[property] {
                return value
            }
            
            throw NoPropertyExists(type: dynamicTypeInfo, property: property)
        }
    }
    
    /// Sets this object's value for the requested property,
    /// if such a property can exist. Throws if it cannot exist or be set.
    ///
    /// - Parameters:
    ///   - property: The targeted property.
    ///   - newValue: The new value to assign for the property.
    ///
    /// - Throws:
    ///   - `NoWritablePropertyExists` if the property cannot exist on this
    ///     object or is not writable.
    ///   - `Uncoercible` if the proposed new value cannot be coerced to
    ///     a suitable type for the property.
    ///
    /// This is called by the `RT_Specifier` implementation of the `set` command.
    public func setProperty(_ property: PropertyInfo, to newValue: RT_Object) throws {
        throw NoWritablePropertyExists(type: dynamicTypeInfo, property: property)
    }
    
    public func coerce(to type: TypeInfo) -> RT_Object? {
        if dynamicTypeInfo.isA(type) {
            return self
        } else {
            switch Types(type.id) {
            case .boolean:
                return RT_Boolean.withValue(self.truthy)
            case .string:
                return RT_String(value: String(describing: self))
            default:
                return nil
            }
        }
    }
    
    public func evaluate() throws -> RT_Object {
        try (self as? RT_HierarchicalSpecifier)?.evaluate_() ?? self
    }
    
    /// Applies a unary logical NOT operation.
    public final func not() -> RT_Object? {
        RT_Boolean.withValue(!truthy)
    }
    
    /// The ordering of this object relative to another object, or `nil` if
    /// no such ordering relationship exists.
    ///
    /// - Parameter other: The object to compare against.
    ///
    /// The base implementation always returns `nil`. This should be overridden
    /// to define any ordering relationships between objects of the same or
    /// different runtime types.
    ///
    /// - Important: If this is overridden, then `hash` must also be overridden.
    public func compare(with other: RT_Object) -> ComparisonResult? {
        nil
    }
    
    /// Whether this object is equivalent to another object.
    ///
    /// - Parameter other: The object to compare against.
    ///
    /// The base implementation first checks whether `self === other`
    /// (pointer equality). If this is `false`, it defers to whether
    /// `compare(with:)` returns `.orderedSame`.
    ///
    /// This is overridable so that equivalence relationships may be defined
    /// without defining full ordering relationships.
    ///
    /// - Important: If this is overridden, then `hash` must also be overridden.
    public func compareEqual(with other: RT_Object) -> Bool {
        self === other ||
            self.compare(with: other) == .orderedSame ||
            other.compare(with: self) == .orderedSame
    }
    
    // Overrides -[NSObject isEqual:] to use compareEqual(with:).
    public final override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? RT_Object else { return false }
        return self.compareEqual(with: object)
    }
    
    /// Applies a binary logical OR operation.
    public final func or(_ other: RT_Object) -> RT_Object? {
        RT_Boolean.withValue(truthy || other.truthy)
    }
    
    /// Applies a binary logical XOR operation.
    public final func xor(_ other: RT_Object) -> RT_Object? {
        let lhsTruthy = truthy
        let rhsTruthy = other.truthy
        return RT_Boolean.withValue(lhsTruthy && !rhsTruthy || !lhsTruthy && rhsTruthy)
    }
    
    /// Applies a binary logical AND operation.
    public final func and(_ other: RT_Object) -> RT_Object? {
        RT_Boolean.withValue(truthy && other.truthy)
    }
    
    /// Applies a binary equivalence comparison.
    ///
    /// Cannot be overridden.
    /// `compare(with:)` and/or `compareEqual(with:)` should be overridden to
    /// define ordering and equivalence relationships between objects.
    public final func equal(to other: RT_Object) -> RT_Object? {
        return RT_Boolean.withValue(compareEqual(with: other))
    }
    
    /// Applies an inverted binary equivalence comparison.
    public final func notEqual(to other: RT_Object) -> RT_Object? {
        return RT_Boolean.withValue(!compareEqual(with: other))
    }
    
    /// Applies a binary less-than (<) comparison.
    ///
    /// Cannot be overridden.
    /// `compareEqual(with:)` should be overridden to define ordering
    /// relationships between objects.
    public final func less(than other: RT_Object) -> RT_Object? {
        guard let order = compare(with: other) else {
            return nil
        }
        return RT_Boolean.withValue(order == .orderedAscending)
    }
    
    /// Applies a binary less-than-equal (≤) comparison.
    ///
    /// Cannot be overridden.
    /// `compareEqual(with:)` should be overridden to define ordering
    /// relationships between objects.
    public final func lessEqual(to other: RT_Object) -> RT_Object? {
        guard let order = compare(with: other) else {
            return nil
        }
        return RT_Boolean.withValue(order != .orderedDescending)
    }
    
    /// Applies a binary greater-than (>) comparison.
    ///
    /// Cannot be overridden.
    /// `compareEqual(with:)` should be overridden to define ordering
    /// relationships between objects.
    public final func greater(than other: RT_Object) -> RT_Object? {
        guard let order = compare(with: other) else {
            return nil
        }
        return RT_Boolean.withValue(order == .orderedDescending)
    }
    
    /// Applies a binary greater-than-equal (≥) comparison.
    ///
    /// Cannot be overridden.
    /// `compareEqual(with:)` should be overridden to define ordering
    /// relationships between objects.
    public final func greaterEqual(to other: RT_Object) -> RT_Object? {
        guard let order = compare(with: other) else {
            return nil
        }
        return RT_Boolean.withValue(order != .orderedAscending)
    }
    
    /// Applies a binary starts-with comparison.
    ///
    /// - Returns: Whether this object starts-with `other`.
    ///
    /// The base implementation returns `nil`. This should be overridden to
    /// define any starts-with relationships between objects.
    public func startsWith(_ other: RT_Object) -> RT_Object? {
        nil
    }
    
    /// Applies a binary ends-with comparison.
    ///
    /// - Returns: Whether this object ends-with `other`.
    ///
    /// The base implementation returns `nil`. This should be overridden to
    /// define any ends-with relationships between objects.
    public func endsWith(_ other: RT_Object) -> RT_Object? {
        nil
    }
    
    /// Applies a binary contains comparison.
    ///
    /// - Returns: Whether this object contains `other`.
    ///
    /// The base implementation returns `nil`. This should be overridden to
    /// define any containment relationships between objects.
    public func contains(_ other: RT_Object) -> RT_Object? {
        nil
    }
    
    /// Applies an inverted binary contains comparison.
    public final func notContains(_ other: RT_Object) -> RT_Object? {
        contains(other).map { RT_Boolean.withValue(!$0.truthy) }
    }
    
    /// Applies a binary contained-by comparison.
    ///
    /// Cannot be overridden.
    /// `contains(_:)` should be overridden to define containment
    /// relationships between objects.
    public final func contained(by other: RT_Object) -> RT_Object? {
        other.contains(self)
    }
    
    /// Applies an inverted binary contained-by comparison.
    public func notContained(by other: RT_Object) -> RT_Object? {
        contained(by: other).map { RT_Boolean.withValue(!$0.truthy) }
    }
    
    /// Applies a binary addition operation.
    ///
    /// The base implementation returns `nil`. This should be overridden to
    /// define any addition operations between objects.
    public func adding(_ other: RT_Object) -> RT_Object? {
        nil
    }
    
    /// Applies a binary subtraction operation.
    ///
    /// The base implementation returns `nil`. This should be overridden to
    /// define any subtraction operations between objects.
    public func subtracting(_ other: RT_Object) -> RT_Object? {
        nil
    }
    
    /// Applies a binary multiplication operation.
    ///
    /// The base implementation returns `nil`. This should be overridden to
    /// define any multiplication operations between objects.
    public func multiplying(by other: RT_Object) -> RT_Object? {
        nil
    }
    
    /// Applies a binary division operation.
    ///
    /// The base implementation returns `nil`. This should be overridden to
    /// define any division operations between objects.
    public func dividing(by other: RT_Object) -> RT_Object? {
        nil
    }
    
    /// Applies a binary concatenation operation.
    ///
    /// The base implementation returns `nil`. This should be overridden
    /// alongside `concatenated(to:)` to define any concatenation operations
    /// between objects.
    public func concatenating(_ other: RT_Object) -> RT_Object? {
        nil
    }
    
    /// Applies a reverse binary concatenation operation.
    ///
    /// The base implementation returns `nil`. This should be overridden
    /// alongside `concatenating(_:)` to define any addition operations
    /// between objects.
    public func concatenated(to other: RT_Object) -> RT_Object? {
        return nil
    }
    
    /// Applies a binary coercion operation.
    ///
    /// Cannot be overridden.
    /// `coerce(to:)` should be overridden to define coercions.
    public final func coercing(to other: RT_Object) throws -> RT_Object {
        guard let type = (other as? RT_Type)?.value else {
            throw TypeObjectRequired(object: other)
        }
        guard let coerced = coerce(to: type) else {
            throw Uncoercible(expectedType: type, object: self)
        }
        return coerced
    }
    
    /// Asks this object to perform the specified command.
    ///
    /// - Parameters:
    ///   - command: The command to perform.
    ///   - arguments: The arguments to the command.
    ///   - implicitDirect: The implicit direct object argument, if any.
    ///                     This will, for example, not cause errors if it is
    ///                     unencodable but specified with a remote event.
    ///
    /// - Returns: The result of this object executing the command, or
    ///            `nil` if the command could not be handled.
    public func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        return nil
    }
    
    // Most of the following default implementations just throw UnsupportedIndexForm.
    
    /// The element of the given type at the given index, if one exists.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - index: The index of the element to access.
    ///
    /// - Throws:
    ///     - `NoElementExists` if there is no element of the specified type
    ///       at the given index.
    ///     - `UnsupportedIndexForm` if indexed access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, at index: Int64) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .index, class: dynamicTypeInfo)
    }
    
    /// The element of the given type with the given name, if one exists.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - name: The name of the element to access.
    ///
    /// - Throws:
    ///     - `NoElementExists` if there is no element of the specified type
    ///       with the given name.
    ///     - `UnsupportedIndexForm` if named access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, named name: String) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .name, class: dynamicTypeInfo)
    }
    
    /// The element of the given type with the given unique ID, if one exists.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - id: The unique ID of the element to access. Can be of any
    ///           runtime type.
    ///
    /// - Throws:
    ///     - `NoElementExists` if there is no element of the specified type
    ///       with the given ID.
    ///     - `UnsupportedIndexForm` if by-ID access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, id: RT_Object) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .id, class: dynamicTypeInfo)
    }
    
    /// The element, if one exists, of the given type positioned relative to
    /// this object within its primary container.
    ///
    /// The returned object should also be an element of this object's primary
    /// container, and that container alone should consulted to determine
    /// element ordering. The meaning of "primary container" depends entirely
    /// on the context of the specific object in question.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - positioning: The position relative to this object of the element
    ///                    to access.
    ///
    /// - Throws:
    ///     - `NoElementExists` if there is no element of the specified type
    ///       at the given position.
    ///     - `UnsupportedIndexForm` if relative access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, positioned positioning: RelativePositioning) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .relative, class: dynamicTypeInfo)
    }
    
    /// The element of the given type at the specified absolute positioning,
    /// if one exists.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - positioning: The absolute positioning of the element to access.
    ///
    /// - Throws:
    ///     - `NoElementExists` if there is no element of the specified type
    ///       at the given position.
    ///     - `UnsupportedIndexForm` if absolute access is unsupported by
    ///       the receiver.
    public func element(_ type: TypeInfo, at positioning: AbsolutePositioning) throws -> RT_Object {
        switch positioning {
        case .first:
            return try element(type, at: 0)
        default:
            throw UnsupportedIndexForm(indexForm: .absolute, class: dynamicTypeInfo)
        }
    }
    
    /// All elements of the given type, if any exist.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///
    /// - Throws:
    ///     - `NoElementExists` if there are no elements of the specified type.
    ///     - `UnsupportedIndexForm` if all-element access is unsupported by
    ///       the receiver.
    public func elements(_ type: TypeInfo) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .all, class: dynamicTypeInfo)
    }
    
    /// The elements, if any exist, of the given type within the specified
    /// bounds.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - from: The lower bound.
    ///     - thru: The upper bound.
    ///
    /// - Throws:
    ///     - `NoElementExists` if there are no elements of the specified type
    ///       within the given bounds.
    ///     - `UnsupportedIndexForm` if absolute access is unsupported by
    ///       the receiver.
    public func elements(_ type: TypeInfo, from: RT_Object, thru: RT_Object) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .range, class: dynamicTypeInfo)
    }
    
    // TODO: Must be migrated to RT_TestSpecifier before documentation & use.
    @available(*, unavailable)
    public func elements(_ type: TypeInfo, filtered: RT_Specifier) throws -> RT_Object {
        throw UnsupportedIndexForm(indexForm: .filter, class: dynamicTypeInfo)
    }
    
}


/// Symbolic constants passed to `element(_:positioned:)`.
public enum RelativePositioning {
    /// The element before some object.
    case before
    /// The element after some object.
    case after
}

/// Symbolic constants passed to `element(_:at:)`.
public enum AbsolutePositioning {
    /// The first element.
    case first
    /// The element in the middle of the container, rounding down.
    /// e.g., `middle of {1,2,3,4}` is `2`.
    case middle
    /// The last element.
    case last
    /// A randomly selected element out of the container.
    /// No, really.
    /// Listen, this was Apple's idea, not mine.
    case random
}

/// Compares two runtime objects via `lhs.compare(with: rhs)`.
func <=> (lhs: RT_Object, rhs: RT_Object) -> ComparisonResult? {
    return lhs.compare(with: rhs)
}

// MARK: Comparable
extension RT_Object: Comparable {
    
    public static func < (lhs: RT_Object, rhs: RT_Object) -> Bool {
        return lhs.compare(with: rhs) == .orderedAscending
    }
    
}

// MARK: Coercion utility functions
extension RT_Object {
    
    /// Attempts to coerce this object to the runtime type specified
    /// by Swift type `to`.
    ///
    /// e.g., `RT_Integer(value: 42).coerce(to: RT_Real.self)`
    ///
    /// - Returns: This instance coerced to `To.typeInfo` via `coerce(to:)`, or
    ///            `nil` if the coercion returns `nil` or something other than
    ///            a `To`.
    public func coerce<To: RTTyped>(to _: To.Type) -> To? {
        coerce(to: To.typeInfo) as? To
    }

    /// Forcibly coerces this object to the runtime type specified
    /// by Swift type `to`.
    ///
    /// e.g., `try RT_Integer(value: 42).coerceOrThrow(to: RT_Real.self)`
    ///
    /// - Returns: This instance coerced to `To.typeInfo` via `coerce(to:)`.
    ///
    /// - Throws:
    ///     - `Uncoercible` if the coercion returns `nil` or something other
    ///       than a `To`.
    public func coerceOrThrow<To: RTTyped>(to _: To.Type) throws -> To {
        guard let coerced = coerce(to: To.self) else {
            throw Uncoercible(expectedType: To.typeInfo, object: self)
        }
        return coerced
    }
    
}

// MARK: Reflective object factory functions
extension RT_Object {
    
    /// The reflective runtime object representation of the given property.
    public static func property(_ property: PropertyInfo) -> RT_Object {
        RT_Constant(value: ConstantInfo(property: property))
    }
    
    /// The reflective runtime object representation of the given symbolic constant.
    public static func constant(_ constant: ConstantInfo) -> RT_Object {
        RT_Constant(value: constant)
    }
    
    /// The reflective runtime object representation of the given type.
    public static func type(_ type: TypeInfo) -> RT_Object {
        RT_Type(value: type)
    }
    
}

extension AnyKeyPath {
    
    public func evaluate<Object: RT_Object>(on object: Object) -> RT_Object? {
        (self as? PartialKeyPath<Object>)
            .flatMap { object[keyPath: $0] as? RT_Object }
    }
    
}

public protocol RTTyped {
    
    /// The BushelScript Runtime type that this Swift type implements.
    static var typeInfo: TypeInfo { get }
    
}

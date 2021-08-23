import Bushel

/// Base type for all runtime objects.
@objc public class RT_Object: NSObject {
    
    public weak var rt: Runtime!
    
    public init(_ rt: Runtime) {
        self.rt = rt
    }
    
    public class var staticType: Types {
        .item
    }
    
    /// The runtime type of this instance.
    public var type: Reflection.`Type` {
        rt.reflection.types[Swift.type(of: self).staticType]
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
    public class var propertyKeyPaths: [Properties : AnyKeyPath] {
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
    public var staticProperties: [Properties : RT_Object] {
        [.type: RT_Type(rt, value: type)].merging(
            RT_Object.propertyKeyPaths.compactMapValues {
                evaluateStaticProperty($0)
            },
            uniquingKeysWith: { old, new in new }
        )
    }
    
    /// A map of all property terms to their current values.
    ///
    /// Overridable to allow for dynamic property listings; for properties that
    /// are statically known to exist, an overridden `propertyKeyPaths` and
    /// `evaluateStaticProperty(_:)` pair is preferable.
    public var properties: [Reflection.Property : RT_Object] {
        [Reflection.Property : RT_Object](uniqueKeysWithValues:
            staticProperties.map { (rt.reflection.properties[$0.key], $0.value) }
        )
    }
    
    /// This object's value for the requested property, or nil if unavailable.
    ///
    /// - Parameter property: The requested property.
    ///
    /// - Throws: Any errors produced during evaluation of the property.
    ///
    /// Overridable to allow for more efficient dynamic property lookup.
    /// Dynamic properties from the `properties` member are automatically
    /// searched by the base implementation, but this will be slower since it
    /// requires computing all property values when only one is needed.
    ///
    /// For properties that are statically known to exist, an overridden
    /// `propertyKeyPaths` and `evaluateStaticProperty(_:)` pair is preferable.
    public func property(_ property: Reflection.Property) throws -> RT_Object? {
        switch Properties(property.id) {
        case .properties:
            return RT_Record(rt, contents:
                [RT_Object : RT_Object](uniqueKeysWithValues:
                    self.properties.map { (key: RT_Constant(rt, value: Reflection.Constant(property: $0.key)), value: $0.value) }
                )
            )
        case .type:
            return RT_Type(rt, value: self.type)
        default:
            // Prefer to avoid evaluating all properties if we can.
            if
                let predefined = Properties(property.uri),
                let keyPath = Swift.type(of: self).propertyKeyPaths[predefined],
                let value = evaluateStaticProperty(keyPath)
            {
                return value
            }
            
            // Bite the bullet and evaluate all properties to check if there's
            // a satisfactory dynamic property.
            return properties[property]
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
    public func setProperty(_ property: Reflection.Property, to newValue: RT_Object) throws {
        throw NoWritablePropertyExists()
    }
    
    public func coerce(to type: Reflection.`Type`) -> RT_Object? {
        if self.type.isA(type) {
            return self
        } else {
            switch Types(type.id) {
            case .boolean:
                return RT_Boolean.withValue(rt, self.truthy)
            case .string:
                return RT_String(rt, value: String(describing: self))
            default:
                return nil
            }
        }
    }
    
    public func evaluate() throws -> RT_Object {
        if let specifier = self as? RT_HierarchicalSpecifier {
            return try specifier.rootAncestor().evaluateSpecifierRootedAtSelf(specifier)
        }
        return self
    }
    
    public func evaluateSpecifierRootedAtSelf(_ specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        try evaluateLocalSpecifierRootedAtSelf(specifier)
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
    
    // Most of the following default implementations just return nil.
    
    /// The element of the given type at the given index, or nil if none exists.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - index: The index of the element to access.
    public func element(_ type: Reflection.`Type`, at index: Int64) throws -> RT_Object? {
        nil
    }
    
    /// The element of the given type with the given name, or nil if none exists.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - name: The name of the element to access.
    public func element(_ type: Reflection.`Type`, named name: String) throws -> RT_Object? {
        nil
    }
    
    /// The element of the given type with the given unique ID, or nil if none
    /// exists.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - id: The unique ID of the element to access. Can be of any
    ///           runtime type.
    public func element(_ type: Reflection.`Type`, id: RT_Object) throws -> RT_Object? {
        nil
    }
    
    /// The element of the given type positioned relative to this object within
    /// its primary container, or nil if none exists.
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
    public func element(_ type: Reflection.`Type`, positioned positioning: RelativePositioning) throws -> RT_Object? {
        nil
    }
    
    /// The element of the given type at the specified absolute positioning,
    /// or nil if none exists.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - positioning: The absolute positioning of the element to access.
    public func element(_ type: Reflection.`Type`, at positioning: AbsolutePositioning) throws -> RT_Object? {
        switch positioning {
        case .first:
            return try element(type, at: 0)
        default:
            return nil
        }
    }
    
    /// All elements of the given type.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    public func elements(_ type: Reflection.`Type`) throws -> RT_Object {
        RT_List(rt, contents: [])
    }
    
    /// The elements of the given type within the specified bounds.
    ///
    /// - Parameters:
    ///     - type: The type of element to access.
    ///     - from: The lower bound.
    ///     - thru: The upper bound.
    public func elements(_ type: Reflection.`Type`, from: RT_Object, thru: RT_Object) throws -> RT_Object {
        RT_List(rt, contents: [])
    }
    
    // TODO: Must be migrated to RT_TestSpecifier before documentation & use.
    @available(*, unavailable)
    public func elements(_ type: Reflection.`Type`, filtered: RT_Specifier) throws -> RT_Object {
        RT_List(rt, contents: [])
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
    /// e.g., `RT_Integer(rt, value: 42).coerce(to: RT_Real.self)`
    ///
    /// - Returns: This instance coerced to `To.Reflection.`Type`` via `coerce(to:)`, or
    ///            `nil` if the coercion returns `nil` or something other than
    ///            a `To`.
    public func coerce<To: RT_Object>(to _: To.Type) -> To? {
        coerce(to: rt.reflection.types[To.staticType]) as? To
    }

    /// Forcibly coerces this object to the runtime type specified
    /// by Swift type `to`.
    ///
    /// e.g., `try RT_Integer(rt, value: 42).coerceOrThrow(to: RT_Real.self)`
    ///
    /// - Returns: This instance coerced to `To.Reflection.`Type`` via `coerce(to:)`.
    ///
    /// - Throws:
    ///     - `Uncoercible` if the coercion returns `nil` or something other
    ///       than a `To`.
    public func coerceOrThrow<To: RT_Object>(to _: To.Type) throws -> To {
        guard let coerced = coerce(to: To.self) else {
            throw Uncoercible(expectedType: rt.reflection.types[To.staticType], object: self)
        }
        return coerced
    }
    
}

extension AnyKeyPath {
    
    public func evaluate<Object: RT_Object>(on object: Object) -> RT_Object? {
        (self as? PartialKeyPath<Object>)
            .flatMap { object[keyPath: $0] as? RT_Object }
    }
    
}

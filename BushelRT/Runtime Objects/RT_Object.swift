import Bushel

/// Base type for all runtime objects.
@objc public class RT_Object: NSObject {
    
    private static let typeInfo_ = TypeInfo(TypeUID.item.rawValue, TypeUID.item.aeCode, [.root, .name(TermName("item"))])
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
        switch property.code {
        case try! FourCharCode(fourByteString: "pALL"):
            return RT_List(contents: self.properties)
        case pClass:
            return RT_Class(value: self.dynamicTypeInfo)
        default:
            throw NoPropertyExists(className: self.dynamicTypeInfo.displayName, property: property)
        }
    }
    
    public func coerce(to type: TypeInfo) -> RT_Object? {
        if dynamicTypeInfo.isA(type) {
            return self
        } else {
            switch type.code {
            case typeBoolean:
                return RT_Boolean.withValue(self.truthy)
            default:
                return nil
            }
        }
    }
    
    /// Compares this object with another object.
    ///
    /// - Parameter other: The object to compare against.
    /// - Returns: The ordering of this object relative to the other object,
    ///            or nil if there is no ordering relationship between them.
    public func compare(with other: RT_Object) -> ComparisonResult? {
        return nil
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
    public func perform(command: CommandInfo, arguments: [Bushel.ConstantTerm : RT_Object]) -> RT_Object? {
        print("Command “\(command.displayName)” not handled!")
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
        print(self)
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

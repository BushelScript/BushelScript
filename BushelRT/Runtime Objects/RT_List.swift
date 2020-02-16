import Bushel
import SwiftAutomation

/// An Apple Event list. Pretty much your standard list type.
public class RT_List: RT_Object, AEEncodable {
    
    public var contents: [RT_Object] = []
    
    public init(contents: [RT_Object]) {
        self.contents = contents
    }
    
    public override var description: String {
        "{\(contents.map { String(describing: $0) }.joined(separator: ", "))}"
    }
    
    private static let typeInfo_ = TypeInfo(.list)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var truthy: Bool {
        !contents.isEmpty
    }
    
    public func add(_ object: RT_Object) {
        contents.append(object)
    }
    
    public override func concatenating(_ other: RT_Object) -> RT_Object? {
        if let other = other.coerce() as? RT_List {
            return RT_List(contents: self.contents + other.contents)
        } else {
            return RT_List(contents: self.contents + [other])
        }
    }
    
    public override func concatenated(to other: RT_Object) -> RT_Object? {
        if let other = other.coerce() as? RT_List {
            return RT_List(contents: other.contents + self.contents)
        } else {
            return RT_List(contents: [other] + self.contents)
        }
    }
    
    public var length: RT_Integer {
        let count = Int64(contents.count)
        return RT_Integer(value: count)
    }
    public var reverse: RT_List {
        RT_List(contents: contents.reversed())
    }
    public var tail: RT_List {
        RT_List(contents: [RT_Object](contents[1...]))
    }
    
    public override class var propertyKeyPaths: [PropertyInfo : AnyKeyPath] {
        [
            PropertyInfo(PropertyUID.Sequence_length): \RT_List.length,
            PropertyInfo(PropertyUID.Sequence_reverse): \RT_List.reverse,
            PropertyInfo(PropertyUID.Sequence_tail): \RT_List.tail
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    private func filteredContents(_ type: TypeInfo) -> [RT_Object] {
        contents.filter { $0.dynamicTypeInfo.isA(type) }
    }
    
    public override func element(_ type: TypeInfo, at index: Int64) throws -> RT_Object {
        let filteredContents = self.filteredContents(type)
        let zeroBasedIndex = index - 1
        guard filteredContents.indices.contains(Int(zeroBasedIndex)) else {
            // FIXME: use the error system
            fatalError("index out of bounds")
        }
        return filteredContents[Int(zeroBasedIndex)]
    }
    
    public override func element(_ type: TypeInfo, at positioning: AbsolutePositioning) throws -> RT_Object {
        switch positioning {
        case .first:
            return try element(type, at: 0)
        case .middle:
            return try element(type, at: Int64(contents.count / 2))
        case .last:
            return try element(type, at: Int64(contents.count - 1))
        case .random:
            return try element(type, at: Int64(arc4random_uniform(UInt32(contents.count))))
        }
    }
    
    public override func elements(_ type: TypeInfo) throws -> RT_Object {
        return RT_List(contents: filteredContents(type))
    }
    
    public override func elements(_ type: TypeInfo, from: RT_Object, thru: RT_Object) throws -> RT_Object {
        let filteredContents = self.filteredContents(type)
        guard
            let from = (from.coerce() as? RT_Numeric)?.numericValue,
            let to = (thru.coerce() as? RT_Numeric)?.numericValue
        else {
            // FIXME: use the error system
            fatalError("range types incorrect")
        }
        guard filteredContents.indices.contains(Int(from)), filteredContents.indices.contains(Int(to)) else {
            // FIXME: use the error system
            fatalError("range out of bounds")
        }
        return RT_List(contents: Array(filteredContents[Int(from)...Int(to)]))
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        (other as? RT_List)
            .map { contents <=> $0.contents }
    }
    
    public override func contains(_ other: RT_Object) -> RT_Object? {
        RT_Boolean.withValue(
            contents.contains { $0.equal(to: other)?.truthy ?? false }
        )
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        switch CommandUID(command.typedUID) {
        case .Sequence_join:
            guard let separator = arguments[ParameterInfo(.Sequence_join_with)]?.coerce() as? RT_String else {
                // TODO: Throw error
                return nil
            }
            guard let strings = contents.map({ ($0.coerce() as? RT_String)?.value }) as? [String] else {
                // TODO: Throw error
                return nil
            }
            return RT_String(value: strings.joined(separator: separator.value))
        default:
            return try super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return try contents.enumerated().reduce(into: NSAppleEventDescriptor.list()) { (descriptor, entry) in
            let (index, value) = entry
            if let value = value as? AEEncodable {
                descriptor.insert(try value.encodeAEDescriptor(appData), at: index + 1)
            }
        }
    }
    
}

extension RT_List {
    
    public override var debugDescription: String {
        super.debugDescription + "[contents: \(contents)]"
    }
    
}

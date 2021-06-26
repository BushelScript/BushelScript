import Bushel
import AEthereal

/// An Apple Event list. Pretty much your standard list type.
public class RT_List: RT_Object, Encodable {
    
    public var contents: [RT_Object] = []
    
    public init(_ rt: Runtime, contents: [RT_Object]) {
        self.contents = contents
        super.init(rt)
    }
    
    public override var description: String {
        "{\(contents.map { String(describing: $0) }.joined(separator: ", "))}"
    }
    
    public override class var staticType: Types {
        .list
    }
    
    public override var truthy: Bool {
        !contents.isEmpty
    }
    
    public override func concatenating(_ other: RT_Object) -> RT_Object? {
        if let other = other.coerce(to: RT_List.self) {
            return RT_List(rt, contents: self.contents + other.contents)
        } else {
            return RT_List(rt, contents: self.contents + [other])
        }
    }
    
    public override func concatenated(to other: RT_Object) -> RT_Object? {
        if let other = other.coerce(to: RT_List.self) {
            return RT_List(rt, contents: other.contents + self.contents)
        } else {
            return RT_List(rt, contents: [other] + self.contents)
        }
    }
    
    public var length: RT_Integer {
        let count = Int64(contents.count)
        return RT_Integer(rt, value: count)
    }
    public var reverse: RT_List {
        RT_List(rt, contents: contents.reversed())
    }
    public var tail: RT_List {
        RT_List(rt, contents: [RT_Object](contents[1...]))
    }
    
    public override class var propertyKeyPaths: [Properties : AnyKeyPath] {
        [
            .Sequence_length: \RT_List.length,
            .Sequence_reverse: \RT_List.reverse,
            .Sequence_tail: \RT_List.tail
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    private func filteredContents(_ type: Reflection.`Type`) -> [RT_Object] {
        contents.filter { $0.type.isA(type) }
    }
    
    public override func element(_ type: Reflection.`Type`, at index: Int64) throws -> RT_Object {
        let filteredContents = self.filteredContents(type)
        let zeroBasedIndex = index - 1
        guard filteredContents.indices.contains(Int(zeroBasedIndex)) else {
            throw IndexOutOfBounds(index: index, container: self)
        }
        return filteredContents[Int(zeroBasedIndex)]
    }
    
    public override func element(_ type: Reflection.`Type`, at positioning: AbsolutePositioning) throws -> RT_Object {
        switch positioning {
        case .first:
            return try element(type, at: 1)
        case .middle:
            return try element(type, at: Int64(contents.count / 2))
        case .last:
            return try element(type, at: Int64(contents.count))
        case .random:
            return try element(type, at: Int64(arc4random_uniform(UInt32(contents.count)) + 1))
        }
    }
    
    public override func elements(_ type: Reflection.`Type`) throws -> RT_Object {
        return RT_List(rt, contents: filteredContents(type))
    }
    
    public override func elements(_ type: Reflection.`Type`, from: RT_Object, thru: RT_Object) throws -> RT_Object {
        let filteredContents = self.filteredContents(type)
        
        guard let fromNum = from.coerce(to: RT_Integer.self)?.value else {
            throw InvalidSpecifierDataType(specifierType: .byRange, specifierData: from)
        }
        guard let thruNum = thru.coerce(to: RT_Integer.self)?.value else {
            throw InvalidSpecifierDataType(specifierType: .byRange, specifierData: thru)
        }
        
        let zeroBasedFrom = Int(fromNum - 1)
        let zeroBasedThru = Int(thruNum - 1)
        guard
            filteredContents.indices.contains(zeroBasedFrom),
            filteredContents.indices.contains(zeroBasedThru)
        else {
            throw RangeOutOfBounds(rangeStart: from, rangeEnd: thru, container: self)
        }
        
        return RT_List(rt, contents: Array(filteredContents[zeroBasedFrom...zeroBasedThru]))
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        (other as? RT_List)
            .map { contents <=> $0.contents }
    }
    
    public override func contains(_ other: RT_Object) -> RT_Object? {
        RT_Boolean.withValue(rt, 
            contents.contains { $0.equal(to: other)?.truthy ?? false }
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for object in contents {
            guard let encodable = object as? Encodable else {
                throw Unencodable(object: object)
            }
            try encodable.encode(to: &container)
        }
    }
    
}

extension RT_List {
    
    public override var debugDescription: String {
        super.debugDescription + "[contents: \(contents)]"
    }
    
}

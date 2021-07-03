import Bushel
import AEthereal

// MARK: AppleEvent decoding
extension RT_Object {
    
    /// Decodes a runtime object from an AE `descriptor`.
    public static func decode(_ rt: Runtime, app: App, aeDescriptor descriptor: AEDescriptor) throws -> RT_Object {
        return try decode(rt, app: app, aeDecoded: try AEDecoder.decode(descriptor))
    }
    
    /// Decodes a runtime object from `value`, the result of
    /// `AEthereal.App#decode(_:)`.
    static func decode(_ rt: Runtime, app: App, aeDecoded value: AEValue) throws -> RT_Object {
        switch value {
        case let .query(query):
            return try fromQuery(rt, app: app, query: query)
        case .missingValue:
            return rt.missing
        case let .type(type):
            return RT_Type(rt, value: rt.reflection.types[.ae4(code: type.rawValue)])
        case let .enum(`enum`):
            return RT_Constant(rt, value: rt.reflection.constants[.ae4(code: `enum`.rawValue)])
        case let .bool(bool):
            return RT_Boolean.withValue(rt, bool)
        case let .int32(int32):
            return RT_Integer(rt, value: Int64(int32))
        case let .int64(int64):
            return RT_Integer(rt, value: int64)
        case let .uint64(uint64):
            return RT_Integer(rt, value: Int64(uint64))
        case let .double(double):
            return RT_Real(rt, value: double)
        case let .string(string):
            return RT_String(rt, value: string)
        case let .date(date):
            return RT_Date(rt, value: date)
        case let .list(list):
            return RT_List(rt, contents: try list.map { try decode(rt, app: app, aeDescriptor: $0) } )
        case let .record(record):
            let keysAndValues = try zip(
                record.keys,
                record.values.map {
                    try decode(rt, app: app, aeDescriptor: $0)
                }
            ).map {
                (key: RT_Constant(rt, value: rt.reflection.constants[.ae4(code: $0.0)]), value: $0.1)
            }
            let convertedDictionary = [RT_Object : RT_Object](uniqueKeysWithValues: keysAndValues)
            return RT_Record(rt, contents: convertedDictionary)
        case let .fileURL(fileURL):
            return RT_File(rt, value: fileURL)
        case let .point(point):
            return RT_List(rt, contents: [
                RT_Real(rt, value: Double(point.x)),
                RT_Real(rt, value: Double(point.y))
            ])
        case let .rect(rect):
            return RT_List(rt, contents: [
                RT_Real(rt, value: Double(rect.minX)),
                RT_Real(rt, value: Double(rect.minY)),
                RT_Real(rt, value: Double(rect.width)),
                RT_Real(rt, value: Double(rect.height))
            ])
        case let .color(color):
            return RT_List(rt, contents: [
                RT_Real(rt, value: Double(color.r)),
                RT_Real(rt, value: Double(color.g)),
                RT_Real(rt, value: Double(color.b)),
            ])
        }
    }
    
    static func fromQuery(_ rt: Runtime, app: App, query: Query) throws -> RT_Object {
        switch query {
        case let .rootSpecifier(rootSpecifier):
            switch rootSpecifier {
            case .application:
                if
                    let bundleID = app.target.bundleIdentifier,
                    let app = RT_Application(rt, id: bundleID)
                {
                    return app
                }
                return RT_RootSpecifier(rt, kind: .application)
            case .container:
                return RT_RootSpecifier(rt, kind: .container)
            case .specimen:
                return RT_RootSpecifier(rt, kind: .specimen)
            case let .object(descriptor):
                return try decode(rt, app: app, aeDescriptor: descriptor)
            }
        case let .objectSpecifier(objectSpecifier):
            let parent = try fromQuery(rt, app: app, query: objectSpecifier.parent)
            let kind: RT_Specifier.Kind = try {
                switch objectSpecifier.selectorForm {
                case let .property(property):
                    return .property(rt.reflection.properties[.ae4(code: property.rawValue)])
                case let .userProperty(userProperty):
                    return .property(rt.reflection.properties[.asid(userProperty)])
                case let .name(name):
                    return .element(RT_Specifier.Kind.Element(type: rt.reflection.types[.ae4(code: objectSpecifier.wantType.rawValue)], form: .name(RT_String(rt, value: name))))
                case let .id(id):
                    return .element(RT_Specifier.Kind.Element(type: rt.reflection.types[.ae4(code: objectSpecifier.wantType.rawValue)], form: .id(try decode(rt, app: app, aeDescriptor: id as! AEDescriptor))))
                case let .index(index):
                    return .element(RT_Specifier.Kind.Element(type: rt.reflection.types[.ae4(code: objectSpecifier.wantType.rawValue)], form: .index(RT_Integer(rt, value: index))))
                case let .absolute(absolute):
                    return .element(RT_Specifier.Kind.Element(type: rt.reflection.types[.ae4(code: objectSpecifier.wantType.rawValue)], form: {
                        switch absolute {
                        case .first:
                            return .first
                        case .last:
                            return .last
                        case .middle:
                            return .middle
                        case .random:
                            return .random
                        case .all:
                            return .all
                        }
                    }()))
                case let .relative(relative):
                    return .element(RT_Specifier.Kind.Element(type: rt.reflection.types[.ae4(code: objectSpecifier.wantType.rawValue)], form: {
                        switch relative {
                        case .next:
                            return .next
                        case .previous:
                            return .previous
                        }
                    }()))
                case let .range(range):
                    return .element(RT_Specifier.Kind.Element(type: rt.reflection.types[.ae4(code: objectSpecifier.wantType.rawValue)], form: .range(from: try decode(rt, app: app, aeDescriptor: range.start as! AEDescriptor), thru: try decode(rt, app: app, aeDescriptor: range.stop as! AEDescriptor))))
                case let .test(test):
                    return .element(RT_Specifier.Kind.Element(type: rt.reflection.types[.ae4(code: objectSpecifier.wantType.rawValue)], form: .test(try fromTestClause(rt, app: app, testClause: test))))
                }
            }()
            return RT_Specifier(rt, parent: parent, kind: kind)
        case let .insertionSpecifier(insertionSpecifier):
            let parent = try fromQuery(rt, app: app, query: insertionSpecifier.parent)
            let kind: RT_InsertionSpecifier.Kind = {
                switch insertionSpecifier.insertionLocation {
                case .beginning:
                    return .beginning
                case .end:
                    return .end
                case .before:
                    return .before
                case .after:
                    return .after
                }
            }()
            return RT_InsertionSpecifier(rt, parent: parent, kind: kind)
        }
    }
    
    static func fromTestClause(_ rt: Runtime, app: App, testClause: ObjectSpecifier.TestClause) throws -> RT_TestSpecifier {
        switch testClause {
        case let .comparison(`operator`, lhs, rhs):
            return RT_TestSpecifier(rt, operation: {
                switch `operator` {
                case .lessThan:
                    return .less
                case .lessThanEquals:
                    return .lessEqual
                case .greaterThan:
                    return .greater
                case .greaterThanEquals:
                    return .greaterEqual
                case .equals:
                    return .equal
                case .contains:
                    return .contains
                case .beginsWith:
                    return .startsWith
                case .endsWith:
                    return .endsWith
                }
            }(), lhs: try decode(rt, app: app, aeDescriptor: lhs as! AEDescriptor), rhs: try decode(rt, app: app, aeDescriptor: rhs as! AEDescriptor))
        case let .logicalBinary(`operator`, lhs, rhs):
            return RT_TestSpecifier(rt, operation: {
                switch `operator` {
                case .and:
                    return .and
                case .or:
                    return .or
                case .not:
                    // TODO: I forgot "not" existed when making RT_TestSpecifier.
                    fatalError("'not' in test clauses is unimplemented.")
                }
            }(), lhs: try fromTestClause(rt, app: app, testClause: lhs), rhs: try fromTestClause(rt, app: app, testClause: rhs))
        case let .logicalUnary(`operator`, operand):
            _ = `operator`
            _ = operand
            // TODO: I forgot "not" existed when making RT_TestSpecifier.
            fatalError("'not' in test clauses is unimplemented.")
        }
    }
    
}

extension CodingUserInfoKey {
    
    public static let rt = CodingUserInfoKey(rawValue: "BushelRT.rt")!
    
}

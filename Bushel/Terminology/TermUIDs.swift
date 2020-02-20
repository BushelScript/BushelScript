import Foundation
import InAnyCase

public protocol TermUIDPredefinedValue {
    
    var kind: TypedTermUID.Kind { get }
    var ae4Code: OSType? { get }
    var ae8Code: (class: AEEventClass, id: AEEventID)? { get }
    var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? { get }
    var idName: String? { get }
    
    init?(_ uid: TermUID)
    
}

public extension TermUIDPredefinedValue {
    
    var ae4Code: OSType? {
        nil
    }
    
    var ae8Code: (class: AEEventClass, id: AEEventID)? {
        nil
    }
    
    var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        nil
    }
    
}

extension TermUIDPredefinedValue where Self: RawRepresentable, RawValue == String {
    
    public var idName: String? {
        makeIDName(from: rawValue)
    }
    
    internal init?(idName: String) {
        self.init(rawValue: makeRawValue(from: idName))
    }
    
}

private func makeIDName(from rawValue: String) -> String {
    rawValue
        .split(separator: "_")
        .map { String($0).transformed(from: .camel, to: .space, case: $0.first!.isUppercase ? .preserve : .lower) }
        .joined(separator: ":")
}

private func makeRawValue(from idName: String) -> String {
    idName
        .split(separator: ":")
        .map { String($0).transformed(from: .space, to: .camel, case: $0.first!.isUppercase ? .preserve : .lowerUpper ) }
        .joined(separator: "_")
}

public extension TermUIDPredefinedValue {
    
    init?(_ uid: TypedTermUID) {
        self.init(uid.uid)
    }
    
}

public extension TermUID {
    
    init(_ predefined: TermUIDPredefinedValue) {
        guard
            let uid: TermUID = {
                if let aeCode = predefined.ae4Code {
                    return .ae4(code: aeCode)
                } else if let (aeClassCode, aeIDCode) = predefined.ae8Code {
                    return .ae8(class: aeClassCode, id: aeIDCode)
                } else if let (aeClassCode, aeIDCode, aeCode) = predefined.ae12Code {
                    return .ae12(class: aeClassCode, id: aeIDCode, code: aeCode)
                } else if let idName = predefined.idName {
                    return .id(idName)
                } else {
                    return nil
                }
            }()
        else {
            preconditionFailure("Predefined term UID \(predefined) has no identification method")
        }
        self = uid
    }
    
}

public extension TypedTermUID {
    
    init(_ predefined: TermUIDPredefinedValue) {
        self.init(predefined.kind, TermUID(predefined))
    }
    
}

public enum DictionaryUID: String, TermUIDPredefinedValue {
    
    case BushelScript
    case Math
    case Sequence
    case String
    case GUI
    case CLI
    
    public var kind: TypedTermUID.Kind {
        .property
    }
    
    public var idName: String? {
        // We need to bypass the default implementation for names
        // that have capital letters that do not denote word breaks.
        switch self {
        case .BushelScript:
            return "BushelScript"
        default:
            return makeIDName(from: rawValue)
        }
    }
    
    public init?(_ uid: TermUID) {
        switch uid {
        case .id(let name):
            self.init(idName: name)
        default:
            return nil
        }
    }
    
}

public enum TypeUID: String, TermUIDPredefinedValue {
    
    case item
    case list
    case record
    case constant
    case boolean
    case string
    case character
    case number
    case integer
    case real
    case date
    case window
    case document
    case file
    case alias
    case application
    case specifier
    case comparisonTestSpecifier
    case logicalTestSpecifier
    case `class`
    case null
    case global
    case script
    case function
    case system
    
    public var kind: TypedTermUID.Kind {
        .type
    }
    
    public var ae4Code: OSType? {
        switch self {
        case .item:
            return cObject
        case .list:
            return typeAEList
        case .record:
            return typeAERecord
        case .constant:
            return typeEnumerated
        case .boolean:
            return typeBoolean
        case .string:
            return typeUnicodeText
        case .character:
            return cChar
        case .number:
            return try! FourCharCode(fourByteString: "nmbr")
        case .integer:
            return typeSInt64
        case .real:
            return typeIEEE64BitFloatingPoint
        case .date:
            return typeLongDateTime
        case .window:
            return cWindow
        case .document:
            return cDocument
        case .file:
            return cFile
        case .alias:
            return typeAlias
        case .application:
            return cApplication
        case .specifier:
            return cObjectSpecifier
        case .comparisonTestSpecifier:
            return typeCompDescriptor
        case .logicalTestSpecifier:
            return typeLogicalDescriptor
        case .class:
            return typeType
        case .null:
            return try! FourCharCode(fourByteString: "msng")
        case .global, .script, .function, .system:
            return nil
        }
    }
    
    public init?(_ uid: TermUID) {
        switch uid {
        case .ae4(let aeCode):
            switch aeCode {
            case cObject:
                self = .item
            case typeAEList:
                self = .list
            case typeAERecord:
                self = .record
            case typeEnumerated:
                self = .constant
            case typeBoolean:
                self = .boolean
            case typeUnicodeText:
                self = .string
            case cChar:
                self = .character
            case try! FourCharCode(fourByteString: "nmbr"):
                self = .number
            case typeSInt64:
                self = .integer
            case typeIEEE64BitFloatingPoint:
                self = .real
            case typeLongDateTime:
                self = .date
            case cWindow:
                self = .window
            case cDocument:
                self = .document
            case cFile:
                self = .file
            case typeAlias:
                self = .alias
            case cApplication:
                self = .application
            case cObjectSpecifier:
                self = .specifier
            case typeCompDescriptor:
                self = .comparisonTestSpecifier
            case typeLogicalDescriptor:
                self = .logicalTestSpecifier
            case typeType:
                self = .class
            case try! FourCharCode(fourByteString: "msng"):
                self = .null
            default:
                return nil
            }
        case .id(let name):
            self.init(idName: name)
        default:
            return nil
        }
    }
    
}

public enum PropertyUID: String, TermUIDPredefinedValue {
    
    case properties
    case type
    case name
    case id
    case index
    
    case topScript
    
    case currentDate
    
    case Sequence_length
    case Sequence_reverse
    case Sequence_tail
    
    case file_basename
    case file_extname
    case file_dirname
    
    case date_seconds
    case date_minutes
    case date_hours
    
    case Math_pi
    case Math_e
    
    public var kind: TypedTermUID.Kind {
        .property
    }
    
    public var ae4Code: OSType? {
        switch self {
        case .properties:
            return try! FourCharCode(fourByteString: "pALL")
        case .type:
            return pClass
        case .name:
            return pName
        case .id:
            return pID
        case .index:
            return pIndex
        case .Sequence_length:
            return try! FourCharCode(fourByteString: "leng")
        case .Sequence_reverse:
            return try! FourCharCode(fourByteString: "rvse")
        case .Sequence_tail:
            return try! FourCharCode(fourByteString: "rest")
        default:
            return nil
        }
    }
    
    public init?(_ uid: TermUID) {
        switch uid {
        case .ae4(let aeCode):
            switch aeCode {
            case try! FourCharCode(fourByteString: "pALL"):
                self = .properties
            case pClass:
                self = .type
            case pName:
                self = .name
            case pID:
                self = .id
            case pIndex:
                self = .index
            case try! FourCharCode(fourByteString: "leng"):
                self = .Sequence_length
            case try! FourCharCode(fourByteString: "rvse"):
                self = .Sequence_reverse
            case try! FourCharCode(fourByteString: "rest"):
                self = .Sequence_tail
            default:
                return nil
            }
        case .id(let name):
            self.init(idName: name)
        default:
            return nil
        }
    }
    
}

public enum ConstantUID: String, TermUIDPredefinedValue {
    
    case `true`
    case `false`
    
    public var kind: TypedTermUID.Kind {
        .constant
    }
    
    public var ae4Code: OSType? {
        switch self {
        case .`true`:
            return typeTrue
        case .`false`:
            return typeFalse
        }
    }
    
    public init?(_ uid: TermUID) {
        switch uid {
        case .ae4(let aeCode):
            switch aeCode {
            case typeTrue:
                self = .true
            case typeFalse:
                self = .false
            default:
                return nil
            }
        case .id(let name):
            self.init(idName: name)
        default:
            return nil
        }
    }
    
}

public enum CommandUID: String, TermUIDPredefinedValue {
    
    case get
    case set
    
    case run
    case reopen
    case open
    case print
    case quit
    
    case delay
    
    case Math_abs
    case Math_sqrt
    case Math_cbrt
    case Math_square
    case Math_cube
    case Math_pow
    
    case Sequence_join
    
    case String_split
    
    case GUI_notification
    case GUI_alert
    case GUI_chooseFrom
    case GUI_ask
    
    case CLI_log
    
    public var kind: TypedTermUID.Kind {
        .command
    }
    
    public var ae8Code: (class: AEEventClass, id: AEEventID)? {
        switch self {
        case .get:
            return (class: kAECoreSuite, id: kAEGetData)
        case .set:
            return (class: kAECoreSuite, id: kAESetData)
        case .run:
            return (class: kCoreEventClass, id: kAEOpenApplication)
        case .reopen:
            return (class: kCoreEventClass, id: kAEReopenApplication)
        case .open:
            return (class: kCoreEventClass, id: kAEOpenDocuments)
        case .print:
            return (class: kCoreEventClass, id: kAEPrintDocuments)
        case .quit:
            return (class: kCoreEventClass, id: kAEQuitApplication)
        case .GUI_notification:
            return (class: try! FourCharCode(fourByteString: "syso"), id: try! FourCharCode(fourByteString: "notf"))
        case .GUI_alert:
            return (class: try! FourCharCode(fourByteString: "syso"), id: try! FourCharCode(fourByteString: "disA"))
        case .GUI_chooseFrom:
            return (class: try! FourCharCode(fourByteString: "gtqp"), id: try! FourCharCode(fourByteString: "chlt"))
        case .GUI_ask:
            return (class: try! FourCharCode(fourByteString: "bShG"), id: try! FourCharCode(fourByteString: "ask "))
        default:
            return nil
        }
    }
    
    public init?(_ uid: TermUID) {
        switch uid {
        case .ae8(let aeCodes):
            switch aeCodes {
            case (class: kAECoreSuite, id: kAEGetData):
                self = .get
            case (class: kAECoreSuite, id: kAESetData):
                self = .set
            case (class: kCoreEventClass, id: kAEOpenApplication):
                self = .run
            case (class: kCoreEventClass, id: kAEReopenApplication):
                self = .reopen
            case (class: kCoreEventClass, id: kAEOpenDocuments):
                self = .open
            case (class: kCoreEventClass, id: kAEPrintDocuments):
                self = .print
            case (class: kCoreEventClass, id: kAEQuitApplication):
                self = .quit
            case (class: try! FourCharCode(fourByteString: "syso"), id: try! FourCharCode(fourByteString: "notf")):
                self = .GUI_notification
            case (class: try! FourCharCode(fourByteString: "syso"), id: try! FourCharCode(fourByteString: "disA")):
                self = .GUI_alert
            case (class: try! FourCharCode(fourByteString: "gtqp"), id: try! FourCharCode(fourByteString: "chlt")):
                self = .GUI_chooseFrom
            case (class: try! FourCharCode(fourByteString: "bShG"), id: try! FourCharCode(fourByteString: "ask ")):
                self = .GUI_ask
            default:
                return nil
            }
        case .id(let name):
            self.init(idName: name)
        default:
            return nil
        }
    }
    
}

public enum ParameterUID: String, TermUIDPredefinedValue {
    
    case direct = "/direct"
    case set_to
    case open_searchText
    
    case Math_pow_exponent
    
    case Sequence_join_with
    
    case String_split_by
    
    case GUI_notification_title
    case GUI_notification_subtitle
    case GUI_notification_sound
    case GUI_alert_message
    case GUI_alert_kind
    case GUI_alert_buttons
    case GUI_alert_default
    case GUI_alert_cancel
    case GUI_alert_timeout
    case GUI_chooseFrom_title
    case GUI_chooseFrom_prompt
    case GUI_chooseFrom_default
    case GUI_chooseFrom_confirm
    case GUI_chooseFrom_cancel
    case GUI_chooseFrom_multipleSelection
    case GUI_chooseFrom_noSelection
    case GUI_ask_dataType
    case GUI_ask_title
    
    public var kind: TypedTermUID.Kind {
        .parameter
    }
    
    public var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        guard
            let commandAndCode: (command: CommandUID, code: AEKeyword) = {
                switch self {
                case .set_to:
                    return (.set, keyAEData)
                case .open_searchText:
                    return (.open, keyAESearchText)
                case .GUI_notification_title:
                    return (.GUI_notification, try! FourCharCode(fourByteString: "appr"))
                case .GUI_notification_subtitle:
                    return (.GUI_notification, try! FourCharCode(fourByteString: "subt"))
                case .GUI_notification_sound:
                    return (.GUI_notification, try! FourCharCode(fourByteString: "nsou"))
                case .GUI_alert_message:
                    return (.GUI_alert, try! FourCharCode(fourByteString: "mesS"))
                case .GUI_alert_kind:
                    return (.GUI_alert, try! FourCharCode(fourByteString: "EAlT"))
                case .GUI_alert_buttons:
                    return (.GUI_alert, try! FourCharCode(fourByteString: "btns"))
                case .GUI_alert_default:
                    return (.GUI_alert, try! FourCharCode(fourByteString: "dflt"))
                case .GUI_alert_cancel:
                    return (.GUI_alert, try! FourCharCode(fourByteString: "cbtn"))
                case .GUI_alert_timeout:
                    return (.GUI_alert, try! FourCharCode(fourByteString: "givu"))
                case .GUI_chooseFrom_title:
                    return (.GUI_chooseFrom, try! FourCharCode(fourByteString: "appr"))
                case .GUI_chooseFrom_prompt:
                    return (.GUI_chooseFrom, try! FourCharCode(fourByteString: "prmp"))
                case .GUI_chooseFrom_default:
                    return (.GUI_chooseFrom, try! FourCharCode(fourByteString: "inSL"))
                case .GUI_chooseFrom_confirm:
                    return (.GUI_chooseFrom, try! FourCharCode(fourByteString: "okbt"))
                case .GUI_chooseFrom_cancel:
                    return (.GUI_chooseFrom, try! FourCharCode(fourByteString: "cnbt"))
                case .GUI_chooseFrom_multipleSelection:
                    return (.GUI_chooseFrom, try! FourCharCode(fourByteString: "mlsl"))
                case .GUI_chooseFrom_noSelection:
                    return (.GUI_chooseFrom, try! FourCharCode(fourByteString: "empL"))
                case .GUI_ask_dataType:
                    return (.GUI_ask, try! FourCharCode(fourByteString: "forT"))
                case .GUI_ask_title:
                    return (.GUI_ask, try! FourCharCode(fourByteString: "titl"))
                default:
                    return nil
                }
            }(),
            let (`class`, id) = commandAndCode.command.ae8Code
        else {
            return nil
        }
        return (class: `class`, id: id, code: commandAndCode.code)
    }
    
    public init?(_ uid: TermUID) {
        switch uid {
        case .ae4(let aeCode):
            switch aeCode {
            case keyDirectObject:
                self = .direct
            default:
                return nil
            }
        case .ae12(let aeCodes):
            if aeCodes.code == keyDirectObject {
                self = .direct
                return
            }
            switch (CommandUID(TermUID.ae8(class: aeCodes.class, id: aeCodes.id)), aeCodes.code) {
            case (.set, keyAEData):
                self = .set_to
            case (.open, keyAESearchText):
                self = .open_searchText
            case (.GUI_notification, try! FourCharCode(fourByteString: "appr")):
                self = .GUI_notification_title
            case (.GUI_notification, try! FourCharCode(fourByteString: "subt")):
                self = .GUI_notification_subtitle
            case (.GUI_notification, try! FourCharCode(fourByteString: "nsou")):
                self = .GUI_notification_sound
            case (.GUI_alert, try! FourCharCode(fourByteString: "mesS")):
                self = .GUI_alert_message
            case (.GUI_alert, try! FourCharCode(fourByteString: "EAlT")):
                self = .GUI_alert_kind
            case (.GUI_alert, try! FourCharCode(fourByteString: "btns")):
                self = .GUI_alert_buttons
            case (.GUI_alert, try! FourCharCode(fourByteString: "dflt")):
                self = .GUI_alert_default
            case (.GUI_alert, try! FourCharCode(fourByteString: "cbtn")):
                self = .GUI_alert_cancel
            case (.GUI_alert, try! FourCharCode(fourByteString: "givu")):
                self = .GUI_alert_timeout
            case (.GUI_chooseFrom, try! FourCharCode(fourByteString: "appr")):
                self = .GUI_chooseFrom_title
            case (.GUI_chooseFrom, try! FourCharCode(fourByteString: "prmp")):
                self = .GUI_chooseFrom_prompt
            case (.GUI_chooseFrom, try! FourCharCode(fourByteString: "inSL")):
                self = .GUI_chooseFrom_default
            case (.GUI_chooseFrom, try! FourCharCode(fourByteString: "okbt")):
                self = .GUI_chooseFrom_confirm
            case (.GUI_chooseFrom, try! FourCharCode(fourByteString: "cnbt")):
                self = .GUI_chooseFrom_cancel
            case (.GUI_chooseFrom, try! FourCharCode(fourByteString: "mlsl")):
                self = .GUI_chooseFrom_multipleSelection
            case (.GUI_chooseFrom, try! FourCharCode(fourByteString: "empL")):
                self = .GUI_chooseFrom_noSelection
            case (.GUI_ask, try! FourCharCode(fourByteString: "forT")):
                self = .GUI_ask_dataType
            case (.GUI_ask, try! FourCharCode(fourByteString: "titl")):
                self = .GUI_ask_title
            default:
                return nil
            }
        case .id(let name):
            self.init(idName: name)
        default:
            return nil
        }
    }
    
}

public enum ResourceUID: String, TermUIDPredefinedValue {
    
    case system
    
    public var kind: TypedTermUID.Kind {
        .resource
    }
    
    public init?(_ uid: TermUID) {
        switch uid {
        case .id(let name):
            self.init(idName: name)
        default:
            return nil
        }
    }
    
}

import Foundation
import InAnyCase

// MARK: Definition
extension Term {
    
    public typealias PredefinedID = Term_PredefinedID
    
}

public protocol Term_PredefinedID {
    
    var role: Term.SyntacticRole { get }
    var ae4Code: OSType? { get }
    var ae8Code: (class: AEEventClass, id: AEEventID)? { get }
    var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? { get }
    var pathname: Term.SemanticURI.Pathname? { get }
    var resourceName: String? { get }
    
    init?(_ uri: Term.SemanticURI)
    
}

public extension Term.PredefinedID {
    
    var ae4Code: OSType? {
        nil
    }
    
    var ae8Code: (class: AEEventClass, id: AEEventID)? {
        nil
    }
    
    var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        nil
    }
    
    var resourceName: String? {
        nil
    }
    
}

extension Term.PredefinedID where Self: RawRepresentable, RawValue == String {
    
    public var pathname: Term.SemanticURI.Pathname? {
        makePathname(from: rawValue)
    }
    
    internal init?(pathname: Term.SemanticURI.Pathname) {
        self.init(rawValue: makeRawValue(from: pathname))
    }
    
    public var resourceName: String {
        rawValue
    }
    
    internal init?(resourceName: String) {
        self.init(rawValue: resourceName)
    }
    
}

private func makePathname(from rawValue: String) -> Term.SemanticURI.Pathname {
    Term.SemanticURI.Pathname(
        rawValue
            .split(separator: "_")
            .map { String($0).transformed(from: .camel, to: .space, case: $0.first!.isUppercase ? .preserve : .lower) }
    )
}

private func makeRawValue(from pathname: Term.SemanticURI.Pathname) -> String {
    pathname
        .components
        .map { String($0).transformed(from: .space, to: .camel, case: $0.first!.isUppercase ? .preserve : .lowerUpper ) }
        .joined(separator: "_")
}

public extension Term.PredefinedID {
    
    init?(_ id: Term.ID) {
        self.init(id.uri)
    }
    
}

public extension Term.SemanticURI {
    
    init(_ predefined: Term.PredefinedID) {
        guard
            let uri: Term.SemanticURI = {
                if let aeCode = predefined.ae4Code {
                    return .ae4(code: aeCode)
                } else if let (aeClassCode, aeIDCode) = predefined.ae8Code {
                    return .ae8(class: aeClassCode, id: aeIDCode)
                } else if let (aeClassCode, aeIDCode, aeCode) = predefined.ae12Code {
                    return .ae12(class: aeClassCode, id: aeIDCode, code: aeCode)
                } else if predefined.role == .resource, let resourceName = predefined.resourceName {
                    return .res(resourceName)
                } else if let pathname = predefined.pathname {
                    return .id(pathname)
                } else {
                    return nil
                }
            }()
        else {
            preconditionFailure("Predefined term URI \(predefined) has no valid identification method")
        }
        self = uri
    }
    
}

public extension Term.ID {
    
    init(_ predefined: Term.PredefinedID) {
        self.init(predefined.role, Term.SemanticURI(predefined))
    }
    
}

public enum Variables: String, Term.PredefinedID {
    
    case Script = ""
    case Core
    
    public var role: Term.SyntacticRole {
        .variable
    }
    
    public init?(_ uri: Term.SemanticURI) {
        switch uri {
        case .id(let pathname):
            self.init(pathname: pathname)
        default:
            return nil
        }
    }
    
}

public enum Types: String, Term.PredefinedID {
    
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
    case specifier
    case comparisonTestSpecifier
    case logicalTestSpecifier
    case type
    case null
    case unspecified
    case coreObject
    case script
    case app
    case applescript
    case function
    case system
    case error
    case environmentVariable
    
    public var role: Term.SyntacticRole {
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
        case .specifier:
            return cObjectSpecifier
        case .comparisonTestSpecifier:
            return typeCompDescriptor
        case .logicalTestSpecifier:
            return typeLogicalDescriptor
        case .type:
            // AppleScript uses this as a type.
            // AppleScript is weird.
            return pClass
        case .null:
            return try! FourCharCode(fourByteString: "msng")
        case .app:
            return cApplication
        default:
            return nil
        }
    }
    
    public init?(_ uri: Term.SemanticURI) {
        switch uri {
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
                self = .app
            case cObjectSpecifier:
                self = .specifier
            case typeCompDescriptor:
                self = .comparisonTestSpecifier
            case typeLogicalDescriptor:
                self = .logicalTestSpecifier
            case typeType:
                self = .type
            case try! FourCharCode(fourByteString: "msng"):
                self = .null
            default:
                return nil
            }
        case .id(let pathname):
            self.init(pathname: pathname)
        default:
            return nil
        }
    }
    
}

public enum Properties: String, Term.PredefinedID {
    
    case properties
    case type
    case name
    case id
    case index
    
    case topScript
    case arguments
    
    case currentDate
    
    case list_length
    case list_reverse
    case list_tail
    
    case record_keys
    case record_values
    
    case file_basename
    case file_extname
    case file_dirname
    
    case date_seconds
    case date_minutes
    case date_hours
    case date_secondsSinceMidnight
    
    case real_NaN
    case real_inf
    case real_NaN_Q = "real_NaN?"
    case real_inf_Q = "real_inf?"
    case real_finite_Q = "real_finite?"
    case real_normal_Q = "real_normal?"
    case real_zero_Q = "real_zero?"
    case real_pi
    case real_e
    
    case environmentVariable_value
    
    case buttonReturned
    
    public var role: Term.SyntacticRole {
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
        case .list_length:
            return try! FourCharCode(fourByteString: "leng")
        case .list_reverse:
            return try! FourCharCode(fourByteString: "rvse")
        case .list_tail:
            return try! FourCharCode(fourByteString: "rest")
        case .environmentVariable_value:
            return try! FourCharCode(fourByteString: "valL")
        case .buttonReturned:
            return try! FourCharCode(fourByteString: "bhit")
        default:
            return nil
        }
    }
    
    public init?(_ uri: Term.SemanticURI) {
        switch uri {
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
                self = .list_length
            case try! FourCharCode(fourByteString: "rvse"):
                self = .list_reverse
            case try! FourCharCode(fourByteString: "rest"):
                self = .list_tail
            case try! FourCharCode(fourByteString: "valL"):
                self = .environmentVariable_value
            default:
                return nil
            }
        case .id(let pathname):
            self.init(pathname: pathname)
        default:
            return nil
        }
    }
    
}

public enum Constants: String, Term.PredefinedID {
    
    case function
    
    case `true`
    case `false`
    
    public var role: Term.SyntacticRole {
        .constant
    }
    
    public var ae4Code: OSType? {
        switch self {
        case .`true`:
            return typeTrue
        case .`false`:
            return typeFalse
        default:
            return nil
        }
    }
    
    public init?(_ uri: Term.SemanticURI) {
        switch uri {
        case .ae4(let aeCode):
            switch aeCode {
            case typeTrue:
                self = .true
            case typeFalse:
                self = .false
            default:
                return nil
            }
        case .id(let pathname):
            self.init(pathname: pathname)
        default:
            return nil
        }
    }
    
}

public enum Commands: String, Term.PredefinedID {
    
    case not
    case negate
    
    case or, xor
    case and
    case isA, isNotA
    case equal = "=", notEqual = "≠", less = "<", lessEqual = "≤", greater = ">", greaterEqual = "≥", startsWith, endsWith, contains, notContains, containedBy, notContainedBy
    case concatenate
    case add = "+", subtract = "-"
    case multiply = "✕", divide = "÷"
    case coerce
    
    case get
    case set
    
    case run
    case reopen
    case open
    case print
    case quit
    
    case delay
    
    case real_abs
    case real_sqrt
    case real_cbrt
    case real_pow
    case real_ln
    case real_log10
    case real_log2
    case real_sin
    case real_cos
    case real_tan
    case real_asin
    case real_acos
    case real_atan
    case real_atan2
    case real_round
    case real_ceil
    case real_floor
    
    case list_add
    case list_remove
    case list_pluck
    
    case notification
    case alert
    case chooseFrom
    case ask
    
    case log
    
    public var role: Term.SyntacticRole {
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
        case .notification:
            return (class: try! FourCharCode(fourByteString: "bShG"), id: try! FourCharCode(fourByteString: "notf"))
        case .alert:
            return (class: try! FourCharCode(fourByteString: "bShG"), id: try! FourCharCode(fourByteString: "disA"))
        case .chooseFrom:
            return (class: try! FourCharCode(fourByteString: "bShG"), id: try! FourCharCode(fourByteString: "chlt"))
        case .ask:
            return (class: try! FourCharCode(fourByteString: "bShG"), id: try! FourCharCode(fourByteString: "ask "))
        default:
            return nil
        }
    }
    
    public init?(_ uri: Term.SemanticURI) {
        switch uri {
        case .ae8(let `class`, let id):
            switch (`class`, id) {
            case (kAECoreSuite, kAEGetData):
                self = .get
            case (kAECoreSuite, kAESetData):
                self = .set
            case (kCoreEventClass, kAEOpenApplication):
                self = .run
            case (kCoreEventClass, kAEReopenApplication):
                self = .reopen
            case (kCoreEventClass, kAEOpenDocuments):
                self = .open
            case (kCoreEventClass, kAEPrintDocuments):
                self = .print
            case (kCoreEventClass, kAEQuitApplication):
                self = .quit
            case (try! FourCharCode(fourByteString: "bShG"), try! FourCharCode(fourByteString: "notf")):
                self = .notification
            case (try! FourCharCode(fourByteString: "syso"), try! FourCharCode(fourByteString: "disA")):
                self = .alert
            case (try! FourCharCode(fourByteString: "gtqp"), try! FourCharCode(fourByteString: "chlt")):
                self = .chooseFrom
            case (try! FourCharCode(fourByteString: "bShG"), try! FourCharCode(fourByteString: "ask ")):
                self = .ask
            default:
                return nil
            }
        case .id(let pathname):
            self.init(pathname: pathname)
        default:
            return nil
        }
    }
    
}

public enum Parameters: String, Term.PredefinedID {
    
    case direct = ".direct"
    case target = ".target"
    case lhs = ".lhs"
    case rhs = ".rhs"
    case set_to
    case open_searchText
    
    case real_pow_exponent
    case real_atan2_x
    
    case notification_title
    case notification_subtitle
    case notification_sound
    case alert_title
    case alert_message
    case alert_kind
    case alert_buttons
    case alert_default
    case alert_cancel
    case alert_timeout
    case chooseFrom_title
    case chooseFrom_prompt
    case chooseFrom_default
    case chooseFrom_confirm
    case chooseFrom_cancel
    case chooseFrom_multipleSelection
    case chooseFrom_noSelection
    case ask_dataType
    case ask_title
    
    public var role: Term.SyntacticRole {
        .parameter
    }
    
    public var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        guard
            let commandAndCode: (command: Commands, code: AEKeyword) = {
                switch self {
                case .set_to:
                    return (.set, keyAEData)
                case .open_searchText:
                    return (.open, keyAESearchText)
                case .notification_title:
                    return (.notification, try! FourCharCode(fourByteString: "appr"))
                case .notification_subtitle:
                    return (.notification, try! FourCharCode(fourByteString: "subt"))
                case .notification_sound:
                    return (.notification, try! FourCharCode(fourByteString: "nsou"))
                case .alert_title:
                    return (.alert, try! FourCharCode(fourByteString: "appr"))
                case .alert_message:
                    return (.alert, try! FourCharCode(fourByteString: "mesS"))
                case .alert_kind:
                    return (.alert, try! FourCharCode(fourByteString: "EAlT"))
                case .alert_buttons:
                    return (.alert, try! FourCharCode(fourByteString: "btns"))
                case .alert_default:
                    return (.alert, try! FourCharCode(fourByteString: "dflt"))
                case .alert_cancel:
                    return (.alert, try! FourCharCode(fourByteString: "cbtn"))
                case .alert_timeout:
                    return (.alert, try! FourCharCode(fourByteString: "givu"))
                case .chooseFrom_title:
                    return (.chooseFrom, try! FourCharCode(fourByteString: "appr"))
                case .chooseFrom_prompt:
                    return (.chooseFrom, try! FourCharCode(fourByteString: "prmp"))
                case .chooseFrom_default:
                    return (.chooseFrom, try! FourCharCode(fourByteString: "inSL"))
                case .chooseFrom_confirm:
                    return (.chooseFrom, try! FourCharCode(fourByteString: "okbt"))
                case .chooseFrom_cancel:
                    return (.chooseFrom, try! FourCharCode(fourByteString: "cnbt"))
                case .chooseFrom_multipleSelection:
                    return (.chooseFrom, try! FourCharCode(fourByteString: "mlsl"))
                case .chooseFrom_noSelection:
                    return (.chooseFrom, try! FourCharCode(fourByteString: "empL"))
                case .ask_dataType:
                    return (.ask, try! FourCharCode(fourByteString: "forT"))
                case .ask_title:
                    return (.ask, try! FourCharCode(fourByteString: "appr"))
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
    
    public init?(_ uri: Term.SemanticURI) {
        switch uri {
        case .ae4(let aeCode):
            switch aeCode {
            case keyDirectObject:
                self = .direct
            default:
                return nil
            }
        case .ae12(let `class`, let id, let code):
            if code == keyDirectObject {
                self = .direct
                return
            }
            switch (Commands(.ae8(class: `class`, id: id)), code) {
            case (.set, keyAEData):
                self = .set_to
            case (.open, keyAESearchText):
                self = .open_searchText
            case (.notification, try! FourCharCode(fourByteString: "appr")):
                self = .notification_title
            case (.notification, try! FourCharCode(fourByteString: "subt")):
                self = .notification_subtitle
            case (.notification, try! FourCharCode(fourByteString: "nsou")):
                self = .notification_sound
            case (.alert, try! FourCharCode(fourByteString: "appr")):
                self = .alert_title
            case (.alert, try! FourCharCode(fourByteString: "mesS")):
                self = .alert_message
            case (.alert, try! FourCharCode(fourByteString: "EAlT")):
                self = .alert_kind
            case (.alert, try! FourCharCode(fourByteString: "btns")):
                self = .alert_buttons
            case (.alert, try! FourCharCode(fourByteString: "dflt")):
                self = .alert_default
            case (.alert, try! FourCharCode(fourByteString: "cbtn")):
                self = .alert_cancel
            case (.alert, try! FourCharCode(fourByteString: "givu")):
                self = .alert_timeout
            case (.chooseFrom, try! FourCharCode(fourByteString: "appr")):
                self = .chooseFrom_title
            case (.chooseFrom, try! FourCharCode(fourByteString: "prmp")):
                self = .chooseFrom_prompt
            case (.chooseFrom, try! FourCharCode(fourByteString: "inSL")):
                self = .chooseFrom_default
            case (.chooseFrom, try! FourCharCode(fourByteString: "okbt")):
                self = .chooseFrom_confirm
            case (.chooseFrom, try! FourCharCode(fourByteString: "cnbt")):
                self = .chooseFrom_cancel
            case (.chooseFrom, try! FourCharCode(fourByteString: "mlsl")):
                self = .chooseFrom_multipleSelection
            case (.chooseFrom, try! FourCharCode(fourByteString: "empL")):
                self = .chooseFrom_noSelection
            case (.ask, try! FourCharCode(fourByteString: "forT")):
                self = .ask_dataType
            case (.ask, try! FourCharCode(fourByteString: "titl")):
                self = .ask_title
            default:
                return nil
            }
        case .id(let pathname):
            self.init(pathname: pathname)
        default:
            return nil
        }
    }
    
}

public enum Resources: String, Term.PredefinedID {
    
    case system
    
    public var role: Term.SyntacticRole {
        .resource
    }
    
    public var resourceName: String? {
        rawValue
    }
    
    public init?(_ uri: Term.SemanticURI) {
        switch uri {
        case .res(let resourceName):
            self.init(resourceName: resourceName)
        default:
            return nil
        }
    }
    
}

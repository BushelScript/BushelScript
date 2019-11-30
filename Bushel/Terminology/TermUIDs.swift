import Foundation

public protocol TermUIDPredefinedValue {
    
    var rawValue: String { get }
    var aeCode: OSType? { get }
    var aeDoubleCode: (class: AEEventClass, id: AEEventID)? { get }
    
}

public extension TermUIDPredefinedValue {
    
    var aeCode: OSType? {
        nil
    }
    
    var aeDoubleCode: (class: AEEventClass, id: AEEventID)? {
        nil
    }
    
}

public enum TypeUID: String, TermUIDPredefinedValue {
    
    case item = "bushel.type.item"
    case list = "bushel.type.list"
    case record = "bushel.type.record"
    case constant = "bushel.type.constant"
    case boolean = "bushel.type.boolean"
    case string = "bushel.type.string"
    case character = "bushel.type.character"
    case number = "bushel.type.number"
    case integer = "bushel.type.integer"
    case real = "bushel.type.real"
    case date = "bushel.type.date"
    case window = "bushel.type.window"
    case document = "bushel.type.document"
    case file = "bushel.type.file"
    case alias = "bushel.type.alias"
    case application = "bushel.type.application"
    case specifier = "bushel.type.specifier"
    case `class` = "bushel.type.class"
    case null = "bushel.type.null"
    case global = "bushel.type.global"
    
    public var aeCode: OSType? {
        switch self {
        case .item:
            return cItem
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
        case .class:
            return typeType
        case .null:
            return try! FourCharCode(fourByteString: "msng")
        case .global:
            return nil
        }
    }
    
}

public enum PropertyUID: String, TermUIDPredefinedValue {
    
    case properties = "bushel.property.properties"
    case name = "bushel.property.name"
    case id = "bushel.property.id"
    case index = "bushel.property.index"
    
    case currentDate = "bushel.property.currentDate"
    
    case sequence_length = "bushel.sequence.property.length"
    case sequence_reverse = "bushel.sequence.property.reverse"
    case sequence_tail = "bushel.sequence.property.tail"
    
    case date_seconds = "bushel.date.property.seconds"
    case date_minutes = "bushel.date.property.minutes"
    case date_hours = "bushel.date.property.hours"
    
    case math_pi = "bushel.math.property.pi"
    case math_e = "bushel.math.property.e"
    
    public var aeCode: OSType? {
        switch self {
        case .properties:
            return try! FourCharCode(fourByteString: "pALL")
        case .name:
            return pName
        case .id:
            return pID
        case .index:
            return pIndex
        case .sequence_length:
            return try! FourCharCode(fourByteString: "leng")
        case .sequence_reverse:
            return try! FourCharCode(fourByteString: "rvse")
        case .sequence_tail:
            return try! FourCharCode(fourByteString: "rest")
        default:
            return nil
        }
    }
    
}

public enum ConstantUID: String, TermUIDPredefinedValue {
    
    case `true` = "bushel.constant.true"
    case `false` = "bushel.constant.false"
    
    public var aeCode: OSType? {
        switch self {
        case .`true`:
            return OSType(1)
        case .`false`:
            return OSType(0)
        }
    }
    
}

public enum CommandUID: String, TermUIDPredefinedValue {
    
    case get = "bushel.command.get"
    case set = "bushel.command.set"
    
    case run = "bushel.command.run"
    case reopen = "bushel.command.reopen"
    case open = "bushel.command.open"
    case print = "bushel.command.print"
    case quit = "bushel.command.quit"
    
    case math_abs = "bushel.math.command.abs"
    case math_sqrt = "bushel.math.command.sqrt"
    case math_cbrt = "bushel.math.command.cbrt"
    case math_square = "bushel.math.command.square"
    case math_cube = "bushel.math.command.cube"
    case math_pow = "bushel.math.command.pow"
    
    case gui_notification = "bushel.gui.command.notification"
    case gui_alert = "bushel.gui.command.alert"
    
    case cli_log = "bushel.cli.command.log"
    
    public var aeDoubleCode: (class: AEEventClass, id: AEEventID)? {
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
//        case .math_abs:
//            return (class: try! FourCharCode(fourByteString: "BMAT"), id: try! FourCharCode(fourByteString: "abs "))
//        case .math_sqrt:
//            return (class: try! FourCharCode(fourByteString: "BMAT"), id: try! FourCharCode(fourByteString: "sqrt"))
//        case .math_cbrt:
//            return (class: try! FourCharCode(fourByteString: "BMAT"), id: try! FourCharCode(fourByteString: "cbrt"))
//        case .math_square:
//            return (class: try! FourCharCode(fourByteString: "BMAT"), id: try! FourCharCode(fourByteString: "squr"))
//        case .math_cube:
//            return (class: try! FourCharCode(fourByteString: "BMAT"), id: try! FourCharCode(fourByteString: "cube"))
//        case .math_pow:
//            return (class: try! FourCharCode(fourByteString: "BMAT"), id: try! FourCharCode(fourByteString: "powr"))
        case .gui_notification:
            return (class: try! FourCharCode(fourByteString: "syso"), id: try! FourCharCode(fourByteString: "notf"))
        case .gui_alert:
            return (class: try! FourCharCode(fourByteString: "syso"), id: try! FourCharCode(fourByteString: "disA"))
//        case .cli_log:
//            return (class: try! FourCharCode(fourByteString: "BCLI"), id: try! FourCharCode(fourByteString: "log "))
        default:
            return nil
        }
    }
    
}

public enum ParameterUID: String, TermUIDPredefinedValue {
    
    case direct = "bushel.parameter.direct"
    case set_to = "bushel.parameter.set.to"
    case open_searchText = "bushel.parameter.open.searchText"
    
    case math_pow_exponent = "bushel.math.parameter.pow.exponent"
    
    case gui_notification_title = "bushel.gui.parameter.notification.title"
    case gui_notification_subtitle = "bushel.gui.parameter.notification.subtitle"
    case gui_notification_sound = "bushel.gui.parameter.notification.sound"
    case gui_alert_message = "bushel.gui.parameter.alert.message"
    case gui_alert_kind = "bushel.gui.parameter.alert.kind"
    case gui_alert_buttons = "bushel.gui.parameter.alert.buttons"
    case gui_alert_default = "bushel.gui.parameter.alert.default"
    case gui_alert_cancel = "bushel.gui.parameter.alert.cancel"
    case gui_alert_timeout = "bushel.gui.parameter.alert.timeout"
    
    public var aeCode: OSType? {
        switch self {
        case .direct:
            return keyDirectObject
        case .set_to:
            return keyAEData
        case .open_searchText:
            return keyAESearchText
        case .math_pow_exponent:
            return try! FourCharCode(fourByteString: "expo")
        case .gui_notification_title:
            return try! FourCharCode(fourByteString: "appr")
        case .gui_notification_subtitle:
            return try! FourCharCode(fourByteString: "subt")
        case .gui_notification_sound:
            return try! FourCharCode(fourByteString: "nsou")
        case .gui_alert_message:
            return try! FourCharCode(fourByteString: "mesS")
        case .gui_alert_kind:
            return try! FourCharCode(fourByteString: "EAlT")
        case .gui_alert_buttons:
            return try! FourCharCode(fourByteString: "btns")
        case .gui_alert_default:
            return try! FourCharCode(fourByteString: "dflt")
        case .gui_alert_cancel:
            return try! FourCharCode(fourByteString: "cbtn")
        case .gui_alert_timeout:
            return try! FourCharCode(fourByteString: "givu")
        }
    }
    
}

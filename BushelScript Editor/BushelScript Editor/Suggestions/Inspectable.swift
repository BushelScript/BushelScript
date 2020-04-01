// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa
import BushelLanguageServiceConnectionCreation
import KVODelegate

@objc protocol ObjectInspectable: NSObjectProtocol, NSCopying {
    
    var typeIdentifier: String { get }
    var localizedTypeName: String { get }
    
}

@objc protocol SuggestionListItem: ObjectInspectable {
    
    var iconImage: NSImage { get }
    var isLargeItem: Bool { get }
    
}

class NoSelection: NSObject, ObjectInspectable {
    
    func copy(with zone: NSZone? = nil) -> Any {
        return self
    }
    
    @objc var typeIdentifier: String {
        return "noSelection"
    }
    
    @objc var localizedTypeName: String {
        return ""
    }
    
}

class ErrorSuggestionListItem: NSObject, SuggestionListItem {
    
    let error: Error
    
    init(error: Error) {
        self.error = error
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return ErrorSuggestionListItem(error: error)
    }
    
    override var description: String {
        return error.localizedDescription
    }
    
    var iconImage: NSImage {
        return NSImage(size: .zero)
    }
    
    var isLargeItem: Bool {
        return true
    }
    
    var typeIdentifier: String {
        return "error"
    }
    
    var localizedTypeName: String {
        return "Error message description"
    }
    
    
}

class AutoFixSuggestionListItem: NSObject, SuggestionListItem {
    
    let service: BushelLanguageServiceProtocol
    let fix: SourceFixToken
    let source: Substring
    
    @objc dynamic var fixDescription: String? = nil
    
    init(service: BushelLanguageServiceProtocol, fix: SourceFixToken, source: Substring) {
        _ = AutoFixSuggestionListItem.notificationDelegate
        self.service = service
        self.fix = fix
        self.source = source
        super.init()
        
        service.copySimpleDescriptions(inSource: String(source), fromFixes: [fix]) { descriptions in
            self.fixDescription = descriptions[0]
        }
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return AutoFixSuggestionListItem(service: service, fix: fix, source: source)
    }
    
    override var description: String {
        return (fixDescription ?? "(loading…)").replacingOccurrences(of: "\n", with: "[line break]")
    }
    
    var iconImage: NSImage {
        return NSImage(named: NSImage.actionTemplateName)!
    }
    
    var isLargeItem: Bool {
        return false
    }
    
    var typeIdentifier: String {
        return "fix"
    }
    
    var localizedTypeName: String {
        return "Auto-fix suggestion"
    }
    
}

extension AutoFixSuggestionListItem: KVONotificationDelegator {
    
    private static var notificationDelegate = KVONotificationDelegate(forClass: AutoFixSuggestionListItem.self)
    
    static func configKVONotificationDelegate(_ delegate: KVONotificationDelegate) {
        delegate.key(#keyPath(AutoFixSuggestionListItem.description), dependsUponKeyPath: #keyPath(AutoFixSuggestionListItem.fixDescription))
    }
    
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        notificationDelegate.keyPathsForValuesAffectingValue(forKey: key)
    }
    
}

class BushelExpression: NSObject, ObjectInspectable {
    
    let service: BushelLanguageServiceProtocol
    let expression: ExpressionToken
    
    @objc dynamic var kindName: String?
    @objc dynamic var kindDescription: String?
    
    init(service: BushelLanguageServiceProtocol, expression: ExpressionToken) {
        self.service = service
        self.expression = expression
        super.init()
        service.copyKindName(forExpression: expression) { (kindName) in
            DispatchQueue.main.async {
                self.kindName = kindName
            }
        }
        service.copyKindDescription(forExpression: expression) { (kindDescription) in
            DispatchQueue.main.async {
                self.kindDescription = kindDescription
            }
        }
    }
    
    deinit {
        service.releaseExpression(expression, reply: { _ in })
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        BushelExpression(service: service, expression: expression)
    }
    
    var typeIdentifier: String {
        "expression"
    }
    
    var localizedTypeName: String {
        "Expression"
    }
    
}

class BushelRTObject: NSObject, ObjectInspectable {
    
    let service: BushelLanguageServiceProtocol
    let object: RTObjectToken
    
    @objc dynamic var objectDescription: String?
    
    init(service: BushelLanguageServiceProtocol, object: RTObjectToken) {
        _ = BushelRTObject.notificationDelegate
        self.service = service
        self.object = object
        super.init()
        service.copyDescription(for: object) { (objectDescription) in
            DispatchQueue.main.async {
                self.objectDescription = objectDescription
            }
        }
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return BushelRTObject(service: service, object: object)
    }
    
    override var description: String {
        return objectDescription ?? "(loading…)"
    }
    
    var typeIdentifier: String {
        return "object"
    }
    
    var localizedTypeName: String {
        return "Object"
    }
    
}

extension BushelRTObject: KVONotificationDelegator {
    
    private static var notificationDelegate = KVONotificationDelegate(forClass: BushelRTObject.self)
    
    static func configKVONotificationDelegate(_ delegate: KVONotificationDelegate) {
        delegate.key(#keyPath(BushelRTObject.description), dependsUponKeyPath: #keyPath(BushelRTObject.objectDescription))
    }
    
    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        notificationDelegate.keyPathsForValuesAffectingValue(forKey: key)
    }
    
}

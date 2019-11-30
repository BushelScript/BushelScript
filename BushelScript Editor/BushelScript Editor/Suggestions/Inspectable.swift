//
//  Inspectable.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 25-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa
import BushelLanguageServiceConnectionCreation

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
    
    @objc class func keyPathsForValuesAffectingDescription() -> Set<String> {
        return [#keyPath(AutoFixSuggestionListItem.fixDescription)]
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

class BushelRTObject: NSObject, ObjectInspectable {
    
    let service: BushelLanguageServiceProtocol
    let object: RTObjectToken
    
    @objc dynamic var objectDescription: String?
    
    init(service: BushelLanguageServiceProtocol, object: RTObjectToken) {
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
    
    @objc class func keyPathsForValuesAffectingDescription() -> Set<String> {
        return [#keyPath(BushelRTObject.objectDescription)]
    }
    
    var typeIdentifier: String {
        return "object"
    }
    
    var localizedTypeName: String {
        return "Object"
    }
    
}

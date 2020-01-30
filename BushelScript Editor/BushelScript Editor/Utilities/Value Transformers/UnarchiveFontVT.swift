//
//  UnarchiveFontVT.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 28 Jan ’20.
//  Copyright © 2020 Ian Gregory. All rights reserved.
//

import Cocoa

@objc(UnarchiveFontVT)
class UnarchiveFontVT: NSSecureUnarchiveFromDataTransformer {
    
    // NSSecureUnarchiveFromDataTransformer reads this property
    // and automatically returns it the `-allowedTopLevelClasses`.
    override class func transformedValueClass() -> AnyClass {
        NSFont.self
    }
    
}

@objc(UnarchiveFontDisplayNameVT)
class UnarchiveFontDisplayNameVT: NSSecureUnarchiveFromDataTransformer {
    
    // NSSecureUnarchiveFromDataTransformer reads this property
    // and automatically returns it the `-allowedTopLevelClasses`.
    override class func transformedValueClass() -> AnyClass {
        NSFont.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        (UnarchiveFontVT().transformedValue(value) as? NSFont)?.displayName
    }
    
}

@objc(UnarchiveFontSizeVT)
class UnarchiveFontSizeVT: NSSecureUnarchiveFromDataTransformer {
    
    // NSSecureUnarchiveFromDataTransformer reads this property
    // and automatically returns it the `-allowedTopLevelClasses`.
    override class func transformedValueClass() -> AnyClass {
        NSFont.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        (UnarchiveFontVT().transformedValue(value) as? NSFont)?.pointSize
    }
    
}

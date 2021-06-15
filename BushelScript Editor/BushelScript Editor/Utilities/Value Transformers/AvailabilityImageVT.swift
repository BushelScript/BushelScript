// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit

@objc(AvailabilityImageVT)
class AvailabilityImageVT: ValueTransformer {
    
    // NSSecureUnarchiveFromDataTransformer reads this property
    // and automatically returns it the `-allowedTopLevelClasses`.
    override class func transformedValueClass() -> AnyClass {
        NSFont.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        false
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        (value as? Bool).flatMap { NSImage(named: $0 ? NSImage.statusAvailableName : NSImage.statusUnavailableName) }
    }
    
}

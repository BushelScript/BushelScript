// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa

class ObjectInspectorDetailVC: PropagatingTabViewController {
    
    override var representedObject: Any? {
        didSet {
            guard let representedObject = representedObject as AnyObject? else {
                return
            }
            let selectedTypeIdentifier = representedObject.value(forKeyPath: #keyPath(ObjectInspectable.typeIdentifier))!
            if !NSIsControllerMarker(selectedTypeIdentifier) {
                selectTabViewItem(withIdentifier: selectedTypeIdentifier)
            }
        }
    }
    
}

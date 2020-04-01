// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa

class ObjectInspectorVC: NSViewController {
    
    static func instantiate(for object: ObjectInspectable) -> ObjectInspectorVC {
        let vc = NSStoryboard(name: "ObjectInspectorVC", bundle: Bundle(for: self)).instantiateInitialController() as! ObjectInspectorVC
        vc.representedObject = object
        return vc
    }
    
    private var detailVC: NSTabViewController?
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "embedDetailVC":
            detailVC = (segue.destinationController as! NSTabViewController)
            pushRepresentedObject()
        default:
            super.prepare(for: segue, sender: sender)
        }
    }
    
    override var representedObject: Any? {
        didSet {
            if representedObject != nil {
                pushRepresentedObject()
            }
        }
    }
    
    private func pushRepresentedObject() {
        guard
            let detailVC = detailVC,
            let representedObject = representedObject as AnyObject?
        else {
            return
        }
        detailVC.representedObject = representedObject
    }
    
}

//
//  ObjectInspectorDetailVC.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 4 Jan ’20.
//  Copyright © 2020 Ian Gregory. All rights reserved.
//

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

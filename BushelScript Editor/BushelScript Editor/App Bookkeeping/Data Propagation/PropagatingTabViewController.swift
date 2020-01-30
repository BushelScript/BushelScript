//
//  PropagatingTabViewController.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 26-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa

class PropagatingTabViewController: NSTabViewController {
    
    @IBInspectable var propagateRepresentedObject: Bool = true
    
    // Implemented in swizzled methods in ModalPropagation.swift
    
}

// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa

class PropagatingTabViewController: NSTabViewController {
    
    @IBInspectable var propagateRepresentedObject: Bool = true
    
    // Implemented in swizzled methods in ModalPropagation.swift
    
}

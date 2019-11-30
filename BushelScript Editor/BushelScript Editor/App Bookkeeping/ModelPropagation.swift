//
//  TabViewModelPropagation.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 26-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa

extension NSViewController {
    
    private static var bubbleKeyPathAssociationKey: Int = 0
    
    /// When set, representedObject is bubbled up to the parent view controller
    /// via the specified key path. e.g., to update the parent's "parameters"
    /// value when self.representedObject changes, set bubbleKeyPath to
    /// "parameters".
    @IBInspectable var bubbleKeyPath: String? {
        get {
            return objc_getAssociatedObject(self, &NSViewController.bubbleKeyPathAssociationKey) as! String?
        }
        set {
            return objc_setAssociatedObject(self, &NSViewController.bubbleKeyPathAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    // Swizzled in ObjC
    @objc dynamic func TJC_setRepresentedObject(_ newValue: Any?) {
        TJC_setRepresentedObject(newValue) // Swizzled in ObjC
        performBubbleRepresentedObject()
        if let self = self as? NSTabViewController {
            self.performPropagateRepresentedObject(to: self.tabViewItems[self.selectedTabViewItemIndex])
        }
    }
    
    fileprivate func performBubbleRepresentedObject() {
        if let bubbleKeyPath = bubbleKeyPath {
            parent?.setValue(representedObject, forKeyPath: bubbleKeyPath)
        }
    }
    
}

extension NSTabViewController {
    
    // Swizzled in ObjC
    @objc dynamic func TJC_tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        TJC_tabView(tabView, willSelect: tabViewItem) // Swizzled in ObjC
        if let tabViewItem = tabViewItem {
            performPropagateRepresentedObject(to: tabViewItem)
        }
    }
    
//    @objc dynamic var TJC_selectedTabViewItemIndex: Int {
//        get {
//            self.TJC_selectedTabViewItemIndex // Swizzled in ObjC
//        }
//        set {
//            if tabViewItems.indices.contains(newValue) {
//                performPropagateRepresentedObject(to: tabViewItems[newValue])
//            }
//            self.TJC_selectedTabViewItemIndex = newValue // Swizzled in ObjC
//        }
//    }
    
    fileprivate func performPropagateRepresentedObject(to tabViewItem: NSTabViewItem) {
        guard
            let self = self as? PropagatingTabViewController,
            self.propagateRepresentedObject
        else {
            return
        }
        for viewController in tabViewItems.compactMap({ $0.viewController }) {
            viewController.representedObject = nil
        }
        tabViewItem.viewController?.representedObject = representedObject
    }
    
}

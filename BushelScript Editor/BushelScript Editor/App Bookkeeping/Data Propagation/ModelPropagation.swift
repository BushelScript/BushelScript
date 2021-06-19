// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

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

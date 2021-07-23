// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Bushel

class DictionaryBrowserVC: NSSplitViewController {
    
    private var sidebarVC: DictionaryBrowserSidebarVC?
    private var contentVC: DictionaryBrowserContentVC?
    
    @IBOutlet var selectedTermDocOC: NSObjectController! {
        didSet {
            contentVC?.representedObject = selectedTermDocOC
        }
    }
    
    override var splitViewItems: [NSSplitViewItem] {
        didSet {
            for item in splitViewItems {
                if let sidebarVC = item.viewController as? DictionaryBrowserSidebarVC {
                    self.sidebarVC = sidebarVC
                    sidebarVC.termDocs = globalTermDocs
                    sidebarVC.selectionOC = selectedTermDocOC
                }
                if let contentVC = item.viewController as? DictionaryBrowserContentVC {
                    self.contentVC = contentVC
                    contentVC.representedObject = selectedTermDocOC
                }
            }
        }
    }
    
    var rootTerm: Term? {
        get {
            sidebarVC?.rootTerm
        }
        set {
            sidebarVC?.representedObject = newValue
        }
    }
    
    func reveal(_ term: Term) {
        sidebarVC?.reveal(term)
    }
    
}

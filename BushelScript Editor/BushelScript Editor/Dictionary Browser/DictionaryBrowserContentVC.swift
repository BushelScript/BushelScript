// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit

class DictionaryBrowserContentVC: NSViewController {
    
    var termDoc: DictionaryBrowserTermDoc? {
        representedObject as? DictionaryBrowserTermDoc
    }
    
}

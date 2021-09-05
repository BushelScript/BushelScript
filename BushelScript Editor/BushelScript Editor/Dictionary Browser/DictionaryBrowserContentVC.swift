// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import BushelSourceEditor

class DictionaryBrowserContentVC: NSViewController {
    
    var termDoc: TermTableCellValue? {
        representedObject as? TermTableCellValue
    }
    
}

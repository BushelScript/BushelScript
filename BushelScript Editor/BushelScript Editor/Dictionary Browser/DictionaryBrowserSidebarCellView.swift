import AppKit
import BushelSourceEditor

class DictionaryBrowserSidebarCellView: NSTableCellView {
    
    @IBOutlet var termRoleIconView: TermRoleIconView!
    
    var highlightStyles: HighlightStyles? {
        get {
            termRoleIconView.highlightStyles
        }
        set {
            termRoleIconView.highlightStyles = newValue
        }
    }
    
    override var objectValue: Any? {
        didSet {
            termRoleIconView.role = (objectValue as? DictionaryBrowserTermDoc)?.termDoc.term.role
        }
    }
    
}

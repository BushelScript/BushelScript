import AppKit

class DictionaryBrowserSidebarCellView: NSTableCellView {
    
    @IBOutlet var termRoleIconView: TermRoleIconView!
    
    override var objectValue: Any? {
        didSet {
            termRoleIconView.role = (objectValue as? DictionaryBrowserTermDoc)?.termDoc.term.role
        }
    }
    
}

import AppKit

public class TermTableCellView: NSTableCellView {
    
    @IBOutlet public var termRoleIconView: TermRoleIconView!
    
    public var highlightStyles: HighlightStyles? {
        get {
            termRoleIconView.highlightStyles
        }
        set {
            termRoleIconView.highlightStyles = newValue
        }
    }
    
    public override var objectValue: Any? {
        didSet {
            termRoleIconView.role = (objectValue as? TermTableCellValue)?.termDoc.term.role
        }
    }
    
}

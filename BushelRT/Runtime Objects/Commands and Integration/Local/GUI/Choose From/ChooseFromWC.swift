import Cocoa

final class ChooseFromWC: NSWindowController {
    
    @objc private dynamic var copiableItems: [BushelRT_TriviallyCopiable] = []
    var items: [Any] {
        get {
            copiableItems.map { $0.value }
        }
        set {
            copiableItems = newValue.map(BushelRT_TriviallyCopiable.init)
        }
    }
    
    @objc dynamic var prompt: String?
    
    @objc dynamic var okButtonName: String = "OK"
    @objc dynamic var cancelButtonName: String = "Cancel"
    
    @IBOutlet var listTableView: NSTableView!
    
    var response: Any?
    
    @IBAction func buttonClicked(_ sender: NSButton) {
        if sender.tag == 2 {
            setResponse(for: listTableView)
        }
        close()
    }
    
    @IBAction func itemSelected(_ sender: NSTableView) {
        setResponse(for: sender)
        close()
    }
    
    private func setResponse(for tableView: NSTableView) {
        let selectedRow = tableView.selectedRow
        guard
            selectedRow != -1,
            let rowView = tableView.rowView(atRow: selectedRow, makeIfNecessary: false),
            let cellView = rowView.view(atColumn: 0) as? NSTableCellView
        else {
            return
        }
        
        response = (cellView.objectValue as! BushelRT_TriviallyCopiable).value
    }
    
}

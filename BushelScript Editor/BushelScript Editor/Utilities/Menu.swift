// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

extension NSMenu {
    
    @discardableResult
    func addItem(title: String, target: AnyObject? = nil, action: Selector? = nil, tag: Int = 0, representedObject: Any? = nil, isOn: Bool = false, indentationLevel: Int? = nil, submenu: NSMenu? = nil) -> NSMenuItem {
        let item = addItem(withTitle: title, action: action, keyEquivalent: "")
        if let target = target {
            item.target = target
        }
        item.tag = tag
        item.representedObject = representedObject
        if isOn {
            item.state = .on
        }
        if let indentationLevel = indentationLevel {
            item.indentationLevel = indentationLevel
        }
        if let submenu = submenu {
            item.submenu = submenu
        }
        return item
    }
    
}

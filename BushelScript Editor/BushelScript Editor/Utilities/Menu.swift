// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

extension NSMenu {
    
    @discardableResult
    func addItem(title: String, action: Selector, tag: Int = 0, representedObject: Any? = nil, isOn: Bool = false) -> NSMenuItem {
        let item = addItem(withTitle: title, action: action, keyEquivalent: "")
        item.tag = tag
        item.representedObject = representedObject
        if isOn {
            item.state = .on
        }
        return item
    }
    
}

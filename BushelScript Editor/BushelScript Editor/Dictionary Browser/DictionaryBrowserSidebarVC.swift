// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Bushel

class DictionaryBrowserSidebarVC: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    var selectionOC: NSObjectController?
    
    var termDocs: Ref<[Term.ID : TermDoc]>?
    
    var rootTerm: Term? {
        representedObject as? Term
    }
    
    override var representedObject: Any? {
        didSet {
            outlineView?.reloadData()
        }
    }
    
    @IBOutlet var outlineView: NSOutlineView!
    
    // MARK: NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? Term {
            return item.dictionary.contents.count
        } else {
            return rootTerm?.dictionary.contents.count ?? 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? Term {
            return term(at: index, of: item.dictionary.contents)
        } else if let rootTerm = rootTerm {
            return term(at: index, of: rootTerm.dictionary.contents)
        } else {
            preconditionFailure("Queried but no items available")
        }
    }
    
    private func term<TC: TermCollection>(at index: Int, of collection: TC) -> Term {
        collection[collection.index(collection.startIndex, offsetBy: index)]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? Term)?.dictionary.contents.isEmpty ?? true)
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let termDocs = termDocs, let term = item as? Term else {
            return nil
        }
        return DictionaryBrowserTermDoc(termDocs.value[term.id] ?? TermDoc(term: term))
    }
    
    // MARK: NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("DataCell"), owner: nil)
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = outlineView.selectedRow
        if selectedRow != -1 {
            selectionOC?.content = outlineView(outlineView, objectValueFor: nil, byItem: outlineView.item(atRow: selectedRow))
        }
    }
    
}

class DictionaryBrowserTermDoc: NSObject, NSCopying {
    
    init(_ termDoc: TermDoc) {
        self.termDoc = termDoc
    }
    
    var termDoc: TermDoc
    
    func copy(with _: NSZone? = nil) -> Any {
        DictionaryBrowserTermDoc(termDoc)
    }
    
    override var description: String {
        "\(termDoc.term)"
    }
    
    @objc var id: String {
        "\(termDoc.term.id)"
    }
    
    @objc var role: String {
        "\(termDoc.term.role)"
    }
    
    @objc var doc: String {
        "\(termDoc)"
    }
    
    @objc var summary: String {
        termDoc.summary
    }
    
    @objc var discussion: String {
        termDoc.discussion
    }
    
}

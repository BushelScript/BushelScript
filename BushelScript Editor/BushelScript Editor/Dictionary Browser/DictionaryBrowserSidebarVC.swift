// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Bushel
import os.log

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

class DictionaryBrowserSidebarVC: NSViewController, NSOutlineViewDelegate, NSOutlineViewDataSource {
    
    var selectionOC: NSObjectController?
    
    var termDocs: Ref<[Term.ID : TermDoc]>?
    
    var rootTerm: Term? {
        representedObject as? Term
    }
    
    var termToContainingTerm: [Term : Term] = [:]
    func indexContainingTerms(for containingTerm: Term) {
        for term in containingTerm.dictionary.contents where termToContainingTerm[term as! Term] == nil {
            let term = term as! Term
            termToContainingTerm[term] = containingTerm
            indexContainingTerms(for: term)
        }
    }
    
    override var representedObject: Any? {
        didSet {
            termToContainingTerm.removeAll()
            if let rootTerm = rootTerm {
                indexContainingTerms(for: rootTerm)
            }
            
            outlineView?.reloadData()
        }
    }
    
    func drillDown(to term: Term) {
        if let containingTerm = termToContainingTerm[term] {
            drillDown(to: containingTerm)
        }
        outlineView.expandItem(term)
    }
    
    func reveal(_ term: Term) {
        drillDown(to: term)
        let row = outlineView.row(forItem: term)
        guard row != -1 else {
            os_log("Cannot reveal term without outline entry: %@", log: log, "\(term)")
            return
        }
        outlineView.selectRowIndexes([row], byExtendingSelection: false)
        outlineView.scrollRowToVisible(row)
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
    
    private func term(at index: Int, of set: NSOrderedSet) -> Term {
        set.object(at: index) as! Term
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as! Term).dictionary.contents.count != 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let termDocs = termDocs, let term = item as? Term else {
            return nil
        }
        let doc = termDocs.value[term.id] ?? TermDoc(term: term)
        // TODO: This dance shouldn't be necessary.
        //       TermDocs should be created for each available synonym,
        //       or be coalesced in some other way.
        let synonymDoc = TermDoc(term: term, summary: doc.summary, discussion: doc.discussion)
        return DictionaryBrowserTermDoc(synonymDoc)
    }
    
    // MARK: NSOutlineViewDelegate
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("DataCell"), owner: self) as! DictionaryBrowserSidebarCellView
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

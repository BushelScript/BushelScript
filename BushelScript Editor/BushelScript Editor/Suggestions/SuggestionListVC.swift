//
//  SuggestionListVC.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 25-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa

class SuggestionListVC: NSViewController {
    
    @IBOutlet var suggestionsAC: NSArrayController!
    
    private lazy var inspectorPanelWC = ObjectInspectorPanelWC.instantiate(for: NoSelection(), attachedTo: self.view.window)
    private var inspectorVC: ObjectInspectorVC {
        return inspectorPanelWC.contentViewController as! ObjectInspectorVC
    }
    
    private var selectionObservation: NSKeyValueObservation? = nil
    
    deinit {
        selectionObservation?.invalidate()
        stopObservingWindow()
    }
    
    var documentVC: DocumentVC?
    
    override func viewDidAppear() {
        guard let inspectorPanel = inspectorPanelWC.window else {
            return
        }
        
        selectionObservation = suggestionsAC.observe(\.selection, changeHandler: { [weak self] (ac, change) in
            self?.inspectorVC.representedObject = ac.selection
        })
        
        inspectorPanel.bind(.title, to: suggestionsAC!, withKeyPath: "selection.description", options: nil)
        
        observeWindow()
        inspectorPanel.orderFront(self)
        view.window?.orderFront(self)
    }
    
    private var windowMovedObservation: AnyObject?, windowResizedObservation: AnyObject?
    private var windowClosingObservation: AnyObject?
    
    private func observeWindow() {
        let repositionWindow = { [weak self] (notification: Notification) in
            guard
                let self = self,
                let window = self.view.window,
                let inspectorPanel = self.inspectorPanelWC.window
            else {
                return
            }
            let windowFrame = window.frame
            let inspectorFrame = inspectorPanel.frame
            let inspectorOrigin = CGPoint(x: windowFrame.maxX, y: windowFrame.maxY - inspectorFrame.height)
            inspectorPanel.setFrameOrigin(inspectorOrigin)
        }
        if let window = view.window {
            if windowMovedObservation == nil {
                windowMovedObservation = NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: nil, using: repositionWindow)
            }
            if windowResizedObservation == nil {
                windowResizedObservation = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: nil, using: repositionWindow)
            }
        }
        repositionWindow(Notification(name: .init("")))
        
        let wipeSuggestionsList = { [weak self] (notification: Notification) in
            guard let self = self else {
                return
            }
            self.suggestionsAC.content = []
        }
        if let window = view.window {
            windowClosingObservation = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: nil, using: wipeSuggestionsList)
        } else {
            wipeSuggestionsList(Notification(name: .init("")))
        }
    }
    
    private func stopObservingWindow() {
        for observation in [
            windowMovedObservation,
            windowResizedObservation,
            windowClosingObservation
        ].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observation)
        }
    }
    
    @IBAction func apply(_ sender: Any?) {
        guard let suggestion = suggestionsAC.selectedObjects[0] as? AutoFixSuggestionListItem else {
            return
        }
        documentVC?.apply(suggestion: suggestion)
        view.window?.orderOut(self)
    }
    
    override func viewWillDisappear() {
        inspectorPanelWC.window?.orderOut(self)
        (view.window?.windowController as? SuggestionListWC)?.resetOpacity()
    }
    
    @IBAction func becomeKey(_ sender: Any?) {
        view.window?.becomeKey()
    }
    
    @IBOutlet var iconColumn: NSTableColumn!
    @IBOutlet var descriptionColumn: NSTableColumn!
    
}

extension SuggestionListVC: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return hasErrorDescriptionRow && row == 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch tableColumn?.identifier {
        case descriptionColumn.identifier, nil:
            return tableView.makeView(withIdentifier: descriptionColumn.identifier, owner: self)
        default:
            return tableView.makeView(withIdentifier: iconColumn.identifier, owner: self)
        }
    }
    
    private var hasErrorDescriptionRow: Bool {
        if
            let suggestions = suggestionsAC.arrangedObjects as? [SuggestionListItem],
            suggestions.first is ErrorSuggestionListItem
        {
            return true
        } else {
            return false
        }
    }
    
}

@objc(SuggestionListItemFontSizeVT)
class SuggestionListItemFontSizeVT: ValueTransformer {
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let item = value as? SuggestionListItem else {
            return nil
        }
        return item.isLargeItem ? 13 : 12
    }
    
}

//
//  ObjectInspectorPanel.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 28-09-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

import Cocoa

class ObjectInspectorPanelWC: NSWindowController {
    
    @IBOutlet var containerView: NSView!
    
    private var parentWindow: NSWindow?
    
    static func instantiate(for object: ObjectInspectable, attachedTo parentWindow: NSWindow? = nil) -> ObjectInspectorPanelWC {
        let wc = ObjectInspectorPanelWC(windowNibName: "ObjectInspectorPanelWC")
        let vc = ObjectInspectorVC.instantiate(for: object)
        wc.contentViewController = vc
        wc.window?.contentView = vc.view
        
        if let parentWindow = parentWindow {
            wc.attach(to: parentWindow)
        } else {
            wc.detach()
        }
        
        return wc
    }
    
    func attach(to parentWindow: NSWindow) {
        self.parentWindow = parentWindow
        
        guard let window = self.window else {
            return
        }
        window.styleMask.remove(.closable)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    func detach() {
        parentWindow = nil
        
        guard let window = self.window else {
            return
        }
        window.styleMask.insert(.closable)
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
    }
    
}

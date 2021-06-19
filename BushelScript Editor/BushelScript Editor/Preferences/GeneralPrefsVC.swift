// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Defaults

class GeneralPrefsVC: NSViewController {
    
    @IBOutlet var fontManager: NSFontManager!
    
    @IBOutlet weak var fontPreviewTF: NSTextField!
    
    override func viewDidAppear() {
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey(_:)), name: NSWindow.didResignKeyNotification, object: nil)
    }
    
    @IBAction func modifyFont(_ sender: Any) {
        guard let fontPanel = fontManager.fontPanel(true) else {
            return
        }
        fontPanel.delegate = self
        fontPanel.orderFront(self)
        view.window?.makeFirstResponder(self)
    }
    
    override func resignFirstResponder() -> Bool {
        orderOutFontPanel()
        return true
    }
    
    @objc func windowDidResignKey(_ notification: Notification) {
        if NSApp.keyWindow !== view.window && NSApp.keyWindow !== fontManager.fontPanel(false) {
            orderOutFontPanel()
        }
    }
    
    override func viewWillDisappear() {
        orderOutFontPanel()
    }
    
    private func orderOutFontPanel() {
        fontManager.fontPanel(false)?.orderOut(self)
    }
    
}

extension GeneralPrefsVC: NSWindowDelegate, NSFontChanging {
    
    func validModesForFontPanel(_ fontPanel: NSFontPanel) -> NSFontPanel.ModeMask {
        [.collection, .face, .size]
    }
    
    func changeFont(_ sender: NSFontManager?) {
        guard
            let sender = sender,
            let font = fontPreviewTF.font
        else {
            return
        }
        let changedFont = sender.convert(font)
        
        Defaults[.sourceCodeFont] = changedFont
    }
    
}

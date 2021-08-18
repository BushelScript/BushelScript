// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

import AppKit
import Defaults

class GeneralPrefsVC: NSViewController {
    
    @IBOutlet var fontManager: NSFontManager!
    @IBOutlet var themeMenuDelegate: ThemeMenuDelegate!
    
    @IBOutlet weak var fontPreviewTF: NSTextField!
    @IBOutlet var themeMenu: NSMenu!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        themeMenuDelegate.menuNeedsUpdate(themeMenu)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
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
        return super.resignFirstResponder()
    }
    
    @objc func windowDidResignKey(_ notification: Notification) {
        if NSApp.keyWindow !== view.window && NSApp.keyWindow !== fontManager.fontPanel(false) {
            orderOutFontPanel()
        }
    }
    
    override func viewWillDisappear() {
        orderOutFontPanel()
        super.viewWillDisappear()
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

class ThemeMenuDelegate: NSObject, NSMenuDelegate {
    
    @IBOutlet var themePUB: NSPopUpButton!
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        do {
            func addItems(for themeDir: URL, label: String) throws {
                menu.addItem(title: "Open \(label) Folder…", target: self, action: #selector(openFolder(_:)), representedObject: themeDir)
                menu.addItem(.separator())
                
                for themeFile in try FileManager.default.contentsOfDirectory(at: themeDir, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]) {
                    let title = themeFile.deletingPathExtension().lastPathComponent
                    menu.addItem(title: title, target: self, action: #selector(setTheme(_:)), representedObject: themeFile, isOn: themeFile.lastPathComponent == Defaults[.themeFileName], indentationLevel: 1)
                }
            }
            
            try addItems(for: makeUserThemesDir(), label: "User Themes")
            
            if let builtInThemesDir = builtInThemesDir {
                menu.addItem(.separator())
                try addItems(for: builtInThemesDir, label: "Default Themes")
            }
        } catch {
            NSApplication.shared.presentError(error)
            return
        }
        
        menu.addItem(.separator())
        
        menu.addItem(title: "Browse…", target: self, action: #selector(browseForTheme(_:)))
        
        DispatchQueue.main.async(execute: selectCorrectMenuItem)
    }
    
    func selectCorrectMenuItem() {
        themePUB.select(themePUB.menu!.item(withTitle: (Defaults[.themeFileName] as NSString).deletingPathExtension))
    }
    
    @IBAction func setTheme(_ sender: NSMenuItem) {
        Defaults[.themeFileName] = (sender.representedObject as! URL).lastPathComponent
    }
    
    @IBAction func browseForTheme(_ sender: Any?) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["tmTheme", "plist"]
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a theme file."
        
        switch openPanel.runModal() {
        case .OK:
            do {
                let selectedThemeURL = openPanel.url!
                try FileManager.default.copyItem(at: selectedThemeURL, to: makeUserThemesDir().appendingPathComponent(selectedThemeURL.lastPathComponent))
                
                Defaults[.themeFileName] = selectedThemeURL.lastPathComponent
                
                menuNeedsUpdate(themePUB.menu!)
                selectCorrectMenuItem()
            } catch {
                NSApplication.shared.presentError(error)
            }
        default:
            return
        }
    }
    
    @IBAction func openFolder(_ sender: NSMenuItem) {
        selectCorrectMenuItem()
        
        NSWorkspace.shared.open(sender.representedObject as! URL)
    }
    
}

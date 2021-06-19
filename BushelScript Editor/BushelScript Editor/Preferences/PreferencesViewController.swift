// BushelScript Editor application
// © 2019-2021 Ian Gregory.
// See file LICENSE.txt for licensing information.

// This file is also available at
// https://gist.github.com/ThatsJustCheesy/8148106fa7269326162d473408d3f75a

// Thanks to mminer on GitHub
// https://gist.github.com/mminer/caec00d2165362ff65e9f1f728cecae2

import Cocoa

class PreferencesViewController: NSTabViewController {
    
    private lazy var tabViewSizes: [NSTabViewItem: NSSize] = [:]
    private var lastSelectedTabViewItem: NSTabViewItem? = nil
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if let selectedItem = tabView.selectedTabViewItem {
            view.window?.title = selectedItem.label
        }
    }
    
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        
        lastSelectedTabViewItem?.view?.isHidden = false
        
        if let tabViewItem = tabViewItem {
            view.window?.title = tabViewItem.label
            resizeWindowToFit(tabViewItem: tabViewItem)
        }
    }
    
    override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, willSelect: tabViewItem)
        
        // Noticeably smoothens the transition if crossfade is disabled.
        lastSelectedTabViewItem = tabView.selectedTabViewItem
        lastSelectedTabViewItem?.view?.isHidden = true
        
        // Cache the size of the tab view.
        if let tabViewItem = tabViewItem, let view = tabViewItem.view {
            view.layoutSubtreeIfNeeded()
            let size = view.frame.size
            tabViewSizes[tabViewItem] = size
        }
    }
    
    /// Resizes the window so that it fits the content of the tab.
    private func resizeWindowToFit(tabViewItem: NSTabViewItem) {
        guard let size = tabViewSizes[tabViewItem], let window = view.window else {
            return
        }
        
        let contentRect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let contentFrame = window.frameRect(forContentRect: contentRect)
        let toolbarHeight = window.frame.size.height - contentFrame.size.height
        let newOrigin = NSPoint(x: window.frame.origin.x, y: window.frame.origin.y + toolbarHeight)
        let newFrame = NSRect(origin: newOrigin, size: contentFrame.size)
        window.animator().setFrame(newFrame, display: false)
    }
}

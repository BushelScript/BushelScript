// BushelScript Editor application
// © 2019-2020 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

import Cocoa

class SuggestionListView: NSTableView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectRowIndexes([0], byExtendingSelection: false)
    }
    
    override func didAdd(_ rowView: NSTableRowView, forRow row: Int) {
        super.didAdd(rowView, forRow: row)
        let triangleView = NSImageView(image: NSImage(named: NSImage.rightFacingTriangleTemplateName)!)
        triangleView.translatesAutoresizingMaskIntoConstraints = false
        rowView.addSubview(triangleView)
        rowView.trailingAnchor.constraint(equalTo: triangleView.trailingAnchor, constant: 5).isActive = true
        rowView.centerYAnchor.constraint(equalTo: triangleView.centerYAnchor).isActive = true
    }
    
}

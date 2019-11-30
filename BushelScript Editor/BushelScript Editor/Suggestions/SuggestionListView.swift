//
//  SuggestionListView.swift
//  BushelScript Editor
//
//  Created by Ian Gregory on 25-08-2019.
//  Copyright © 2019 Ian Gregory. All rights reserved.
//

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

import Bushel

let guiEventClass = try! AEEventClass(fourByteString: "bShG")

enum GUIEventID: AEEventID, CaseIterable {
    
    case ask = 1634954016 // 'ask '
    case notification = 1852798054 // 'notf'
    
}

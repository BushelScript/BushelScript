import Bushel

let guiEventClass = try! AEEventClass(fourByteString: "bShG")

enum GUIEventID: AEEventID, CaseIterable {
    
    case ask = 1634954016 // 'ask '
    
}

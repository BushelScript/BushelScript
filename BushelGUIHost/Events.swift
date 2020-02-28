import Bushel

let guiEventClass = try! AEEventClass(fourByteString: "bShG")

enum GUIEventID: AEEventID, CaseIterable {
    
    case alert = 1684632385 // 'disA'
    case ask = 1634954016 // 'ask '
    case chooseFrom = 1667787892 // 'chlt'
    case notification = 1852798054 // 'notf'
    
}

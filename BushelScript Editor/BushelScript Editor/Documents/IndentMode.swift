// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

public class IndentMode: NSObject {
    
    @objc dynamic var character: Character = .tab
    @objc dynamic var width: Int = 4
    
    @objc enum Character: Int {
        case space, tab
    }
    
    var indentation: String {
        switch character {
        case .space:
            return String(repeating: " ", count: width)
        case .tab:
            return "\t"
        @unknown default:
            return String(repeating: " ", count: width)
        }
    }
    func indentation(for level: Int) -> String {
        String(repeating: indentation, count: level)
    }
    
}

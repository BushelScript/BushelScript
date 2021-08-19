
public class IndentMode: NSObject {
    
    @objc public dynamic var character: Character = .tab
    @objc public dynamic var width: Int = 4
    
    @objc public enum Character: Int {
        case space, tab
    }
    
    public var indentation: String {
        switch character {
        case .space:
            return String(repeating: " ", count: width)
        case .tab:
            return "\t"
        @unknown default:
            return String(repeating: " ", count: width)
        }
    }
    public func indentation(for level: Int) -> String {
        String(repeating: indentation, count: level)
    }
    
}

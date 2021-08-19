import Foundation
import Bushel

public struct HighlightStyles {
    
    public var highlighted: Bushel.Styles
    public var unhighlighted: [NSAttributedString.Key : Any]
    
    public subscript(_ styling: Bushel.Styling) -> [NSAttributedString.Key : Any]? {
        highlighted[styling]
    }
    
    public init(highlighted: Bushel.Styles, unhighlighted: [NSAttributedString.Key : Any]) {
        self.highlighted = highlighted
        self.unhighlighted = unhighlighted
    }
    public init() {
        self.init(highlighted: [:], unhighlighted: [:])
    }
    
}

import Bushel

public struct RT_Stack<Element> {
    
    public private(set) var contents: [Element]
    
    public init(bottom: Element, rest: [Element] = []) {
        self.contents = [bottom] + rest
    }
    
    public var top: Element {
        get {
            contents.last!
        }
        set {
            contents[contents.endIndex - 1] = newValue
        }
    }
    
    public mutating func push(_ newElement: Element) {
        contents.append(newElement)
    }
    
    public mutating func repush() {
        push(top)
    }
    
    @discardableResult
    public mutating func pop() -> Element? {
        (contents.count > 1) ? contents.popLast() : nil
    }
    
}

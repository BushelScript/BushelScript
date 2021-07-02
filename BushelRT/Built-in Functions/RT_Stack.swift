import Bushel

/// A stack with a constant, non-nil bottom element.
public struct RT_Stack<Element> {
    
    public private(set) var contents: [Element]
    
    /// Initializes with constant `bottom` element and, optionally,
    /// additional elements `rest`.
    public init(bottom: Element, rest: [Element] = []) {
        self.contents = [bottom] + rest
    }
    
    /// The top element.
    public var top: Element {
        get {
            contents.last!
        }
        set {
            contents[contents.endIndex - 1] = newValue
        }
    }
    
    /// The bottom element.
    public var bottom: Element {
        contents.first!
    }
    
    /// Pushes `newElement` onto the top.
    public mutating func push(_ newElement: Element) {
        contents.append(newElement)
    }
    
    /// Pushes a copy of the top element.
    public mutating func repush() {
        push(top)
    }
    
    /// Removes the top element and returns it if doing so would leave the stack
    /// nonempty. Otherwise (if it would leave the stack empty), returns `nil`.
    @discardableResult
    public mutating func pop() -> Element? {
        (contents.count > 1) ? contents.popLast() : nil
    }
    
}

import Foundation
import Bushel

public class TermTableCellValue: NSObject, NSCopying {
    
    public init(_ termDoc: TermDoc) {
        self.termDoc = termDoc
    }
    
    public var termDoc: TermDoc
    
    public func copy(with _: NSZone? = nil) -> Any {
        TermTableCellValue(termDoc)
    }
    
    public override var description: String {
        "\(termDoc.term)"
    }
    
    @objc public var id: String {
        "\(termDoc.term.id)"
    }
    
    @objc public var role: String {
        "\(termDoc.term.role)"
    }
    
    @objc public var doc: String {
        "\(termDoc)"
    }
    
    @objc public var summary: String {
        termDoc.summary
    }
    
    @objc public var discussion: String {
        termDoc.discussion
    }
    
}


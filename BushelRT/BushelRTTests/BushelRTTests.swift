import XCTest
@testable import BushelRT
import Bushel

class BushelRTTests: XCTestCase {
    
    lazy var xyzSource = try! String(contentsOf: Bundle(for: type(of: self)).url(forResource: "xyz", withExtension: "bushel")!)
    
    func testGenerate() {
        let parsed = try! parse(source: xyzSource)
        BushelRT.run(parsed)
    }
    
}
